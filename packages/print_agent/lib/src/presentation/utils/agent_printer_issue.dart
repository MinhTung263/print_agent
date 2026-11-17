import 'package:print_agent/src/agent_domain.dart';

/// Máy in đang lỗi kết nối: mất kết nối / ở mạng khác — và còn nhận lệnh (máy in đã tắt nhận
/// lệnh ([AgentPrinterSwitches]) không tính là lỗi). Xử lý ngay ở chi tiết máy in trên sơ
/// đồ ("Kết nối lại" / "Đổi mạng").
abstract final class AgentPrinterIssue {
  static bool isIssue(AgentPrinterStatus<AgentPrinterRef> s) =>
      isConnectionLost(s.state) && AgentPrinterSwitches.isOn(s.printer);

  /// Trạng thái mất kết nối (chưa tính máy đã tắt nhận lệnh).
  static bool isConnectionLost(AgentPrinterState state) =>
      state == AgentPrinterState.disconnected ||
      state == AgentPrinterState.otherNetwork;
}
