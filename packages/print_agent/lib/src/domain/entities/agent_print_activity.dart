import 'agent_printer_ref.dart';

/// Giai đoạn một lệnh in hộ trên máy Agent.
enum AgentPrintPhase { printing, done, failed }

/// Một lệnh in hộ đang chạy / vừa xong — để sơ đồ máy Agent làm nổi máy in đang
/// nhận lệnh (máy nào gửi, hoá đơn hay tem, kết quả).
class AgentPrintActivity {
  const AgentPrintActivity({
    required this.seq,
    required this.phase,
    required this.isLabel,
    required this.builtIn,
    required this.usb,
    required this.ips,
    this.printerId,
    this.sender,
  });

  final int seq;
  final AgentPrintPhase phase;
  final bool isLabel;
  final bool builtIn;
  final bool usb;

  /// IP máy in (cả IP mới khi máy in đổi IP lúc in).
  final Set<String> ips;
  final Object? printerId;
  final String? sender;

  bool get active => phase == AgentPrintPhase.printing;

  /// Lệnh này in ra máy in [p] (nút trên sơ đồ) không.
  bool matches(AgentPrinterRef p) {
    if (builtIn) return p.refKind == AgentPrinterKind.builtIn;
    if (p.refKind == AgentPrinterKind.builtIn) return false;
    if (printerId != null && p.refId != null && '${p.refId}' == '$printerId') {
      return true;
    }
    if (usb) return p.refKind == AgentPrinterKind.usb;
    final ip = p.refAddress?.trim() ?? '';
    return ip.isNotEmpty && ips.contains(ip);
  }

  AgentPrintActivity copyWith({AgentPrintPhase? phase, Set<String>? ips}) =>
      AgentPrintActivity(
        seq: seq,
        phase: phase ?? this.phase,
        isLabel: isLabel,
        builtIn: builtIn,
        usb: usb,
        ips: ips ?? this.ips,
        printerId: printerId,
        sender: sender,
      );
}
