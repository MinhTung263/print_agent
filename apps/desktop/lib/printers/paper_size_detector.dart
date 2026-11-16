import '../agent/paper_size.dart';

/// Khổ giấy gợi ý cho một máy in hoá đơn.
class PaperSizeGuess {
  const PaperSizeGuess(this.size, {required this.detected});

  final PaperSize size;

  /// `true` = suy ra được từ tên máy; `false` = không biết, gợi ý mặc định 80mm.
  final bool detected;

  String get label => '${size.pageMm}mm';

  /// Nhãn hiện trên thẻ máy in: "80mm" hoặc "80mm · gợi ý".
  String get pill => detected ? label : '$label · gợi ý';
}

/// Đoán khổ giấy (58 / 80mm) của máy in hoá đơn từ tên model: ESC/POS không có lệnh hỏi
/// bề rộng giấy nên đây là cách duy nhất không cần in thử. Không đoán được → gợi ý 80mm
/// (khổ phổ biến nhất ở quán).
abstract final class PaperSizeDetector {
  static const PaperSizeGuess recommended = PaperSizeGuess(
    PaperSize.size80,
    detected: false,
  );

  // Model nổi tiếng không ghi khổ trong tên.
  static final _known58 = RegExp(
    r'\b(pt-?210|mht-?p?29|zj-?58\w*|rp-?58\w*)\b',
  );
  static final _known80 = RegExp(
    r'\b(tm-?t(20|82|88|70|81|83)\w*|rp-?80\w*|zj-?80\w*|tsp-?(100|143|650)\w*)\b',
  );

  static PaperSizeGuess guess(String? model) {
    final name = (model ?? '').toLowerCase();
    if (name.trim().isEmpty) return recommended;
    if (_known58.hasMatch(name)) return _of(PaperSize.size58);
    if (_known80.hasMatch(name)) return _of(PaperSize.size80);
    // "XP-58", "POS58", "58mm", "T58" ... "XP-80C", "POS-80", "80mm", "N80".
    final has58 = RegExp(r'(^|[^0-9])58(mm|[^0-9]|$)').hasMatch(name);
    final has80 = RegExp(r'(^|[^0-9])80(mm|[^0-9]|$)').hasMatch(name);
    if (has58 && !has80) return _of(PaperSize.size58);
    if (has80 && !has58) return _of(PaperSize.size80);
    return recommended;
  }

  static PaperSizeGuess _of(PaperSize size) =>
      PaperSizeGuess(size, detected: true);
}
