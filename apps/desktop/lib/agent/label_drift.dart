/// Tính khe mới từ độ lệch đo được khi in nhiều tem liền nhau.
///
/// Máy kéo giấy mỗi hàng một đoạn = chiều cao tem + khe đã khai. Nếu đoạn đó khác độ dài
/// thật của một tem (bước tem) thì mỗi hàng lệch thêm một chút, cùng hướng. In [rows] hàng
/// liền nhau rồi đo hàng cuối lệch so với hàng đầu [driftMm] (dương = lệch XUỐNG) thì mỗi
/// hàng lệch [driftMm] / ([rows] - 1) — bớt khe đúng bấy nhiêu là hết lệch.
abstract final class LabelDrift {
  /// Số hàng in liền khi đo.
  static const int rows = 4;

  /// Bước chỉnh nhỏ nhất của khe (mm).
  static const double step = 0.25;

  /// Khe mới (mm, làm tròn theo [step], trong 0–10mm) để hết lệch dần.
  static double newGap({
    required double currentGapMm,
    required double driftMm,
    int rows = LabelDrift.rows,
  }) {
    final perRow = driftMm / (rows - 1);
    final raw = (currentGapMm - perRow).clamp(0.0, 10.0);
    return (raw / step).round() * step;
  }
}
