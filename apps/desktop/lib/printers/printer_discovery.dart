import '../agent/printer_type.dart';
import 'printer_option.dart';

/// Cổng tìm / cài máy in của trạm in máy tính (domain). Giao diện chỉ dùng cổng
/// này — cài đặt cụ thể (plugin printer_label, mạng của máy) ở tầng dữ liệu
/// ([DesktopPrinterDiscovery]); test thay bằng bản giả.
abstract interface class PrinterDiscovery {
  /// Dò cùng lúc máy in mạng (cổng 9100) và máy in USB.
  Future<List<PrinterOption>> find();

  /// Thẻ cho máy in đang dùng mà lượt dò không thấy (tắt / khác mạng).
  PrinterOption missing(String address);

  /// Tên model máy in mạng ở [address] (không gửi gì vào cổng in); `null` khi
  /// không đọc được.
  Future<String?> modelOf(String address);

  /// Máy in mạng ở [address] là máy in tem hay máy in hoá đơn (hỏi trạng thái, không
  /// in gì); `null` khi chưa rõ. [model] (nếu đã biết) giúp đoán khi máy không trả lời.
  Future<PrinterType?> typeOf(String address, {String? model});

  /// Cài máy in USB chưa cài ([PrinterOption.setupPort]); trả địa chỉ hoặc
  /// `null` khi không cài được (thiếu quyền quản trị).
  Future<String?> setupUsb(String setupPort);

  /// Lý do lần [setupUsb] gần nhất thất bại (hệ điều hành báo); `null` = không rõ.
  String? get setupError => null;

  /// Mở được cổng in của máy in mạng [ip] không.
  Future<bool> reachable(String ip);

  /// Các dải mạng máy này đang quét tìm máy in (VD `192.168.1.x`) — hiện cho người
  /// dùng biết máy in phải cùng dải này.
  Future<List<String>> scannedNetworks();

  /// IPv4 nội bộ của máy này (điền sẵn dải mạng khi nhập IP tay).
  Future<String?> localIp();
}
