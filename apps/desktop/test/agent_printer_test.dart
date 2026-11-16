import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:print_agent/print_agent.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_printer.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/desktop_agent_host.dart';
import 'package:print_agent_desktop/agent/desktop_job_printer.dart';
import 'package:print_agent_desktop/agent/desktop_printer.dart';
import 'package:print_agent_desktop/agent/desktop_printer_gateway.dart';
import 'package:printer_label/desktop.dart';
import 'package:printer_label/printer_label.dart' show LabelCalibration;

/// Lệnh như trạm nhận từ hàng đợi (cùng định dạng app gửi).
PrintRelayJob job(Map<String, Object?> map) =>
    PrintRelayJob.fromMap('j1', {'printerIp': 'builtin', ...map})!;

void main() {
  var config = const AgentConfig(printer: '192.168.1.50');
  final gateway = DesktopPrinterGateway(() => config);
  final printer = DesktopJobPrinter(() => config, gateway);

  test('lệnh tới máy in tích hợp của Agent → máy in đã chọn', () {
    final p = printer.resolve(job({'printerType': 'builtin'}));
    expect(p.kind, AgentPrinterKind.builtIn);
    expect(p.address, '192.168.1.50');
  });

  test('lệnh in hộ máy LAN → in thẳng tới IP của lệnh', () {
    final p = printer.resolve(
      job({'printerType': 'lan', 'printerIp': ' 10.0.0.9 ', 'printerId': 3}),
    );
    expect(p.kind, AgentPrinterKind.lan);
    expect(p.address, '10.0.0.9');
    expect(p.id, 3);
  });

  test(
    'lệnh tem: gửi TSPL (SIZE/GAP/BITMAP/PRINT) tới máy in tem LAN',
    () async {
      // Máy in tem giả: nhận hết byte của một kết nối.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<Uint8List>();
      unawaited(
        server.first.then((s) async {
          final b = BytesBuilder();
          await for (final chunk in s) {
            b.add(chunk);
          }
          received.complete(b.takeBytes());
        }),
      );
      final png = img.encodePng(
        img.Image(width: 560, height: 336, numChannels: 4)
          ..clear(img.ColorRgba8(255, 255, 255, 255)),
      );
      final address = '127.0.0.1:${server.port}';
      final failure = await printer.printJob(
        printer.resolve(
          job({
            'kind': 'label',
            'printerType': 'lan',
            'printerIp': address,
            'labelSize': 'single',
            'copies': 2,
            'images': [base64Encode(png)],
          }),
        ),
        job({
          'kind': 'label',
          'printerType': 'lan',
          'printerIp': address,
          'labelSize': 'single',
          'copies': 2,
          'images': [base64Encode(png)],
        }),
      );
      expect(failure, isNull);
      final sent = latin1.decode(
        await received.future.timeout(const Duration(seconds: 10)),
      );
      await server.close();
      expect(sent, contains('SIZE 50 mm,30 mm'));
      expect(sent, contains('GAP 2 mm,0 mm'));
      expect(sent, contains('BITMAP 0,0,50,240,0,'));
      expect(sent, endsWith('PRINT 1,2\r\n'));
    },
  );

  group('khổ tem theo lệnh', () {
    PrintRelayJob labelJob(Map<String, Object?> extra) =>
        job({'kind': 'label', 'printerType': 'lan', ...extra});

    test(
      'không kèm kích thước: theo tên khổ của app (mặc định 2 tem 35x22)',
      () {
        final a = AgentPrinter.labelSpecOf(
          labelJob({'labelSize': 'single_40_30'}),
        );
        expect([a.widthMm, a.heightMm, a.gapMm, a.shiftXDots], [40, 30, 2, -8]);
        final d = AgentPrinter.labelSpecOf(labelJob({}));
        expect([d.widthMm, d.heightMm, d.gapMm], [72, 22, 1]);
      },
    );

    test('kèm kích thước thật: dùng đúng số đó, ảnh web không dịch lề', () {
      final s = AgentPrinter.labelSpecOf(
        labelJob({
          'labelSize': 'double',
          'labelSpec': {'w': 105, 'h': 40, 'gap': 1, 'count': 2, 'shiftX': 0},
        }),
      );
      expect([s.widthMm, s.heightMm, s.gapMm, s.shiftXDots], [105, 40, 1, 0]);
      expect(s.home, isFalse);
    });

    test('khổ 3 tem giữ HOME dù kèm kích thước thật', () {
      final s = AgentPrinter.labelSpecOf(
        labelJob({
          'labelSize': 'triple',
          'labelSpec': {'w': 106, 'h': 15, 'gap': 2, 'count': 4},
        }),
      );
      expect(s.home, isTrue);
      expect(s.shiftXDots, -8); // không gửi shiftX → mặc định của app
    });

    test('kích thước vô lý bị bỏ, quay về khổ theo tên', () {
      final s = AgentPrinter.labelSpecOf(
        labelJob({
          'labelSize': 'single_40_30',
          'labelSpec': {'w': 0, 'h': 9999},
        }),
      );
      expect([s.widthMm, s.heightMm], [40, 30]);
    });
  });

  test(
    'lệnh tem kèm kích thước thật + chỉnh lệch: SIZE đúng, chỉnh lệch làm trong ảnh',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<Uint8List>();
      unawaited(
        server.first.then((s) async {
          final b = BytesBuilder();
          await for (final chunk in s) {
            b.add(chunk);
          }
          received.complete(b.takeBytes());
        }),
      );
      final png = img.encodePng(
        img.Image(width: 840, height: 320, numChannels: 4)
          ..clear(img.ColorRgba8(255, 255, 255, 255)),
      );
      final address = '127.0.0.1:${server.port}';
      final j = job({
        'kind': 'label',
        'printerType': 'lan',
        'printerIp': address,
        'labelSize': 'double',
        'labelSpec': {'w': 105, 'h': 40, 'gap': 1, 'count': 2, 'shiftX': 0},
        'images': [base64Encode(png)],
      });
      final failure = await AgentPrinter.printLabelJob(
        j,
        address,
        calibration: const LabelCalibration(offsetXMm: 1, offsetYMm: -0.5),
      );
      expect(failure, isNull);
      final sent = latin1.decode(
        await received.future.timeout(const Duration(seconds: 10)),
      );
      await server.close();
      expect(sent, contains('SIZE 105 mm,40 mm'));
      expect(sent, contains('GAP 1 mm,0 mm'));
      // Chỉnh lệch dịch ngay trong ảnh, REFERENCE giữ 0,0 (nhiều máy bỏ qua giá trị âm).
      expect(sent, contains('REFERENCE 0,0'));
      expect(sent, contains('BITMAP 0,0,105,320,0,'));
    },
  );

  group('máy in của Agent: tên hiển thị + loại hoá đơn / tem', () {
    test(
      'tên trên sơ đồ gồm loại + model; chưa chọn máy in thì tên mặc định',
      () {
        expect(
          DesktopPrinter.nameFor(const AgentConfig()),
          DesktopPrinter.builtInName,
        );
        const lan = AgentConfig(printer: '192.168.1.125');
        expect(DesktopPrinter.nameFor(lan), 'Máy in hoá đơn');
        expect(
          DesktopPrinter.nameFor(
            lan.copyWith(
              printerName: 'XP-420B',
              printerType: PrinterType.label,
            ),
          ),
          'Máy in tem · XP-420B',
        );
      },
    );

    test(
      'máy in tem chỉ nhận mẫu tem; máy in hoá đơn nhận các phiếu hoá đơn',
      () {
        config = const AgentConfig(
          printer: '10.0.0.5',
          printerType: PrinterType.label,
        );
        expect(printer.builtInSpec()?.templates, ['label']);
        expect(printer.defaultTemplates, ['label']);
        config = const AgentConfig(printer: '10.0.0.5');
        expect(
          printer.builtInSpec()?.templates,
          contains('paymentPrintingForm'),
        );
        expect(printer.builtInSpec()?.templates, isNot(contains('label')));
        config = const AgentConfig();
      },
    );

    test('xoá máy in: bỏ địa chỉ / MAC / tên / loại, giữ các cài đặt khác', () {
      const c = AgentConfig(
        companyId: 1,
        ownerId: 2,
        printer: '10.0.0.5',
        printerMac: 'AA:BB',
        printerName: 'XP-420B',
        printerType: PrinterType.label,
        paper: PaperSize.size58,
        labelOffsetXMm: -6.5,
        labelGapMm: 3,
      );
      final r = c.withoutPrinter();
      expect(r.hasPrinter, isFalse);
      expect([r.printer, r.printerMac, r.printerName], ['', '', '']);
      expect(r.printerType, PrinterType.receipt);
      // Giữ nguyên phần còn lại (đăng nhập, khổ giấy, căn chỉnh tem).
      expect(
        [r.companyId, r.paper, r.labelOffsetXMm, r.labelGapMm],
        [1, PaperSize.size58, -6.5, 3],
      );
      // Chọn lại máy in khác thì nhận ra lại từ đầu (tên rỗng).
      final again = r.copyWith(printer: '10.0.0.9');
      expect([again.printerName, again.printerType], ['', PrinterType.receipt]);
    });

    test('đổi IP máy in (tìm lại theo MAC) giữ tên và loại đã nhận ra', () {
      const c = AgentConfig(
        printer: '10.0.0.5',
        printerName: 'XP-420B',
        printerType: PrinterType.label,
      );
      final moved = c.copyWith(printer: '10.0.0.9');
      expect(moved.printerName, 'XP-420B');
      expect(moved.printerType, PrinterType.label);
    });
  });

  group('khe giữa tem của máy này', () {
    test('withGap: 0 giữ khe theo lệnh, >0 thay khe', () {
      const spec = TsplLabelSpec(widthMm: 72, heightMm: 22, gapMm: 1);
      expect(AgentPrinter.withGap(spec, 0).gapMm, 1);
      final g = AgentPrinter.withGap(spec, 3);
      expect([g.widthMm, g.heightMm, g.gapMm], [72, 22, 3]);
    });

    test('lệnh tem dùng khe khai báo trên máy; dò khe gửi GAPDETECT', () async {
      // In tem với khe 3mm.
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final got = Completer<Uint8List>();
      unawaited(
        server.first.then((s) async {
          final b = BytesBuilder();
          await for (final c in s) {
            b.add(c);
          }
          got.complete(b.takeBytes());
        }),
      );
      final png = img.encodePng(
        img.Image(width: 576, height: 176, numChannels: 4)
          ..clear(img.ColorRgba8(255, 255, 255, 255)),
      );
      final address = '127.0.0.1:${server.port}';
      final failure = await AgentPrinter.printLabelJob(
        job({
          'kind': 'label',
          'printerType': 'lan',
          'printerIp': address,
          'labelSize': 'double',
          'images': [base64Encode(png)],
        }),
        address,
        gapOverrideMm: 3,
      );
      expect(failure, isNull);
      final sent = latin1.decode(
        await got.future.timeout(const Duration(seconds: 10)),
      );
      await server.close();
      expect(sent, contains('GAP 3 mm,0 mm'));
    });
  });

  test('lệnh tem không có ảnh: báo thiếu nội dung', () async {
    final failure = await printer.printJob(
      printer.resolve(job({'kind': 'label', 'printerType': 'lan'})),
      job({'kind': 'label', 'printerType': 'lan'}),
    );
    expect(failure?.error, AgentJobError.noContent);
  });

  test('máy in tích hợp báo cho máy khác theo khổ giấy đã chọn', () {
    config = const AgentConfig(printer: '10.0.0.5', paper: PaperSize.size58);
    expect(gateway.hasBuiltIn, isTrue);
    expect(printer.builtInSpec()?.paper, 'size58');
    config = const AgentConfig();
    expect(gateway.hasBuiltIn, isFalse);
  });

  group('DesktopAgentHost', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('agent_host_');
      AgentStore.debugDirectory = dir;
    });
    tearDown(() {
      AgentStore.debugDirectory = null;
      dir.deleteSync(recursive: true);
    });

    test('độ chỉnh tem lưu / đọc lại, giới hạn ±20mm, giữ sau đăng xuất', () {
      const c = AgentConfig(
        companyId: 1,
        ownerId: 2,
        labelOffsetXMm: 1.5,
        labelOffsetYMm: -2,
      );
      c.save();
      final loaded = AgentConfig.load();
      expect([loaded.labelOffsetXMm, loaded.labelOffsetYMm], [1.5, -2]);
      expect(loaded.withoutCompany().labelOffsetXMm, 1.5);
      const g = AgentConfig(companyId: 1, ownerId: 2, labelGapMm: 3);
      g.save();
      expect(AgentConfig.load().labelGapMm, 3);
      expect(AgentConfig.load().withoutCompany().labelGapMm, 3);
      const t = AgentConfig(
        companyId: 1,
        ownerId: 2,
        printer: '10.0.0.5',
        printerName: 'XP-420B',
        printerType: PrinterType.label,
      );
      t.save();
      final tl = AgentConfig.load();
      expect([tl.printerName, tl.printerType], ['XP-420B', PrinterType.label]);
      expect(tl.withoutCompany().printerType, PrinterType.label);
      AgentStore.set('printerType', 'rác');
      expect(AgentConfig.load().printerType, PrinterType.receipt);
      AgentStore.set('labelGap', '99');
      expect(AgentConfig.load().labelGapMm, 10);
      AgentStore.set('labelOffsetX', '999');
      AgentStore.set('labelOffsetY', 'rác');
      final bad = AgentConfig.load();
      expect([bad.labelOffsetXMm, bad.labelOffsetYMm], [20, 0]);
    });

    test('khoá hàng đợi giống app EasyPOS', () {
      var c = const AgentConfig(env: 'Dev-Test', companyId: 7, ownerId: 9);
      final host = DesktopAgentHost(() => c);
      expect(host.shopKey, 'dev_test/c7_9');
      c = const AgentConfig();
      expect(host.shopKey, isNull);
    });

    test('lưu giá trị JSON của module vào file cấu hình', () async {
      final host = DesktopAgentHost(() => const AgentConfig());
      await host.storage.put('known_agents_1', [
        {'id': 'a1'},
      ]);
      expect(host.storage.get('known_agents_1'), [
        {'id': 'a1'},
      ]);
      expect(AgentStore.get('m.known_agents_1'), '[{"id":"a1"}]');
    });
  });

  test('tách địa chỉ máy in', () {
    expect(parsePrinterAddress('192.168.1.5'), ('192.168.1.5', 9100));
    expect(parsePrinterAddress('192.168.1.5:9101'), ('192.168.1.5', 9101));
    expect(parsePrinterAddress('  '), isNull);
  });

  test('bỏ dấu tiếng Việt cho phiếu in thử', () {
    expect(EscPosCommands.asciiFold('Quầy Thu Ngân Đà'), 'Quay Thu Ngan Da');
  });
}
