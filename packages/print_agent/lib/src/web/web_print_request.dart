import 'dart:convert';
import 'dart:typed_data';

/// Yêu cầu sai định dạng (trả `400` kèm [code] cho trang web).
class WebRequestError implements Exception {
  const WebRequestError(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'WebRequestError($code): $message';
}

/// Máy in đích trang web chọn: máy in của trạm in, hoặc một máy in LAN.
class WebPrintTarget {
  const WebPrintTarget.builtIn() : lanAddress = null;
  const WebPrintTarget.lan(String this.lanAddress);

  /// `ip` hoặc `ip:cổng`; `null` = máy in của trạm in.
  final String? lanAddress;

  bool get isBuiltIn => lanAddress == null;

  /// Mã máy in trong danh sách `/v1/info`: `builtin` / `lan:<ip[:cổng]>`.
  String get id => isBuiltIn ? builtInId : '$lanPrefix$lanAddress';

  static const String builtInId = 'builtin';
  static const String lanPrefix = 'lan:';

  /// Đọc mã máy in; chỉ nhận IPv4 mạng nội bộ (không cho trang web gửi tới
  /// địa chỉ bất kỳ).
  static WebPrintTarget parse(Object? raw) {
    if (raw == null || raw == builtInId || raw == '') {
      return const WebPrintTarget.builtIn();
    }
    final s = raw.toString().trim();
    if (s.startsWith(lanPrefix)) {
      final address = s.substring(lanPrefix.length);
      if (isPrivateAddress(address)) return WebPrintTarget.lan(address);
    }
    throw WebRequestError('badPrinter', 'Máy in không hợp lệ: $s');
  }

  /// `ip[:cổng]` IPv4 thuộc dải nội bộ (10/8, 172.16/12, 192.168/16).
  static bool isPrivateAddress(String address) {
    final parts = address.split(':');
    if (parts.length > 2) return false;
    if (parts.length == 2) {
      final port = int.tryParse(parts[1]);
      if (port == null || port < 1 || port > 65535) return false;
    }
    final octets = parts[0].split('.').map(int.tryParse).toList();
    if (octets.length != 4 ||
        octets.any((o) => o == null || o < 0 || o > 255)) {
      return false;
    }
    final a = octets[0]!, b = octets[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }
}

/// Lệnh in hoá đơn trang web gửi (`POST /v1/print`, JSON):
///
/// ```json
/// {
///   "jobId": "HD0001-1700000000",  // bắt buộc, gửi lại cùng mã không in đúp
///   "image": "<PNG/JPEG base64 hoặc data URL>",
///   "printer": "builtin",          // hoặc "lan:192.168.1.50"
///   "paper": "size80",             // size80 | size58, mặc định khổ của trạm
///   "copies": 1, "openDrawer": false, "beep": false,
///   "companyId": 123,              // có thì trạm kiểm tra đúng cửa hàng
///   "sender": "Quầy thu ngân"
/// }
/// ```
class WebPrintRequest {
  const WebPrintRequest({
    required this.jobId,
    required this.image,
    this.target = const WebPrintTarget.builtIn(),
    this.paper,
    this.copies = 1,
    this.openDrawer = false,
    this.beep = false,
    this.companyId,
    this.sender,
  });

  static const int maxCopies = 10;
  static final RegExp _jobId = RegExp(r'^[A-Za-z0-9_.:\-]{1,80}$');

  final String jobId;
  final Uint8List image;
  final WebPrintTarget target;

  /// `size80` / `size58`; `null` = khổ giấy đã chọn ở trạm in.
  final String? paper;
  final int copies;
  final bool openDrawer;
  final bool beep;
  final int? companyId;
  final String? sender;

  static WebPrintRequest parse(Object? json) {
    if (json is! Map) {
      throw const WebRequestError('badRequest', 'Cần JSON object');
    }
    final jobId = json['jobId']?.toString() ?? '';
    if (!_jobId.hasMatch(jobId)) {
      throw const WebRequestError(
        'badJobId',
        'jobId bắt buộc: 1–80 ký tự chữ, số, _ . : -',
      );
    }
    final paper = json['paper']?.toString();
    if (paper != null && paper != 'size80' && paper != 'size58') {
      throw WebRequestError('badPaper', 'Khổ giấy không hợp lệ: $paper');
    }
    final copies = json['copies'] ?? 1;
    if (copies is! int || copies < 1 || copies > maxCopies) {
      throw const WebRequestError('badCopies', 'copies từ 1 tới $maxCopies');
    }
    final company = json['companyId'];
    final sender = json['sender']?.toString().trim();
    return WebPrintRequest(
      jobId: jobId,
      image: _image(json['image']),
      target: WebPrintTarget.parse(json['printer']),
      paper: paper,
      copies: copies,
      openDrawer: json['openDrawer'] == true,
      beep: json['beep'] == true,
      companyId: company is int ? company : int.tryParse('${company ?? ''}'),
      sender: (sender == null || sender.isEmpty)
          ? null
          : (sender.length > 60 ? sender.substring(0, 60) : sender),
    );
  }

  static Uint8List _image(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      throw const WebRequestError('noImage', 'Thiếu ảnh phiếu (image)');
    }
    final comma = raw.startsWith('data:') ? raw.indexOf(',') : -1;
    try {
      final bytes = base64Decode(comma < 0 ? raw : raw.substring(comma + 1));
      if (bytes.isEmpty) throw const FormatException();
      return bytes;
    } on FormatException {
      throw const WebRequestError('badImage', 'Ảnh phiếu không phải base64');
    }
  }
}
