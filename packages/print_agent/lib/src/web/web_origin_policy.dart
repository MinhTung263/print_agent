/// Trang web nào được gọi cổng web của trạm in (trình duyệt luôn gửi `Origin`
/// khi trang web gọi sang): chỉ trang EasyPOS (`https://easypos.vn` và tên miền
/// con) + các địa chỉ thêm ở [extra] (bản thử nghiệm / chạy trên máy dev).
///
/// Yêu cầu KHÔNG có `Origin` (không phải trình duyệt — chương trình trên chính
/// máy này) được nhận: cổng web chỉ mở trên máy này, trang web lạ không giả được
/// việc không gửi `Origin`.
class WebOriginPolicy {
  const WebOriginPolicy({this.extra = const [], this.allowLocalHttp = false});

  static const String domain = 'easypos.vn';

  /// Origin đầy đủ được thêm, VD `http://localhost:4200`.
  final List<String> extra;

  /// Chỉ cho bản thử nghiệm (debug): nhận cả trang `http://` chạy ở `localhost`
  /// hoặc địa chỉ mạng nội bộ (trang test chạy trên máy dev).
  final bool allowLocalHttp;

  /// Đọc danh sách thêm dạng `a, b` (cấu hình `webOrigins`).
  factory WebOriginPolicy.parse(String? raw, {bool allowLocalHttp = false}) =>
      WebOriginPolicy(
        allowLocalHttp: allowLocalHttp,
        extra: [
          for (final s in (raw ?? '').split(','))
            if (s.trim().isNotEmpty) _strip(s.trim()),
        ],
      );

  bool allows(String? origin) {
    if (origin == null || origin.isEmpty) return true;
    if (extra.contains(_strip(origin))) return true;
    final uri = Uri.tryParse(origin);
    if (uri == null) return false;
    if (allowLocalHttp && uri.scheme == 'http' && _isLocalHost(uri.host)) {
      return true;
    }
    if (uri.scheme != 'https') return false;
    return uri.host == domain || uri.host.endsWith('.$domain');
  }

  static String _strip(String origin) =>
      origin.endsWith('/') ? origin.substring(0, origin.length - 1) : origin;

  static bool _isLocalHost(String host) {
    if (host == 'localhost' || host == '127.0.0.1') return true;
    final o = host.split('.').map(int.tryParse).toList();
    if (o.length != 4 || o.any((v) => v == null || v < 0 || v > 255)) {
      return false;
    }
    return o[0] == 10 ||
        (o[0] == 172 && o[1]! >= 16 && o[1]! <= 31) ||
        (o[0] == 192 && o[1] == 168);
  }
}
