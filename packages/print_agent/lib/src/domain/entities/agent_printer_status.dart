import 'agent_printer_ref.dart';

/// Trạng thái kết nối của một máy in trên máy Agent.
enum AgentPrinterState {
  /// Agent tới được máy in.
  connected,

  /// Máy in tắt / mất mạng (đang chờ máy in bật lại, tự tìm lại theo MAC).
  disconnected,

  /// Máy in LAN ở mạng khác — Agent này không in tới được.
  otherNetwork,

  /// Chưa kiểm tra.
  checking,
}

/// Một dòng ở màn quản lý máy Agent.
class AgentPrinterStatus<P extends AgentPrinterRef> {
  const AgentPrinterStatus({
    required this.printer,
    required this.state,
    this.checkedAt,
    this.note,
  });

  final P printer;
  final AgentPrinterState state;
  final DateTime? checkedAt;

  /// Ghi chú thêm (VD "Đổi IP 192.168.1.10 → 192.168.1.23").
  final String? note;
}
