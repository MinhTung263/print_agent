import 'package:printer_label/desktop.dart' show TsplLabelSpec;
import 'package:printer_label/printer_label.dart' show LabelPerRow;

/// Khổ tem để chọn khi căn chỉnh: các khổ app EasyPOS đã có tên + vài khổ phổ biến
/// trên thị trường app chưa có (trang web gửi kèm kích thước thật nên Agent in đúng).
class LabelPreset {
  const LabelPreset(
    this.title,
    this.spec, {
    required this.count,
    required this.tem,
  });

  final String title;
  final TsplLabelSpec spec;

  /// Số tem trên một hàng (1–4).
  final int count;

  /// Khổ MỘT tem, hiện trên nút chọn (VD `35×22`).
  final String tem;

  /// Bề rộng MỘT tem (mm) lấy từ [tem] (`35×22` → 35).
  int get temWidthMm =>
      int.tryParse(tem.split('×').first) ?? (spec.widthMm / count).floor();

  /// Mô tả cho khách: "2 tem/hàng · mỗi tem 35×22mm (cả hàng 72×22mm)".
  String get description =>
      '$count tem/hàng · mỗi tem ${tem}mm (cả hàng ${spec.widthMm}×${spec.heightMm}mm)';

  /// Mặc định: 2 tem/hàng, mỗi tem 35×22mm (khổ mặc định của app).
  static final LabelPreset defaultPreset = all.firstWhere(
    (p) => p.spec.widthMm == 72 && p.spec.heightMm == 22 && !p.spec.home,
  );

  /// Khổ app chưa có tên (cả hàng rộng × cao, khe).
  static const List<LabelPreset> extra = [
    LabelPreset(
      '2 tem/hàng · 40×25mm (cả hàng 85×25)',
      TsplLabelSpec(widthMm: 85, heightMm: 25, gapMm: 3),
      count: 2,
      tem: '40×25',
    ),
    LabelPreset(
      '2 tem/hàng · 50×40mm (cả hàng 105×40)',
      TsplLabelSpec(widthMm: 105, heightMm: 40, gapMm: 1),
      count: 2,
      tem: '50×40',
    ),
    LabelPreset(
      '1 tem · 100×50mm',
      TsplLabelSpec(widthMm: 100, heightMm: 50, gapMm: 2),
      count: 1,
      tem: '100×50',
    ),
    LabelPreset(
      '4 tem/hàng · 25×15mm (cả hàng 106×15)',
      TsplLabelSpec(widthMm: 106, heightMm: 15, gapMm: 2, home: true),
      count: 4,
      tem: '25×15',
    ),
    // Tem vàng bạc, trang sức (nhỏ, dài): in trên máy 300dpi — chọn "300 dpi" trong cài đặt
    // máy in (khổ này không tự đổi độ phân giải).
    LabelPreset(
      '1 tem · 50×12mm (tem vàng bạc)',
      TsplLabelSpec(widthMm: 50, heightMm: 12, gapMm: 2),
      count: 1,
      tem: '50×12',
    ),
  ];

  /// Mọi khổ để chọn: khổ của app trước, rồi [extra].
  static final List<LabelPreset> all = [
    for (final s in LabelPerRow.values)
      if (TsplLabelSpec.fromLabelPerRow(s) case final spec?)
        LabelPreset(
          '${s.title} · ${spec.widthMm}×${spec.heightMm}mm',
          spec,
          count: s.count,
          tem: '${s.stampWidth.round()}×${s.stampHeight.round()}',
        ),
    ...extra,
  ];

  /// Khổ có sẵn khớp [widthMm] × [heightMm] (cả hàng); không có thì dựng khổ riêng với
  /// [count] tem/hàng (bề rộng một tem = cả hàng chia đều).
  static LabelPreset forSize({
    required int widthMm,
    required int heightMm,
    required int count,
    num gapMm = 2,
  }) {
    for (final p in all) {
      if (p.spec.widthMm == widthMm &&
          p.spec.heightMm == heightMm &&
          p.count == count) {
        return p;
      }
    }
    final tem = (widthMm / count).floor();
    return LabelPreset(
      '$count tem/hàng · $widthMm×${heightMm}mm',
      TsplLabelSpec(widthMm: widthMm, heightMm: heightMm, gapMm: gapMm),
      count: count,
      tem: '$tem×$heightMm',
    );
  }
}
