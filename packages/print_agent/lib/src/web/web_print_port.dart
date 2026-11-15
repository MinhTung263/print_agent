import 'web_print_request.dart';

/// Kết quả in một lệnh của trang web (trả trong `status`).
enum WebPrintStatus {
  /// Đã in xong.
  done,

  /// Máy in hết giấy / mở nắp: trạm GIỮ lệnh, tự in khi máy in sẵn sàng lại —
  /// trang web KHÔNG gửi lại (gửi lại cùng `jobId` cũng không in đúp).
  held,

  /// In lỗi (máy in tắt, mất kết nối...) — kiểm tra máy in rồi in lại.
  failed,

  /// Trạm in chưa đăng nhập / đang tắt.
  off,

  /// Trạm in chưa chọn máy in.
  noPrinter,

  /// Trạm in đang đăng nhập cửa hàng khác `companyId` của trang web.
  wrongCompany,
}

class WebPrintResult {
  const WebPrintResult(this.status, {this.message});

  final WebPrintStatus status;

  /// Lý do bằng lời cho người bán hàng (nếu có).
  final String? message;

  Map<String, Object?> toJson() => {'status': status.name, 'message': ?message};
}

/// Phần trạm in mà cổng web dùng (tách khỏi máy chủ HTTP để test được).
abstract interface class WebPrintPort {
  /// Thông tin trạm + danh sách máy in cho trang web chọn (`GET /v1/info`).
  Map<String, Object?> info();

  Future<WebPrintResult> print(WebPrintRequest request);
}
