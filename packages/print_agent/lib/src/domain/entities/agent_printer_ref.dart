/// Kiểu kết nối máy in, theo cách module Agent nhìn.
enum AgentPrinterKind { lan, bluetooth, usb, builtIn }

/// Máy in đã lưu của app chủ, đủ để module Agent nhận diện: app chủ cho thực
/// thể máy in của mình cài giao diện này (VD `PrinterEntity implements
/// AgentPrinterRef`), module không phụ thuộc mô hình máy in của app.
abstract interface class AgentPrinterRef {
  /// Mã máy in đã lưu (`null` với máy chưa lưu).
  Object? get refId;

  AgentPrinterKind? get refKind;

  /// IP (máy LAN) / mã thiết bị.
  String? get refAddress;

  /// Tên hiển thị (rỗng khi chưa đặt).
  String get refName;

  /// MAC máy in LAN (để tìm lại khi đổi IP); `null` khi không có.
  String? get refMac;
}

extension AgentPrinterRefDisplay on AgentPrinterRef {
  /// [refName], rỗng thì `null`.
  String? get nameOrNull => refName.isEmpty ? null : refName;
}
