/// Một máy Agent máy này từng thấy: thông tin Agent báo lần cuối khi trực tuyến
/// (tên, máy in tích hợp, số máy in...) + lúc thấy cuối.
class KnownAgent {
  const KnownAgent({required this.info, required this.lastSeenAt});

  /// Thông tin trạm (`{id, name, builtIn, printers, ...}`) lần cuối trực tuyến.
  final Map<Object?, Object?> info;
  final DateTime lastSeenAt;

  String get id => info['id']?.toString() ?? '';

  Map<String, Object?> toMap() => {
    'info': _plain(info),
    'seen': lastSeenAt.millisecondsSinceEpoch,
  };

  static KnownAgent? fromMap(Object? raw) {
    if (raw is! Map || raw['info'] is! Map || raw['seen'] is! int) return null;
    final info = Map<Object?, Object?>.from(raw['info'] as Map);
    if (info['id'] is! String) return null;
    return KnownAgent(
      info: info,
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(raw['seen'] as int),
    );
  }

  /// Bỏ phần không lưu được (giữ Map / List / chuỗi / số / bool).
  static Object? _plain(Object? v) => switch (v) {
    final Map m => {for (final e in m.entries) '${e.key}': _plain(e.value)},
    final List l => [for (final e in l) _plain(e)],
    String() || num() || bool() || null => v,
    _ => '$v',
  };
}
