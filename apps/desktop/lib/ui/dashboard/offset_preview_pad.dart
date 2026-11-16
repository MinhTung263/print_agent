import 'package:flutter/material.dart';
import 'package:printer_label/printer_label.dart' show Box, SchematicTemLayout;

import '../agent_theme.dart';

/// Chỉnh vị trí tem bằng mắt: vẽ cuộn tem THẬT (đúng số tem trên hàng, khe giữa các tem)
/// với nội dung mẫu (tên, giá, mã vạch) dời theo độ chỉnh hiện tại — nội dung bị cắt ở
/// mép tem đúng như khi in lệch. Nét đứt xám là vị trí gốc. Bốn mũi tên quanh tem: bấm
/// là nội dung dời ngay theo hướng đó. Bấm vào tem để về vị trí gốc.
class OffsetPreviewPad extends StatelessWidget {
  const OffsetPreviewPad({
    super.key,
    required this.widthMm,
    required this.heightMm,
    required this.offsetXMm,
    required this.offsetYMm,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
    this.count = 1,
    this.onReset,
  });

  /// Cả hàng tem (mm) — quyết định tỉ lệ hình.
  final int widthMm;
  final int heightMm;

  /// Số tem trên một hàng (vẽ đúng số tem).
  final int count;
  final double offsetXMm;
  final double offsetYMm;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  /// `null` = đang ở vị trí gốc.
  final VoidCallback? onReset;

  static const double _arrow = 48;
  static const double _previewWidth = 250;

  Widget _arrowButton(IconData icon, String tip, VoidCallback onTap) =>
      SizedBox.square(
        dimension: _arrow,
        child: Tooltip(
          message: tip,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
            ),
            onPressed: onTap,
            child: Icon(icon, size: 26),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ratio = heightMm / widthMm;
    // Đúng tỉ lệ tem thật (không kéo cao) để hình giống tờ in.
    final previewHeight = (_previewWidth * ratio).clamp(56.0, 190.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        _arrowButton(Icons.keyboard_arrow_up_rounded, 'Dời lên', onUp),
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            _arrowButton(
              Icons.keyboard_arrow_left_rounded,
              'Dời sang trái',
              onLeft,
            ),
            Tooltip(
              message: onReset == null ? '' : 'Bấm để về vị trí gốc',
              child: GestureDetector(
                onTap: onReset,
                child: CustomPaint(
                  size: Size(_previewWidth, previewHeight),
                  painter: OffsetPreviewPainter(
                    widthMm: widthMm,
                    heightMm: heightMm,
                    count: count,
                    offsetXMm: offsetXMm,
                    offsetYMm: offsetYMm,
                  ),
                ),
              ),
            ),
            _arrowButton(
              Icons.keyboard_arrow_right_rounded,
              'Dời sang phải',
              onRight,
            ),
          ],
        ),
        _arrowButton(Icons.keyboard_arrow_down_rounded, 'Dời xuống', onDown),
      ],
    );
  }
}

/// Chú thích dưới hình tem: nét đứt xám = vị trí gốc, xanh = nội dung đang in.
class OffsetPreviewLegend extends StatelessWidget {
  const OffsetPreviewLegend({super.key});

  @override
  Widget build(BuildContext context) => const Row(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 16,
    children: [
      _Key(color: AgentColors.muted, label: 'Vị trí gốc'),
      _Key(color: AgentColors.primary, label: 'Nội dung đang in'),
    ],
  );
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    spacing: 6,
    children: [
      Container(
        width: 14,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: AgentColors.textSecondary),
      ),
    ],
  );
}

/// Vẽ cuộn tem + nội dung mẫu dời theo độ chỉnh.
class OffsetPreviewPainter extends CustomPainter {
  const OffsetPreviewPainter({
    required this.widthMm,
    required this.heightMm,
    required this.offsetXMm,
    required this.offsetYMm,
    this.count = 1,
  });

  final int widthMm;
  final int heightMm;
  final int count;
  final double offsetXMm;
  final double offsetYMm;

  /// Phóng đại độ dời cho dễ nhìn (nhưng không cho nội dung dời quá xa).
  static const double exaggerate = 3;

  /// Độ dời (px) của nội dung trong hình tem rộng [size].
  static Offset shiftOf(Size size, int widthMm, double dx, double dy) {
    final scale = size.width / widthMm * exaggerate;
    const limit = 0.12;
    return Offset(
      (dx * scale).clamp(-size.width * limit, size.width * limit),
      (dy * scale).clamp(-size.width * limit, size.width * limit),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = count.clamp(1, 4);
    final gap = n > 1 ? size.width * 0.03 : 0.0;
    final temW = (size.width - gap * (n - 1)) / n;
    final shift = shiftOf(size, widthMm, offsetXMm, offsetYMm);
    for (var i = 0; i < n; i++) {
      final rect = Rect.fromLTWH(i * (temW + gap), 0, temW, size.height);
      _paintTem(canvas, rect, shift);
    }
  }

  void _paintTem(Canvas canvas, Rect rect, Offset shift) {
    final tem = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    // Bóng nhẹ + giấy tem.
    canvas.drawRRect(
      tem.shift(const Offset(0, 1.5)),
      Paint()..color = Colors.black.withValues(alpha: 0.08),
    );
    canvas.drawRRect(tem, Paint()..color = Colors.white);
    canvas.drawRRect(
      tem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AgentColors.border,
    );

    // Bố cục dùng chung với ảnh in ra ([SchematicTemLayout]) nên hai hình luôn giống nhau.
    final l = SchematicTemLayout.of(rect.width, rect.height);
    Rect r(Box b) =>
        Rect.fromLTRB(b.left, b.top, b.right, b.bottom).shift(rect.topLeft);

    // Vị trí gốc: nét đứt xám.
    _dashedRect(
      canvas,
      r(l.frame),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AgentColors.muted,
    );

    // Nội dung mẫu, dời theo độ chỉnh và bị cắt ở mép tem.
    canvas.save();
    canvas.clipRRect(tem);
    canvas.translate(shift.dx, shift.dy);
    final ink = Paint()..color = AgentColors.primary;
    canvas.drawRect(
      r(l.frame).deflate(l.strokeWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l.strokeWidth.clamp(1.6, 4.0)
        ..color = AgentColors.primary,
    );
    canvas.drawRect(r(l.bar1), ink);
    canvas.drawRect(r(l.bar2), ink);
    for (final (x, w) in l.bars) {
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + x,
          rect.top + l.code.top,
          w < 1 ? 1 : w,
          l.code.height,
        ),
        ink,
      );
    }
    canvas.restore();
  }

  void _dashedRect(Canvas canvas, Rect r, Paint paint) {
    void dash(Offset a, Offset b) {
      final total = (b - a).distance;
      final dir = (b - a) / total;
      var d = 0.0;
      while (d < total) {
        canvas.drawLine(a + dir * d, a + dir * (d + 4).clamp(0, total), paint);
        d += 7;
      }
    }

    dash(r.topLeft, r.topRight);
    dash(r.topRight, r.bottomRight);
    dash(r.bottomRight, r.bottomLeft);
    dash(r.bottomLeft, r.topLeft);
  }

  @override
  bool shouldRepaint(OffsetPreviewPainter old) =>
      old.widthMm != widthMm ||
      old.heightMm != heightMm ||
      old.count != count ||
      old.offsetXMm != offsetXMm ||
      old.offsetYMm != offsetYMm;
}
