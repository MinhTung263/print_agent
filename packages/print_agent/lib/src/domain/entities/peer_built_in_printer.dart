/// Máy in tích hợp của một máy Agent KHÁC, dùng như một máy in của máy này:
/// chỉ bật / tắt (lưu trên máy này); chức năng in, khổ giấy theo máy Agent.
class PeerBuiltInPrinter {
  const PeerBuiltInPrinter({
    required this.stationId,
    required this.agentName,
    required this.paper,
    required this.templates,
    required this.enabled,
    required this.lastSeenAt,
  });

  /// Tiền tố địa chỉ của máy in ảo (`station:<mã Agent>`).
  static const String addressPrefix = 'station:';

  final String stationId;

  /// Tên máy Agent (VD "T1-G"); rỗng khi Agent chưa đặt tên.
  final String agentName;

  /// Tên khổ giấy của app (`size58` / `size80`).
  final String paper;

  /// Chức năng in (tên) — theo cài đặt trên máy Agent.
  final List<String> templates;

  /// Người dùng đã bật dùng máy in này để in.
  final bool enabled;

  /// Lần cuối thấy Agent trực tuyến.
  final DateTime lastSeenAt;

  bool get is80mm => paper == 'size80';

  /// Địa chỉ máy in ảo — lệnh vào đây đi thẳng tới đúng Agent.
  String get address => '$addressPrefix$stationId';

  /// Mã Agent từ địa chỉ máy in ảo; `null` khi không phải máy in ảo.
  static String? stationIdOf(String? address) =>
      address != null && address.startsWith(addressPrefix)
      ? address.substring(addressPrefix.length)
      : null;

  PeerBuiltInPrinter copyWith({
    String? stationId,
    String? agentName,
    String? paper,
    List<String>? templates,
    bool? enabled,
    DateTime? lastSeenAt,
  }) => PeerBuiltInPrinter(
    stationId: stationId ?? this.stationId,
    agentName: agentName ?? this.agentName,
    paper: paper ?? this.paper,
    templates: templates ?? this.templates,
    enabled: enabled ?? this.enabled,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
  );

  Map<String, Object?> toMap() => {
    'id': stationId,
    'name': agentName,
    'paper': paper,
    'templates': templates,
    'enabled': enabled,
    'seen': lastSeenAt.millisecondsSinceEpoch,
  };

  /// Khổ giấy hợp lệ từ dữ liệu Agent báo / đã lưu.
  static String paperOf(Object? name) => name == 'size80' ? 'size80' : 'size58';

  static List<String> templatesOf(Object? raw, List<String> fallback) =>
      raw is List ? [for (final t in raw) '$t'] : fallback;

  static PeerBuiltInPrinter? fromMap(Object? raw, List<String> fallback) {
    if (raw is! Map || raw['id'] is! String) return null;
    return PeerBuiltInPrinter(
      stationId: raw['id'] as String,
      agentName: raw['name']?.toString() ?? '',
      paper: paperOf(raw['paper']),
      templates: templatesOf(raw['templates'], fallback),
      enabled: raw['enabled'] == true,
      lastSeenAt: DateTime.fromMillisecondsSinceEpoch(
        raw['seen'] is int ? raw['seen'] as int : 0,
      ),
    );
  }
}
