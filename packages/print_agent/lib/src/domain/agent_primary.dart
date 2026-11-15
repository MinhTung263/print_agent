/// Bầu TRẠM IN CHÍNH khi nhiều trạm in cùng một mạng: máy in LAN phổ thông chỉ
/// nhận một kết nối cổng 9100 một lúc — trạm chính canh máy in dày, các trạm
/// dự phòng canh thưa; đơn tự động (ShopeeFood, GrabFood, QR tại bàn) chỉ trạm
/// chính in để không ra 2–3 phiếu.
///
/// Mỗi trạm báo trong thông tin trạm: `rank` (ưu tiên: máy tính > Android >
/// iOS) và `net` (các dải mạng của trạm). Trong các trạm đang bật CÙNG dải,
/// trạm `rank` cao nhất là trạm chính; bằng nhau thì mã trạm nhỏ hơn. Trạm
/// bản cũ (không báo `rank`) không tham gia bầu.
abstract final class AgentPrimary {
  static const int rankDesktop = 30;
  static const int rankAndroid = 20;
  static const int rankOther = 10;

  /// Máy này ([selfId], [selfRank], dải mạng [selfNets]) có phải trạm chính
  /// giữa các trạm đang bật [stations] (thông tin trạm, có thể gồm chính máy
  /// này) không.
  static bool isPrimary({
    required String selfId,
    required int selfRank,
    required Set<String> selfNets,
    required Iterable<Map<Object?, Object?>> stations,
  }) {
    if (selfNets.isEmpty) return true;
    for (final s in stations) {
      final id = s['id']?.toString() ?? '';
      if (id.isEmpty || id == selfId) continue;
      final rank = s['rank'];
      if (rank is! int) continue;
      final nets = s['net'];
      if (nets is! List || !nets.any((n) => selfNets.contains('$n'))) {
        continue;
      }
      if (rank > selfRank || (rank == selfRank && id.compareTo(selfId) < 0)) {
        return false;
      }
    }
    return true;
  }

  /// Dải mạng (3 số đầu của IPv4) của các địa chỉ [ips].
  static Set<String> netsOf(Iterable<String> ips) => {
    for (final ip in ips)
      if (ip.split('.').length == 4) ip.split('.').take(3).join('.'),
  };
}
