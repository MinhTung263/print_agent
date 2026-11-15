import '../print_agent_module.dart';
import 'package:get/get.dart';

/// Thứ tự người dùng tự sắp trên sơ đồ Agent của cửa hàng: thứ tự các máy Agent
/// + thứ tự máy in trong từng Agent. Chỉ đổi cách HIỂN THỊ (không đổi Agent nào in
/// máy in nào). Agent / máy in chưa sắp nằm cuối theo thứ tự mặc định. Lưu trên
/// máy này theo cửa hàng.
abstract final class AgentMapLayout {
  /// Mã Agent theo thứ tự đã sắp.
  static final RxList<String> agents = <String>[].obs;

  /// Mã Agent → khoá máy in ([printerKey]) theo thứ tự đã sắp.
  static final RxMap<String, List<String>> printers =
      <String, List<String>>{}.obs;

  static String? _loadedFor;

  static String get _storageKey =>
      'agent_map_layout_${PrintAgentModule.host.companyKey}';

  /// Đọc thứ tự của cửa hàng đang đăng nhập — gọi NGOÀI lúc dựng giao diện.
  static void ensureLoaded() {
    final key = _storageKey;
    if (_loadedFor == key) return;
    _loadedFor = key;
    try {
      final raw = PrintAgentModule.host.storage.get(key);
      final map = raw is Map ? raw : const {};
      agents.assignAll([
        if (map['agents'] is List)
          for (final e in map['agents'] as List)
            if (e is String) e,
      ]);
      printers.assignAll({
        if (map['printers'] is Map)
          for (final e in (map['printers'] as Map).entries)
            if (e.value is List)
              '${e.key}': [
                for (final p in e.value as List)
                  if (p is String) p,
              ],
      });
    } catch (_) {
      agents.clear();
      printers.clear();
    }
  }

  /// Khoá nhận diện một máy in trên sơ đồ: loại + địa chỉ + tên (ổn định giữa
  /// các lần Agent báo lại).
  static String printerKey({
    required Object? kind,
    required Object? address,
    required Object? name,
  }) => '${kind ?? 'lan'}|${address ?? ''}|${name ?? ''}';

  /// Sắp [items] theo thứ tự đã lưu [order] (khoá [keyOf]); mục chưa sắp giữ thứ
  /// tự gốc ở cuối.
  static List<T> sorted<T>(
    List<T> items,
    List<String> order,
    String Function(T) keyOf,
  ) {
    if (order.isEmpty) return items;
    final index = {for (var i = 0; i < order.length; i++) order[i]: i};
    final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
    indexed.sort((a, b) {
      final ia = index[keyOf(a.$2)] ?? order.length + a.$1;
      final ib = index[keyOf(b.$2)] ?? order.length + b.$1;
      return ia.compareTo(ib);
    });
    return [for (final e in indexed) e.$2];
  }

  /// Lưu thứ tự mới.
  static Future<void> save({
    required List<String> agentOrder,
    required Map<String, List<String>> printerOrder,
  }) async {
    ensureLoaded();
    agents.assignAll(agentOrder);
    printers.assignAll(printerOrder);
    try {
      await PrintAgentModule.host.storage.put(_storageKey, {
        'agents': agentOrder,
        'printers': printerOrder,
      });
    } catch (_) {}
  }

  /// Về thứ tự mặc định.
  static Future<void> reset() =>
      save(agentOrder: const [], printerOrder: const {});
}
