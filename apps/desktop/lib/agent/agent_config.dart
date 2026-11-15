import 'agent_store.dart';
import 'paper_size.dart';

export 'paper_size.dart';

/// Cấu hình Agent desktop, lưu ở [AgentStore].
class AgentConfig {
  const AgentConfig({
    this.env = 'Production',
    this.companyId,
    this.ownerId,
    this.name = '',
    this.paper = PaperSize.size80,
    this.acceptAll = false,
    this.autoStart = true,
    this.printer = '',
    this.printerMac = '',
    this.companyName = '',
    this.userName = '',
  });

  final String env;
  final int? companyId;
  final int? ownerId;
  final String name;
  final PaperSize paper;

  /// In hộ lệnh hoá đơn gửi tới MÁY IN LAN của cửa hàng (giành lệnh như Agent
  /// Android). Tắt: chỉ in lệnh nhắm thẳng Agent này.
  final bool acceptAll;
  final bool autoStart;

  /// Máy in của Agent (hiện ở app là "máy in tích hợp" của Agent này): địa chỉ
  /// LAN `ip` hoặc `ip:cổng`. Rỗng = chưa chọn.
  final String printer;

  /// MAC máy in LAN của Agent (đọc từ bảng ARP lúc chọn) — máy in bật lại nhận
  /// IP mới thì Agent tự tìm lại theo MAC.
  final String printerMac;

  /// Tên công ty + người đăng nhập (hiện trên màn Agent).
  final String companyName;
  final String userName;

  bool get ready => companyId != null && ownerId != null;

  bool get hasPrinter => printer.trim().isNotEmpty;

  AgentConfig copyWith({
    String? env,
    int? companyId,
    int? ownerId,
    String? name,
    PaperSize? paper,
    bool? acceptAll,
    bool? autoStart,
    String? printer,
    String? printerMac,
    String? companyName,
    String? userName,
  }) => AgentConfig(
    env: env ?? this.env,
    companyId: companyId ?? this.companyId,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    paper: paper ?? this.paper,
    acceptAll: acceptAll ?? this.acceptAll,
    autoStart: autoStart ?? this.autoStart,
    printer: printer ?? this.printer,
    // Đổi máy in: bỏ MAC cũ (đọc lại MAC máy mới).
    printerMac:
        printerMac ??
        (printer != null && printer != this.printer ? '' : this.printerMac),
    companyName: companyName ?? this.companyName,
    userName: userName ?? this.userName,
  );

  static AgentConfig load() => AgentConfig(
    env: AgentStore.get('env') ?? 'Production',
    companyId: int.tryParse(AgentStore.get('companyId') ?? ''),
    ownerId: int.tryParse(AgentStore.get('ownerId') ?? ''),
    name: AgentStore.get('name') ?? '',
    paper: PaperSize.fromName(AgentStore.get('paper')),
    acceptAll: AgentStore.get('acceptAll') == '1',
    autoStart: AgentStore.get('autoStart') != '0',
    printer: AgentStore.get('printer') ?? '',
    printerMac: AgentStore.get('printerMac') ?? '',
    companyName: AgentStore.get('companyName') ?? '',
    userName: AgentStore.get('userName') ?? '',
  );

  void save() {
    AgentStore.set('env', env);
    if (companyId != null) AgentStore.set('companyId', '$companyId');
    if (ownerId != null) AgentStore.set('ownerId', '$ownerId');
    AgentStore.set('name', name);
    AgentStore.set('paper', paper.name);
    AgentStore.set('acceptAll', acceptAll ? '1' : '0');
    AgentStore.set('autoStart', autoStart ? '1' : '0');
    AgentStore.set('printer', printer);
    AgentStore.set('printerMac', printerMac);
    AgentStore.set('companyName', companyName);
    AgentStore.set('userName', userName);
  }

  /// Đăng xuất: bỏ công ty đã lưu (giữ mã Agent, tên, máy in, khổ giấy).
  static void clearSession() {
    for (final k in ['companyId', 'ownerId', 'companyName', 'userName']) {
      AgentStore.remove(k);
    }
  }

  /// Bản không còn công ty (sau đăng xuất).
  AgentConfig withoutCompany() => AgentConfig(
    env: env,
    name: name,
    paper: paper,
    acceptAll: acceptAll,
    autoStart: autoStart,
    printer: printer,
    printerMac: printerMac,
  );

  /// Mã Agent của máy này — cố định (lưu lại), để máy bán hàng nhớ đúng "máy in
  /// tích hợp" của Agent này qua các lần mở.
  static String agentId(String Function() generate) {
    final saved = AgentStore.get('id');
    if (saved != null && saved.isNotEmpty) return saved;
    final id = generate();
    AgentStore.set('id', id);
    return id;
  }
}
