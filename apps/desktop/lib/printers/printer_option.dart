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
  });

  factory PrinterOption.lan(
    String address, {
    bool manual = false,
    String? model,
  }) => PrinterOption(
    kind: PrinterOptionKind.lan,
    address: address,
    title: (model ?? '').trim().isNotEmpty
        ? model!.trim()
        : (manual ? 'Máy in nhập tay' : 'Máy in mạng (LAN)'),
    subtitle: address,
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

  bool get needsSetup => setupPort != null;

  /// Khoá chọn: địa chỉ, hoặc cổng cài đặt với máy chưa cài.
  String get key => address.isNotEmpty ? address : 'setup:$setupPort';
}
