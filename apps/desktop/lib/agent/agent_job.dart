/// Một lệnh in đã xử lý (nhật ký).
class AgentJobEntry {
  const AgentJobEntry({
    required this.at,
    required this.ok,
    this.sender,
    this.printerName,
    this.copies = 1,
    this.error,
  });

  final DateTime at;
  final bool ok;
  final String? sender;
  final String? printerName;
  final int copies;
  final String? error;
}

enum AgentState { off, connecting, online, offline }

enum AgentPrintPhase { printing, done, failed }

/// Lệnh in đang chạy / vừa xong — để sơ đồ làm nổi máy in (giống app).
class AgentPrintActivity {
  const AgentPrintActivity(this.phase, this.sender);

  final AgentPrintPhase phase;
  final String? sender;
}
