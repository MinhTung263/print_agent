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

  /// Cài máy in USB chưa cài ([PrinterOption.setupPort]); trả địa chỉ hoặc
  /// `null` khi không cài được (thiếu quyền quản trị).
  Future<String?> setupUsb(String setupPort);

  /// Mở được cổng in của máy in mạng [ip] không.
  Future<bool> reachable(String ip);

  /// IPv4 nội bộ của máy này (điền sẵn dải mạng khi nhập IP tay).
  Future<String?> localIp();
}
