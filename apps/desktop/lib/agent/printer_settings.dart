import 'package:printer_label/printer_label.dart' show LabelCalibration;

import 'paper_size.dart';
import 'printer_type.dart';

/// Máy in tem truyền nhiệt (ruy-băng mực): `auto` = không gửi lệnh (như máy nhiệt trực tiếp
/// thông thường); `on` / `off` = gửi `SET RIBBON ON` / `OFF` theo lựa chọn rõ ràng của người dùng.
enum RibbonMode {
  auto,
  on,
  off;

  /// Giá trị truyền cho lệnh tem: `null` = không gửi.
  bool? get value => switch (this) {
    RibbonMode.auto => null,
    RibbonMode.on => true,
    RibbonMode.off => false,
  };

  static RibbonMode fromName(String? name) => RibbonMode.values.firstWhere(
    (m) => m.name == name,
    orElse: () => RibbonMode.auto,
  );
}

/// Cài đặt RIÊNG của từng máy in trong trạm in (mở từ chi tiết máy in trên sơ đồ):
/// loại, khổ giấy hoá đơn, và độ chỉnh tem (lệch ngang / dọc, khe giữa các tem).
class PrinterSettings {
  const PrinterSettings({
    this.type = PrinterType.receipt,
    this.paper = PaperSize.size80,
    this.offsetXMm = 0,
    this.offsetYMm = 0,
    this.gapMm = 0,
    this.beep = true,
    this.autoCut = true,
    this.dpi = 203,
    this.ribbon = RibbonMode.auto,
  });

  final PrinterType type;
  final PaperSize paper;
  final double offsetXMm;
  final double offsetYMm;

  /// Khe thật giữa hai tem (mm); 0 = theo lệnh in.
  final double gapMm;

  /// Cho máy in kêu bíp khi phiếu có yêu cầu (phiếu báo bếp). Tắt: máy in im lặng.
  final bool beep;

  /// Tự động cắt giấy sau mỗi phiếu (máy hoá đơn có dao cắt). Tắt: chỉ đẩy giấy, tự xé.
  final bool autoCut;

  /// Máy tem: độ phân giải đầu in — 203 (tem trà sữa / F&B) hoặc 300 (tem vàng bạc).
  final int dpi;

  /// Máy tem: có dùng ruy-băng mực (truyền nhiệt) không.
  final RibbonMode ribbon;

  LabelCalibration get calibration =>
      LabelCalibration(offsetXMm: offsetXMm, offsetYMm: offsetYMm);

  PrinterSettings copyWith({
    PrinterType? type,
    PaperSize? paper,
    double? offsetXMm,
    double? offsetYMm,
    double? gapMm,
    bool? beep,
    bool? autoCut,
    int? dpi,
    RibbonMode? ribbon,
  }) => PrinterSettings(
    type: type ?? this.type,
    paper: paper ?? this.paper,
    offsetXMm: offsetXMm ?? this.offsetXMm,
    offsetYMm: offsetYMm ?? this.offsetYMm,
    gapMm: gapMm ?? this.gapMm,
    beep: beep ?? this.beep,
    autoCut: autoCut ?? this.autoCut,
    dpi: dpi ?? this.dpi,
    ribbon: ribbon ?? this.ribbon,
  );

  PrinterSettings withCalibration(LabelCalibration c) =>
      copyWith(offsetXMm: c.offsetXMm, offsetYMm: c.offsetYMm);
}
