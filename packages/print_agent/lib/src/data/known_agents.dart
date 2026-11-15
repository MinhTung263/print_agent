import '../print_agent_module.dart';
import 'package:get/get.dart';

import '../domain/entities/known_agent.dart';
import 'agent_device_identity.dart';

/// Các máy Agent của công ty mà máy này từng thấy — để Agent TẮT vẫn hiện (ngoại
/// tuyến, lần thấy cuối) thay vì biến mất khỏi sơ đồ. Ngoại tuyến quá
/// [_forgetAfter] thì tự bỏ (máy đã thôi dùng). Lưu trên máy này theo công ty.
abstract final class KnownAgents {
  static const Duration _forgetAfter = Duration(days: 7);

  static final RxList<KnownAgent> items = <KnownAgent>[].obs;

  static String? _loadedFor;

  /// Agent đang trực tuyến ở lần [sync] trước — Agent vừa biến mất thì lần thấy
  /// cuối chính là lúc này (không phải lần ghi bộ nhớ trước đó).
  static Set<String> _online = {};

  /// Agent [id] đang trực tuyến (theo lần [sync] gần nhất).
  static bool isOnline(String id) => _online.contains(id);

  static String get _storageKey =>
      'known_agents_${PrintAgentModule.host.companyKey}';

  /// Đọc danh sách của công ty đang đăng nhập — gọi NGOÀI lúc dựng giao diện.
  static void ensureLoaded() {
    final key = _storageKey;
    if (_loadedFor == key) return;
    _loadedFor = key;
    try {
      final raw = PrintAgentModule.host.storage.get(key);
      final now = DateTime.now();
      items.assignAll([
        if (raw is List)
          for (final e in raw)
            if (KnownAgent.fromMap(e) case final a?)
              if (now.difference(a.lastSeenAt) < _forgetAfter) a,
      ]);
    } catch (_) {
      items.clear();
    }
  }

  /// Cập nhật theo các Agent đang trực tuyến: thêm Agent mới, cập nhật thông tin
  /// + lần thấy cuối. Chỉ ghi bộ nhớ khi có Agent mới / thông tin đổi / lần thấy
  /// cuối đã cũ (khỏi ghi liên tục).
  static void sync(List<Map<Object?, Object?>> online) {
    ensureLoaded();
    final list = List<KnownAgent>.of(items);
    final now = DateTime.now();
    var changed = false;
    // Agent đã đổi sang mã theo máy: bỏ mục mã cũ (cùng một máy, khỏi hiện 2).
    final replaced = AgentDeviceIdentity.replacedIds(online);
    if (replaced.isNotEmpty) {
      final before = list.length;
      list.removeWhere((a) => replaced.contains(a.id));
      changed = list.length != before;
    }
    final onlineIds = {
      for (final info in online)
        if (info['id'] case final String id when id.isNotEmpty) id,
    };
    for (var i = 0; i < list.length; i++) {
      if (_online.contains(list[i].id) && !onlineIds.contains(list[i].id)) {
        list[i] = KnownAgent(info: list[i].info, lastSeenAt: now);
        changed = true;
      }
    }
    _online = onlineIds;
    for (final info in online) {
      final id = info['id'];
      if (id is! String || id.isEmpty) continue;
      final i = list.indexWhere((a) => a.id == id);
      final next = KnownAgent(info: Map.of(info), lastSeenAt: now);
      if (i < 0) {
        list.add(next);
        changed = true;
      } else if (!_sameInfo(list[i].info, info) ||
          now.difference(list[i].lastSeenAt) > const Duration(minutes: 1)) {
        list[i] = next;
        changed = true;
      }
    }
    if (!changed) return;
    items.assignAll(list);
    try {
      PrintAgentModule.host.storage.put(_storageKey, [
        for (final a in list) a.toMap(),
      ]);
    } catch (_) {}
  }

  /// Quên Agent [id] trên máy này (Agent đã thôi dùng / mã cũ). Trả mục đã bỏ
  /// để hoàn tác ([restore]); Agent bật lại sẽ tự hiện lại.
  static KnownAgent? forget(String id) {
    ensureLoaded();
    final removed = items.firstWhereOrNull((a) => a.id == id);
    if (removed == null) return null;
    items.removeWhere((a) => a.id == id);
    _persist();
    return removed;
  }

  /// Hoàn tác [forget].
  static void restore(KnownAgent agent) {
    ensureLoaded();
    if (items.any((a) => a.id == agent.id)) return;
    items.add(agent);
    _persist();
  }

  static void _persist() {
    try {
      PrintAgentModule.host.storage.put(_storageKey, [
        for (final a in items) a.toMap(),
      ]);
    } catch (_) {}
  }

  static bool _sameInfo(Map<Object?, Object?> a, Map<Object?, Object?> b) {
    for (final k in ['name', 'builtIn', 'printers']) {
      if ('${a[k]}' != '${b[k]}') return false;
    }
    return true;
  }
}
