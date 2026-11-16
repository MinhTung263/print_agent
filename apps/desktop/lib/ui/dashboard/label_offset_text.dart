import 'package:printer_label/printer_label.dart' show LabelCalibration;

/// Câu tiếng Việt dễ hiểu cho độ dời hiện tại (thay cho "+1.5 mm / -0.5 mm").
abstract final class LabelOffsetText {
  static String describe(LabelCalibration c) {
    if (c.isZero) return 'Chưa dời — in đúng vị trí máy in nhận';
    final parts = <String>[
      if (c.offsetXMm != 0)
        'sang ${c.offsetXMm > 0 ? 'phải' : 'trái'} ${_mm(c.offsetXMm.abs())}',
      if (c.offsetYMm != 0)
        '${c.offsetYMm > 0 ? 'xuống dưới' : 'lên trên'} ${_mm(c.offsetYMm.abs())}',
    ];
    return 'Đã dời ${parts.join(', ')}';
  }

  /// "1,5mm" / "2mm" (dấu phẩy thập phân kiểu Việt Nam).
  static String mm(num v) =>
      '${v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',')}mm';

  static String _mm(double v) => mm(v);
}
