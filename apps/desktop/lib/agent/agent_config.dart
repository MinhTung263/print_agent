import 'agent_store.dart';
import 'paper_size.dart';
import 'printer_type.dart';

export 'paper_size.dart';
export 'printer_type.dart';

/// Cấu hình Agent desktop, lưu ở [AgentStore].
class AgentConfig {
  const AgentConfig({
    this.env = 'Production',
    this.companyId,
    this.ownerId,
    this.name = '',
    this.paper = PaperSize.size80,
    this.autoStart = true,
    this.printer = '',
    this.printerMac = '',
    this.companyName = '',
    this.userName = '',
    this.labelOffsetXMm = 0,
    this.labelOffsetYMm = 0,
    this.labelGapMm = 0,
    this.printerName = '',
    this.printerType = PrinterType.receipt,
    this.beep = true,
    this.autoCut = true,
  });

  final String env;
  final int? companyId;
  final int? ownerId;
  final String name;
  final PaperSize paper;

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

  /// Chỉnh tem in lệch trên máy tính này (mm, dương = sang phải / xuống dưới):
  /// áp cho mọi lệnh in tem. Mỗi máy in tem / hệ điều hành lệch khác nhau.
  final double labelOffsetXMm;
  final double labelOffsetYMm;

  /// Khe thật giữa hai hàng tem trên cuộn của máy in này (mm); 0 = theo lệnh in.
  /// Khai báo sai khe làm tem lệch dần theo từng hàng hoặc cuốn thừa một tem trắng.
  final double labelGapMm;

  /// Tên / model máy in của Agent (đọc qua SNMP lúc chọn) — hiện trên sơ đồ để biết
  /// đây là máy gì. Rỗng = chưa nhận ra.
  final String printerName;

  /// Loại máy in của Agent: hoá đơn hay tem (tự nhận lúc chọn, sửa tay được).
  final PrinterType printerType;

  /// Máy in chính có kêu bíp khi phiếu yêu cầu không.
  final bool beep;

  /// Máy in chính tự động cắt giấy sau mỗi phiếu không.
  final bool autoCut;

  bool get ready => companyId != null && ownerId != null;

  bool get hasPrinter => printer.trim().isNotEmpty;

  AgentConfig copyWith({
    String? env,
    int? companyId,
    int? ownerId,
    String? name,
    PaperSize? paper,
    bool? autoStart,
    String? printer,
    String? printerMac,
    String? companyName,
    String? userName,
    double? labelOffsetXMm,
    double? labelOffsetYMm,
    double? labelGapMm,
    String? printerName,
    PrinterType? printerType,
    bool? beep,
    bool? autoCut,
  }) => AgentConfig(
    env: env ?? this.env,
    companyId: companyId ?? this.companyId,
    ownerId: ownerId ?? this.ownerId,
    name: name ?? this.name,
    paper: paper ?? this.paper,
    autoStart: autoStart ?? this.autoStart,
    printer: printer ?? this.printer,
    // Đổi máy in: bỏ MAC cũ (đọc lại MAC máy mới).
    printerMac:
        printerMac ??
        (printer != null && printer != this.printer ? '' : this.printerMac),
    companyName: companyName ?? this.companyName,
    userName: userName ?? this.userName,
    labelOffsetXMm: labelOffsetXMm ?? this.labelOffsetXMm,
    labelOffsetYMm: labelOffsetYMm ?? this.labelOffsetYMm,
    labelGapMm: labelGapMm ?? this.labelGapMm,
    printerName: printerName ?? this.printerName,
    printerType: printerType ?? this.printerType,
    beep: beep ?? this.beep,
    autoCut: autoCut ?? this.autoCut,
  );

  /// Môi trường duy nhất (trạm in luôn chạy máy chủ thật).
  static const String production = 'Production';

  static AgentConfig load() {
    // Bản cũ từng đăng nhập môi trường thử nghiệm: bỏ phiên đó, đăng nhập lại.
    final env = AgentStore.get('env');
    if (env != null && env != production) {
      clearSession();
      AgentStore.set('env', production);
    }
    return _load();
  }

  static AgentConfig _load() => AgentConfig(
    env: production,
    companyId: int.tryParse(AgentStore.get('companyId') ?? ''),
    ownerId: int.tryParse(AgentStore.get('ownerId') ?? ''),
    name: AgentStore.get('name') ?? '',
    paper: PaperSize.fromName(AgentStore.get('paper')),
    autoStart: AgentStore.get('autoStart') != '0',
    printer: AgentStore.get('printer') ?? '',
    printerMac: AgentStore.get('printerMac') ?? '',
    companyName: AgentStore.get('companyName') ?? '',
    userName: AgentStore.get('userName') ?? '',
    labelOffsetXMm: _mm(AgentStore.get('labelOffsetX')),
    labelOffsetYMm: _mm(AgentStore.get('labelOffsetY')),
    labelGapMm: (double.tryParse(AgentStore.get('labelGap') ?? '') ?? 0)
        .clamp(0.0, 10.0)
        .toDouble(),
    printerName: AgentStore.get('printerName') ?? '',
    printerType: PrinterType.fromName(AgentStore.get('printerType')),
    beep: AgentStore.get('beep') != '0',
    autoCut: AgentStore.get('autoCut') != '0',
  );

  /// Đọc độ chỉnh (mm), giới hạn ±20mm; sai / rỗng = 0.
  static double _mm(String? raw) =>
      (double.tryParse(raw ?? '') ?? 0).clamp(-20.0, 20.0).toDouble();

  void save() {
    AgentStore.set('env', env);
    if (companyId != null) AgentStore.set('companyId', '$companyId');
    if (ownerId != null) AgentStore.set('ownerId', '$ownerId');
    AgentStore.set('name', name);
    AgentStore.set('paper', paper.name);
    AgentStore.set('autoStart', autoStart ? '1' : '0');
    AgentStore.set('printer', printer);
    AgentStore.set('printerMac', printerMac);
    AgentStore.set('companyName', companyName);
    AgentStore.set('userName', userName);
    AgentStore.set('labelOffsetX', '$labelOffsetXMm');
    AgentStore.set('labelOffsetY', '$labelOffsetYMm');
    AgentStore.set('labelGap', '$labelGapMm');
    AgentStore.set('printerName', printerName);
    AgentStore.set('printerType', printerType.name);
    AgentStore.set('beep', beep ? '1' : '0');
    AgentStore.set('autoCut', autoCut ? '1' : '0');
  }

  /// Đăng xuất: bỏ công ty đã lưu (giữ mã Agent, tên, máy in, khổ giấy).
  static void clearSession() {
    for (final k in ['companyId', 'ownerId', 'companyName', 'userName']) {
      AgentStore.remove(k);
    }
  }

  /// Bản không còn máy in của Agent (xoá để chọn lại): bỏ địa chỉ, MAC, tên, loại.
  /// Giữ khổ giấy, độ chỉnh tem và các cài đặt khác.
  AgentConfig withoutPrinter() => copyWith(
    printer: '',
    printerMac: '',
    printerName: '',
    printerType: PrinterType.receipt,
  );

  /// Bản không còn công ty (sau đăng xuất).
  AgentConfig withoutCompany() => AgentConfig(
    env: env,
    name: name,
    paper: paper,
    autoStart: autoStart,
    printer: printer,
    printerMac: printerMac,
    labelOffsetXMm: labelOffsetXMm,
    labelOffsetYMm: labelOffsetYMm,
    labelGapMm: labelGapMm,
    printerName: printerName,
    printerType: printerType,
    beep: beep,
    autoCut: autoCut,
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
