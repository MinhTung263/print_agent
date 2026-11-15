import '../entities/agent_printer_ref.dart';

/// Cổng tới dịch vụ máy in của app chủ — module Agent canh / nối lại máy in qua
/// đây mà không biết app in bằng gì. [P] là kiểu máy in của app (VD
/// `PrinterEntity`), nên phía app vẫn làm việc với đúng kiểu của mình.
abstract interface class AgentPrinterGateway<P extends AgentPrinterRef> {
  /// Máy in đã lưu trên máy này.
  List<P> get printers;

  /// Thiết bị có máy in tích hợp (Sunmi / T1-G...).
  bool get hasBuiltIn;

  /// Máy in tích hợp đang kết nối.
  bool get builtInConnected;

  /// Phát mỗi khi máy in tích hợp đổi trạng thái kết nối.
  Stream<bool> get builtInChanges;

  /// Máy in tích hợp dưới dạng máy in của app.
  P builtInPrinter();

  /// Khởi động lại kết nối máy in tích hợp.
  Future<void> reconnectBuiltIn();

  Future<bool> isUsbAttached(P printer);

  /// Xin quyền (nếu cần) rồi kết nối máy in USB.
  Future<bool> connectUsb(P printer);

  /// Máy in kết nối được ngay không (không báo lỗi lên giao diện).
  Future<bool> isReady(P printer);

  /// Tìm lại máy in LAN theo MAC khi đổi IP; trả máy in với IP mới (đã lưu)
  /// hoặc `null` khi không thấy.
  Future<P?> relocate(P printer, {Duration? timeout});

  /// Wi-Fi của máy in LAN (nếu app đã nhớ) — để gợi ý chuyển mạng.
  String? wifiSsidOf(P printer);

  /// Phát khi thiết bị đổi mạng (Wi-Fi / dây / 4G).
  Stream<void> get networkChanges;

  /// Phát khi danh sách / máy in tích hợp của máy này đổi (báo lại cho máy khác).
  Stream<void> get printersChanged;
}
