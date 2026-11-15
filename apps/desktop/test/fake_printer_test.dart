import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
import 'package:print_agent_desktop/agent/agent_printer.dart';

import 'support/dart_cmd.dart';

/// Chạy máy in giả (tool/fake_printer.dart) ở tiến trình riêng, chờ sẵn sàng.
Future<(Process, List<String>)> _startFake(
  int port,
  Directory out, {
  List<String> extra = const [],
}) async {
  final p = await Process.start(dartExecutable, [
    'run',
    'tool/fake_printer.dart',
    '--port',
    '$port',
    '--out',
    out.path,
    ...extra,
  ], runInShell: runInShell);
  final lines = <String>[];
  final ready = Completer<void>();
  p.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
    lines.add(l);
    if (l.contains('nghe cổng') && !ready.isCompleted) ready.complete();
  });
  p.stderr.transform(utf8.decoder).listen(lines.add);
  await ready.future.timeout(const Duration(seconds: 90));
  return (p, lines);
}

Future<Uint8List> _receiptPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 384, 120),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(20, 20, 200, 40),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  final image = await recorder.endRecording().toImage(384, 120);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'in qua TCP vào máy in giả: ra phiếu PNG, mở két, còi',
    () async {
      final out = Directory.systemTemp.createTempSync('fake_printer_ok');
      final (p, lines) = await _startFake(19100, out);
      try {
        final png = await _receiptPng();
        final job = PrintRelayJob(
          kind: PrintRelayJobKind.receipt,
          printer: const PrintRelayPrinter(address: '127.0.0.1:19100'),
          images: [png],
          copies: 2,
          openDrawer: true,
          beep: true,
        );
        final failure = await AgentPrinter.printJob(job, '127.0.0.1:19100');
        expect(failure, isNull, reason: failure?.detail);
        // Chờ máy in giả lưu xong 2 bản.
        for (var i = 0; i < 50; i++) {
          if (out.listSync().length >= 2) break;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(out.listSync().whereType<File>(), hasLength(2));
        expect(lines.any((l) => l.contains('MỞ KÉT')), isTrue);
        expect(lines.any((l) => l.contains('CÒI BÁO BẾP')), isTrue);
        expect(lines.any((l) => l.contains('GỬI DỮ LIỆU khi')), isFalse);
      } finally {
        p.kill();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'máy in hết giấy: Agent không gửi phiếu, báo outOfPaper',
    () async {
      final out = Directory.systemTemp.createTempSync('fake_printer_paper');
      final (p, lines) = await _startFake(19101, out, extra: ['--paper-out']);
      try {
        final job = PrintRelayJob(
          kind: PrintRelayJobKind.receipt,
          printer: const PrintRelayPrinter(address: '127.0.0.1:19101'),
          images: [await _receiptPng()],
        );
        final failure = await AgentPrinter.printJob(job, '127.0.0.1:19101');
        expect(failure?.error, AgentJobError.outOfPaper);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        expect(out.listSync(), isEmpty);
        expect(lines.any((l) => l.contains('GỬI DỮ LIỆU khi')), isFalse);
      } finally {
        p.kill();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
