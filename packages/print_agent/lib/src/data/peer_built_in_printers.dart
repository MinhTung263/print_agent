import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../domain/agent_identity.dart';
import '../domain/entities/peer_built_in_printer.dart';
import '../l10n/agent_locale_keys.dart';
import '../print_agent_module.dart';

/// Danh sách máy in tích hợp của các máy Agent mà máy này biết.
///
/// - Tự phát hiện: Agent trực tuyến có máy in tích hợp → thêm vào danh sách
///   ([sync]); Agent tắt thì máy in vẫn ở đó (hiện "Ngoại tuyến") như một máy in
///   thường bị tắt.
/// - Người dùng chỉ bật / tắt từng máy; mặc định TẮT (bật thì in ra máy tích hợp
///   của Agent khác — phải là người dùng chủ động chọn). Chức năng in, khổ giấy
///   luôn theo cài đặt trên máy Agent. Lưu trên máy này theo công ty.
abstract final class PeerBuiltInPrinters {
  /// Khoá cũ: công tắc chung "In qua máy in tích hợp của máy Agent" — bật thì
  /// máy in mới phát hiện được bật sẵn (giữ thói quen cũ).
  static const String legacyAllKey = 'print_station_builtin_enabled';

  static final RxList<PeerBuiltInPrinter> items = <PeerBuiltInPrinter>[].obs;

  /// Chức năng in khi Agent (bản cũ) không báo — app chủ đặt lúc khởi tạo.
  static List<String> defaultTemplates = const [];

  static String? _loadedFor;

  static String get _storageKey =>
      'station_builtin_printers_${PrintAgentModule.host.companyKey}';

  /// Tên hiển thị: "Máy in tích hợp (Quầy bar · #A3F9)".
  static String displayName(PeerBuiltInPrinter p) =>
      LocaleKeys.printerSetting_stationBuiltInNameNamedTr(
        stationName: AgentIdentity.label(p.agentName, p.stationId),
      );

  /// Đọc danh sách của công ty đang đăng nhập (đổi công ty thì đọc lại). Gọi
  /// NGOÀI lúc dựng giao diện (đổi [items] lúc build làm Obx báo lỗi).
  static void ensureLoaded() {
    final key = _storageKey;
    if (_loadedFor == key) return;
    _loadedFor = key;
    try {
      final raw = PrintAgentModule.host.storage.get(key);
      items.assignAll([
        if (raw is List)
          for (final e in raw) ?PeerBuiltInPrinter.fromMap(e, defaultTemplates),
      ]);
    } catch (_) {
      items.clear();
    }
  }

  static List<PeerBuiltInPrinter> get all {
    ensureLoaded();
    return items;
  }

  /// Mã các Agent đang được BẬT dùng máy in tích hợp.
  static Set<String> enabledStationIds() => {
    for (final p in items)
      if (p.enabled) p.stationId,
  };

  static void _save() {
    try {
      PrintAgentModule.host.storage.put(_storageKey, [
        for (final p in items) p.toMap(),
      ]);
    } catch (_) {}
  }

  /// Bỏ máy in tích hợp của Agent [stationId] (Agent đã quên). Trả mục đã bỏ để
  /// hoàn tác ([restore]).
  static PeerBuiltInPrinter? forget(String stationId) {
    final removed = all.firstWhereOrNull((p) => p.stationId == stationId);
    if (removed == null) return null;
    items.removeWhere((p) => p.stationId == stationId);
    _save();
    return removed;
  }

  /// Hoàn tác [forget].
  static void restore(PeerBuiltInPrinter printer) {
    if (all.any((p) => p.stationId == printer.stationId)) return;
    items.add(printer);
    _save();
  }

  /// Cập nhật theo các Agent đang trực tuyến: thêm máy mới, cập nhật tên / khổ
  /// giấy / lần thấy cuối. Giữ nguyên lựa chọn bật / tắt.
  static void sync(List<Map<Object?, Object?>> stations) {
    final list = List<PeerBuiltInPrinter>.of(all);
    var changed = false;
    final now = DateTime.now();
    for (final s in stations) {
      final builtIn = s['builtIn'];
      final id = s['id'];
      if (builtIn is! Map || id is! String) continue;
      final name = s['name']?.toString() ?? '';
      final paper = PeerBuiltInPrinter.paperOf(builtIn['paper']);
      var i = list.indexWhere((p) => p.stationId == id);
      // Agent vừa đổi sang mã theo máy: chuyển mục mã cũ sang mã mới.
      if (i < 0 && _adoptReplaced(list, id, s['prev'])) {
        i = list.indexWhere((p) => p.stationId == id);
        changed = true;
      }
      if (i < 0) {
        list.add(
          PeerBuiltInPrinter(
            stationId: id,
            agentName: name,
            paper: paper,
            templates: PeerBuiltInPrinter.templatesOf(
              builtIn['templates'],
              defaultTemplates,
            ),
            enabled: PrintAgentModule.host.storage.get(legacyAllKey) == true,
            lastSeenAt: now,
          ),
        );
        changed = true;
        continue;
      }
      // Chức năng in luôn theo cài đặt trên máy Agent (không cấu hình ở đây).
      final templates = PeerBuiltInPrinter.templatesOf(
        builtIn['templates'],
        list[i].templates,
      );
      if (list[i].agentName != name ||
          list[i].paper != paper ||
          !listEquals(list[i].templates, templates) ||
          now.difference(list[i].lastSeenAt) > const Duration(minutes: 5)) {
        list[i] = list[i].copyWith(
          agentName: name,
          paper: paper,
          templates: templates,
          lastSeenAt: now,
        );
        changed = true;
      }
    }
    if (!changed) return;
    items.assignAll(list);
    _save();
  }

  /// Chuyển mục của mã cũ ([prev] — Agent báo đã thay) sang mã mới [id], giữ
  /// lựa chọn bật / tắt. `true` khi có chuyển.
  static bool _adoptReplaced(
    List<PeerBuiltInPrinter> list,
    String id,
    Object? prev,
  ) {
    if (prev is! List) return false;
    final old = {for (final e in prev) '$e'};
    final i = list.indexWhere((p) => old.contains(p.stationId));
    if (i < 0) return false;
    list[i] = list[i].copyWith(stationId: id);
    list.removeWhere((p) => p.stationId != id && old.contains(p.stationId));
    return true;
  }

  static void setEnabled(String stationId, bool enabled) {
    final list = List<PeerBuiltInPrinter>.of(all);
    final i = list.indexWhere((p) => p.stationId == stationId);
    if (i < 0) return;
    list[i] = list[i].copyWith(enabled: enabled);
    items.assignAll(list);
    _save();
  }
}
