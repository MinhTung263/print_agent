/// Khổ giấy hoá đơn — tên giống app (`size80` / `size58`).
enum PaperSize {
  size80(pageMm: 80, dots: 576),
  size58(pageMm: 58, dots: 384);

  const PaperSize({required this.pageMm, required this.dots});

  /// Bề rộng cuộn giấy.
  final int pageMm;

  /// Số điểm in một dòng (đầu in 203 dpi): 80mm → 576, 58mm → 384.
  final int dots;

  static PaperSize fromName(String? name) =>
      name == size58.name ? size58 : size80;
}
