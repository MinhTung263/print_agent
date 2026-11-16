@TestOn('windows')
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/agent_printer.dart';
import 'package:printer_label/desktop.dart';

/// In RAW qua spooler Windows thật (winspool FFI) — CI tạo sẵn hàng in
/// "Generic / Text Only" có cổng ghi ra file:
/// - `EASYPOS_RAW_QUEUE`: tên hàng in;
/// - `EASYPOS_RAW_FILE`: đường dẫn file của cổng.
/// Thiếu biến môi trường thì bỏ qua (máy Windows của lập trình viên).
void main() {
  final queue = Platform.environment['EASYPOS_RAW_QUEUE'];
  final file = Platform.environment['EASYPOS_RAW_FILE'];
  final skip = queue == null || file == null
      ? 'Chưa có hàng in RAW thử (chỉ chạy trên CI)'
      : null;

  Future<Uint8List> waitFile() async {
    final f = File(file!);
    for (var i = 0; i < 100; i++) {
      if (f.existsSync() && f.lengthSync() > 0) {
        // Spooler có thể còn đang ghi — chờ kích thước đứng yên.
        final a = f.lengthSync();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (f.lengthSync() == a) return f.readAsBytesSync();
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    fail('Spooler không ghi ra $file');
  }

  setUp(() {
    final f = File(file ?? '');
    if (f.existsSync()) f.deleteSync();
  });

  test(
    'liệt kê máy USB cắm trực tiếp (usbprint): xong nhanh, không treo',
    () async {
      final sw = Stopwatch()..start();
      final direct = await WindowsUsbPrint.list();
      // ignore: avoid_print
      print(
        'usbprint: ${direct.length} máy, ${sw.elapsedMilliseconds}ms: '
        '${direct.map((e) => '${e.address} | ${e.name}').toList()}',
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 12)));
      expect(
        direct.every((e) => e.address.startsWith(WindowsUsbPrint.prefix)),
        isTrue,
      );
    },
    skip: Platform.isWindows ? false : 'chỉ Windows',
  );

  test('liệt kê thấy hàng in, hàng in "có mặt"', () async {
    final address = '${WindowsRawPrinters.prefix}$queue';
    expect(await UsbPrinters.present(address), isTrue);
    final all = await UsbPrinters.list();
    expect(all.any((p) => p.address == address), isTrue, reason: '$all');
  }, skip: skip);

  test('gửi byte RAW: spooler ghi nguyên byte (không qua driver)', () async {
    final bytes = Uint8List.fromList([
      ...EscPosCommands.init,
      ...'EasyPOS RAW'.codeUnits,
      ...EscPosCommands.cut,
    ]);
    final port = UsbPrinters.port('${WindowsRawPrinters.prefix}$queue')!;
    await port.send(bytes, checkStatus: false);
    expect(await waitFile(), bytes);
  }, skip: skip);

  test('Agent in phiếu in thử ra hàng in RAW', () async {
    final failure = await AgentPrinter.printTest(
      address: '${WindowsRawPrinters.prefix}$queue',
      label: 'CI',
      paperMm: 80,
    );
    expect(failure, isNull, reason: failure?.detail);
    final out = await waitFile();
    expect(out.take(2), EscPosCommands.init);
    expect(String.fromCharCodes(out), contains('EasyPOS - IN THU'));
  }, skip: skip);
}
