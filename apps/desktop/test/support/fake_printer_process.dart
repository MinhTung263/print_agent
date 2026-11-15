import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'dart_cmd.dart';

/// Máy in giả (tool/fake_printer.dart) chạy ở tiến trình riêng.
class FakePrinter {
  FakePrinter._(this.process, this.port, this.out, this.lines);

  final Process process;
  final int port;
  final Directory out;
  final List<String> lines;

  String get address => '127.0.0.1:$port';

  static Future<FakePrinter> start(
    int port, {
    List<String> extra = const [],
    Directory? out,
  }) async {
    final dir = out ?? Directory.systemTemp.createTempSync('fake_printer_');
    final p = await Process.start(dartExecutable, [
      'run',
      'tool/fake_printer.dart',
      '--port',
      '$port',
      '--out',
      dir.path,
      ...extra,
    ], runInShell: runInShell);
    final lines = <String>[];
    final ready = Completer<void>();
    p.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((
      l,
    ) {
      lines.add(l);
      if (l.contains('nghe cổng') && !ready.isCompleted) ready.complete();
    });
    p.stderr.transform(utf8.decoder).listen(lines.add);
    await ready.future.timeout(const Duration(seconds: 90));
    return FakePrinter._(p, port, dir, lines);
  }

  /// Gõ lệnh như người dùng (VD `p` = bật / tắt hết giấy).
  void command(String c) => process.stdin.writeln(c);

  int get tickets => out.listSync().whereType<File>().length;

  bool get sawDataWhileBlocked =>
      lines.any((l) => l.contains('GỬI DỮ LIỆU khi'));

  Future<void> waitTickets(
    int n, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final end = DateTime.now().add(timeout);
    while (tickets < n && DateTime.now().isBefore(end)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Tắt máy in giả và chờ tới khi cổng thật sự đóng.
  Future<void> stop() async {
    await killProcessTree(process);
    await process.exitCode.timeout(
      const Duration(seconds: 10),
      onTimeout: () => -1,
    );
    await _waitPortClosed();
  }

  Future<void> _waitPortClosed() async {
    final end = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(end)) {
      try {
        final s = await Socket.connect(
          InternetAddress.loopbackIPv4,
          port,
          timeout: const Duration(milliseconds: 500),
        );
        s.destroy();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      } on SocketException {
        return;
      }
    }
  }
}

/// Ảnh hoá đơn nhỏ (khổ 58mm) để in thử.
Future<Uint8List> receiptPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 384, 96),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  canvas.drawRect(
    const ui.Rect.fromLTWH(16, 16, 200, 32),
    ui.Paint()..color = const ui.Color(0xFF000000),
  );
  final image = await recorder.endRecording().toImage(384, 96);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
