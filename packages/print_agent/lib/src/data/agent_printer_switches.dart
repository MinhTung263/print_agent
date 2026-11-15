import '../print_agent_module.dart';
import 'package:get/get.dart';
import 'package:print_agent_core/print_agent_core.dart';

import '../domain/entities/agent_printer_ref.dart';

/// Máy Agent: bật / tắt nhanh từng máy in mà Agent này nhận lệnh in hộ (VD tạm
/// không nhận lệnh cho máy in bếp đang sửa). Máy in tắt: trạm bỏ qua lệnh tới
/// máy đó — Agent khác (nếu có) vẫn nhận; lệnh nhắm thẳng Agent này báo lỗi
/// ngay. Mặc định mọi máy in đều bật. Lưu trên máy này theo công ty.
abstract final class AgentPrinterSwitches {
  /// Khoá các máy in đang TẮT ([keyOf]).
  static final RxSet<String> off = <String>{}.obs;

  static String? _loadedFor;

  static String get _storageKey =>
      'agent_printer_off_${PrintAgentModule.host.companyKey}';

  /// Đọc danh sách của công ty đang đăng nhập — gọi NGOÀI lúc dựng giao diện.
  static void ensureLoaded() {
    final key = _storageKey;
    if (_loadedFor == key) return;
    _loadedFor = key;
    try {
      final raw = PrintAgentModule.host.storage.get(key);
      off.assignAll([
        if (raw is List)
          for (final e in raw)
            if (e is String) e,
      ]);
    } catch (_) {
      off.clear();
    }
  }

  /// Khoá nhận diện một máy in: tích hợp / mã máy in đã lưu / USB / IP.
  static String keyOf(AgentPrinterRef p) {
    if (p.refKind == AgentPrinterKind.builtIn) return 'builtin';
    if (p.refId != null) return 'id:${p.refId}';
    if (p.refKind == AgentPrinterKind.usb) return 'usb';
    return 'ip:${p.refAddress?.trim() ?? ''}';
  }

  static bool isOn(AgentPrinterRef p) => !off.contains(keyOf(p));

  static Future<void> setOn(AgentPrinterRef p, bool on) =>
      setKeyOn(keyOf(p), on);

  /// Bật / tắt theo khoá [keyOf] — máy khác điều khiển từ xa gửi khoá này.
  static Future<void> setKeyOn(String key, bool on) async {
    ensureLoaded();
    on ? off.remove(key) : off.add(key);
    try {
      await PrintAgentModule.host.storage.put(_storageKey, off.toList());
    } catch (_) {}
  }

  /// Lệnh tới máy in [target] có được nhận không (máy in đó đang bật).
  static bool accepts(PrintRelayPrinter target) {
    ensureLoaded();
    if (off.isEmpty) return true;
    if (target.isBuiltIn) return !off.contains('builtin');
    if (target.id != null && off.contains('id:${target.id}')) return false;
    if (target.isUsb) return !off.contains('usb');
    final ip = target.address.trim();
    if (off.contains('ip:$ip')) return false;
    // Lệnh không kèm mã máy in: tra máy in đã lưu theo IP.
    final saved = PrintAgentModule.host.printers.firstWhereOrNull(
      (p) => p.refAddress?.trim() == ip,
    );
    return saved == null || isOn(saved);
  }
}
