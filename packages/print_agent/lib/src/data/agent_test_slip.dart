import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Phiếu in thử: ảnh đen trắng rộng [width] chấm (khổ 80mm; app thu nhỏ cho
/// khổ 58mm) ghi tên máy in, cách kết nối, địa chỉ, trạm in và giờ — nhìn tờ
/// giấy là biết máy in nào đã in.
abstract final class AgentTestSlip {
  static const int width = 576;

  /// [lines]: các dòng "nhãn: giá trị" (đã dịch). Trả ảnh PNG.
  static Future<Uint8List> render({
    required String title,
    required String printer,
    required List<String> lines,
    required String footer,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final blocks = <TextPainter>[
      _text(title, 36, bold: true, center: true),
      _text(printer, 30, bold: true, center: true),
      for (final l in lines) _text(l, 26),
      _text(footer, 28, center: true),
    ];
    const gap = 14.0;
    const pad = 20.0;
    final height =
        pad * 2 + blocks.fold<double>(0, (h, b) => h + b.height + gap) + 40;
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    var y = pad;
    for (final b in blocks) {
      b.paint(canvas, ui.Offset(0, y));
      y += b.height + gap;
    }
    final image = await recorder.endRecording().toImage(width, height.ceil());
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  static TextPainter _text(
    String text,
    double size, {
    bool bold = false,
    bool center = false,
  }) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const ui.Color(0xFF000000),
        fontSize: size,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ),
    ),
    textAlign: center ? TextAlign.center : TextAlign.left,
    textDirection: TextDirection.ltr,
    maxLines: 3,
  )..layout(minWidth: width.toDouble(), maxWidth: width.toDouble());
}
