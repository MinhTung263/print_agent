import 'package:print_agent/print_agent.dart';

/// Máy in trên Agent máy tính: máy in đã chọn ở cài đặt (báo cho máy bán hàng
/// là "máy in tích hợp" của Agent này), hoặc máy in LAN của lệnh in hộ.
class DesktopPrinter implements AgentPrinterRef {
  const DesktopPrinter({
    required this.kind,
    required this.address,
    this.name = '',
    this.id,
    this.mac,
  });

  /// Tên máy in của Agent trên sơ đồ.
  static const String builtInName = 'Máy in của Agent';

  final AgentPrinterKind kind;

  /// LAN `ip[:cổng]`, `usb:...` / `queue:...` (xem `UsbPrinters`).
  final String address;
  final String name;
  final Object? id;

  /// MAC máy in LAN (nếu biết) — để tìm lại khi máy in đổi IP.
  final String? mac;

  DesktopPrinter withAddress(String address) => DesktopPrinter(
    kind: kind,
    address: address,
    name: name,
    id: id,
    mac: mac,
  );

  @override
  Object? get refId => id;

  @override
  AgentPrinterKind? get refKind => kind;

  @override
  String? get refAddress => address;

  @override
  String get refName => name;

  @override
  String? get refMac => mac;
}
