import 'package:printer_label/printer_label.dart' show LabelCalibration;

import 'paper_size.dart';
import 'printer_type.dart';

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
  });

  final PrinterType type;
  final PaperSize paper;
  final double offsetXMm;
  final double offsetYMm;

  /// Khe thật giữa hai tem (mm); 0 = theo lệnh in.
  final double gapMm;

  /// Cho máy in kêu bíp khi phiếu có yêu cầu (phiếu báo bếp). Tắt: máy in im lặng.
  final bool beep;

  LabelCalibration get calibration =>
      LabelCalibration(offsetXMm: offsetXMm, offsetYMm: offsetYMm);

  PrinterSettings copyWith({
    PrinterType? type,
    PaperSize? paper,
    double? offsetXMm,
    double? offsetYMm,
    double? gapMm,
    bool? beep,
  }) => PrinterSettings(
    type: type ?? this.type,
    paper: paper ?? this.paper,
    offsetXMm: offsetXMm ?? this.offsetXMm,
    offsetYMm: offsetYMm ?? this.offsetYMm,
    gapMm: gapMm ?? this.gapMm,
    beep: beep ?? this.beep,
  );

  PrinterSettings withCalibration(LabelCalibration c) =>
      copyWith(offsetXMm: c.offsetXMm, offsetYMm: c.offsetYMm);
}
