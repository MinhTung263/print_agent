import '../agent/printer_type.dart';

enum PrinterOptionKind { lan, usb }

/// Một máy in trong hộp chọn: LAN dò thấy / nhập tay, hoặc USB (tầng domain —
/// không phụ thuộc plugin / giao diện).
class PrinterOption {
  const PrinterOption({
    required this.kind,
    required this.address,
    required this.title,
    required this.subtitle,
    this.setupPort,
    this.type,
    this.warning,
  });

  factory PrinterOption.lan(
    String address, {
    bool manual = false,
    String? model,
    PrinterType? type,
    String? warning,
  }) => PrinterOption(
    kind: PrinterOptionKind.lan,
    address: address,
    title: (model ?? '').trim().isNotEmpty
        ? model!.trim()
        : (manual ? 'Máy in nhập tay' : 'Máy in mạng (LAN)'),
    subtitle: address,
    type: type,
    warning: warning,
  );

  /// Máy in USB; [setupPort] khác `null` = chưa cài đặt (cài một lần).
  factory PrinterOption.usb({
    required String address,
    required String name,
    String? setupPort,
    bool missing = false,
  }) => PrinterOption(
    kind: PrinterOptionKind.usb,
    address: address,
    title: name,
    subtitle: missing
        ? 'Cắm USB · chưa thấy máy in'
        : (setupPort != null ? 'Cắm USB · cần cài đặt một lần' : 'Cắm USB'),
    setupPort: setupPort,
  );

  final PrinterOptionKind kind;

  /// Địa chỉ lưu cấu hình; rỗng với máy USB chưa cài đặt.
  final String address;
  final String title;
  final String subtitle;

  /// Máy USB chưa có hàng in: cổng / URI để cài đặt.
  final String? setupPort;

  /// Loại máy in đã nhận ra (tem / hoá đơn); `null` = chưa rõ hoặc đang dò.
  final PrinterType? type;

  /// Máy in có vấn đề (IP bị thiết bị khác dùng, không kết nối được): hiện lý do, không
  /// chọn được.
  final String? warning;

  bool get blocked => warning != null;

  PrinterOption withType(PrinterType? type) => PrinterOption(
    kind: kind,
    address: address,
    title: title,
    subtitle: subtitle,
    setupPort: setupPort,
    type: type,
    warning: warning,
  );

  bool get needsSetup => setupPort != null;

  /// Khoá chọn: địa chỉ, hoặc cổng cài đặt với máy chưa cài.
  String get key => address.isNotEmpty ? address : 'setup:$setupPort';
}
