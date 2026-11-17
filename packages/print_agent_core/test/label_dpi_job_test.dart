import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_core/print_agent_core.dart';
import 'package:printer_label/printer_label.dart' show LabelPerRow;

/// PNG trắng [w]x[h].
Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  final image = await recorder.endRecording().toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<int> _widthOf(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  return frame.image.width;
}

void main() {
  const size = LabelPerRow.doubleLabels; // 2 tem × 35mm
  const printer = PrintRelayPrinter(address: '10.0.0.7');

  test('mặc định 203dpi: thu ảnh hàng tem về 8 chấm/mm (như cũ)', () async {
    final job = await PrintRelayJob.label(
      printer: printer,
      images: [await _png(1470, 200)],
      size: size,
    );
    expect(await _widthOf(job.images.single), 560); // 70mm × 8
  });

  test(
    'máy 300dpi: thu về ~11,81 chấm/mm — mịn hơn cho tem vàng bạc',
    () async {
      final job = await PrintRelayJob.label(
        printer: printer,
        images: [await _png(1470, 200)],
        size: size,
        dotsPerMm: 300 / 25.4,
      );
      expect(await _widthOf(job.images.single), 827); // 70mm × 11,81
    },
  );

  test('ảnh nguồn nhỏ hơn đích: giữ nguyên, không phóng to', () async {
    final job = await PrintRelayJob.label(
      printer: printer,
      images: [await _png(400, 100)],
      size: size,
      dotsPerMm: 300 / 25.4,
    );
    expect(await _widthOf(job.images.single), 400);
  });
}
