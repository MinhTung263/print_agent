import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart'
    show AgentPrinterKind, AgentPrinterState;
import 'package:print_agent_desktop/agent/desktop_printer.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_printer.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/desktop_agent.dart';
import 'package:print_agent_desktop/agent/printer_settings.dart';
import 'package:print_agent_desktop/ui/dashboard/offset_preview_pad.dart';
import 'package:print_agent_desktop/ui/dashboard/label_offset_text.dart';
import 'package:print_agent_desktop/ui/dashboard/printer_settings_panel.dart';
import 'package:printer_label/desktop.dart' show TsplLabelSpec;
import 'package:printer_label/printer_label.dart' show LabelCalibration;

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('printer_settings_');
    AgentStore.debugDirectory = dir;
  });
  tearDown(() {
    AgentStore.debugDirectory = null;
    dir.deleteSync(recursive: true);
  });

  test('LabelOffsetText nói bằng lời', () {
    expect(
      LabelOffsetText.describe(LabelCalibration.none),
      startsWith('Chưa dời'),
    );
    expect(
      LabelOffsetText.describe(
        const LabelCalibration(offsetXMm: 1.5, offsetYMm: -0.5),
      ),
      'Đã dời sang phải 1,5mm, lên trên 0,5mm',
    );
  });

  testWidgets('OffsetPreviewPad: 4 mũi tên + bấm hình tem để về gốc', (
    t,
  ) async {
    final hits = <String>[];
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OffsetPreviewPad(
            widthMm: 72,
            heightMm: 22,
            offsetXMm: 1,
            offsetYMm: 0,
            onUp: () => hits.add('up'),
            onDown: () => hits.add('down'),
            onLeft: () => hits.add('left'),
            onRight: () => hits.add('right'),
            onReset: () => hits.add('reset'),
          ),
        ),
      ),
    );
    for (final icon in [
      Icons.keyboard_arrow_up_rounded,
      Icons.keyboard_arrow_down_rounded,
      Icons.keyboard_arrow_left_rounded,
      Icons.keyboard_arrow_right_rounded,
    ]) {
      await t.tap(find.byIcon(icon));
    }
    await t.tap(find.byTooltip('Bấm để về vị trí gốc'));
    expect(hits, ['up', 'down', 'left', 'right', 'reset']);
  });

  test('khung trên hình tem dời đúng hướng và không tràn khỏi tem', () {
    const size = Size(190, 56);
    final right = OffsetPreviewPainter.shiftOf(size, 72, 1.5, 0);
    expect(right.dx, greaterThan(0));
    expect(right.dy, 0);
    final up = OffsetPreviewPainter.shiftOf(size, 72, 0, -1);
    expect(up.dy, lessThan(0));
    final far = OffsetPreviewPainter.shiftOf(size, 72, 20, 20);
    expect(far.dx, lessThanOrEqualTo(size.width * 0.12));
  });

  test('nhiều máy in USB trong một trạm in: mỗi máy một dòng riêng', () async {
    final agent = DesktopAgent(const AgentConfig(printer: 'cups:EasyPOS_A'));
    agent.gateway.extras
      ..add('cups:EasyPOS_B')
      ..add('cups:EasyPOS_C');
    final usb = agent.gateway.printers.map((p) => p.address).toList();
    expect(usb, ['cups:EasyPOS_B', 'cups:EasyPOS_C']);
    expect(
      agent.gateway.printers.every((p) => p.kind == AgentPrinterKind.usb),
      isTrue,
    );
    agent.dispose();
  });

  test('cài đặt riêng từng máy: máy chính và máy thêm không lẫn', () async {
    final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
    await agent.addPrinter('10.0.0.6');
    await agent.updateSettings(
      '10.0.0.5',
      const PrinterSettings(paper: PaperSize.size58, beep: false),
    );
    // Loại máy chốt lúc thêm (tự nhận): máy này được nhận là máy tem.
    agent.gateway.extras.update('10.0.0.6', type: PrinterType.label);
    await agent.updateSettings(
      '10.0.0.6',
      const PrinterSettings(offsetXMm: 1.5, gapMm: 3),
    );
    expect(agent.settingsOf('10.0.0.5').paper, PaperSize.size58);
    expect(agent.settingsOf('10.0.0.5').type, PrinterType.receipt);
    expect(agent.settingsOf('10.0.0.5').beep, isFalse);
    expect(agent.settingsOf('10.0.0.6').beep, isTrue);
    expect(AgentConfig.load().beep, isFalse);
    final tem = agent.settingsOf('10.0.0.6');
    expect(tem.type, PrinterType.label);
    expect(tem.offsetXMm, 1.5);
    expect(tem.gapMm, 3);
    // Lưu lại: mở lại app vẫn còn.
    expect(agent.gateway.extras.byAddress('10.0.0.6')!.settings.gapMm, 3);
    expect(AgentConfig.load().paper, PaperSize.size58);
    agent.dispose();
  });

  test(
    'loại máy in không đổi được qua cài đặt (muốn đổi: xoá rồi thêm lại)',
    () async {
      final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
      agent.gateway.extras.add('10.0.0.6', type: PrinterType.label);
      await agent.updateSettings(
        '10.0.0.6',
        const PrinterSettings(type: PrinterType.receipt, offsetXMm: 1),
      );
      expect(agent.settingsOf('10.0.0.6').type, PrinterType.label);
      expect(agent.settingsOf('10.0.0.6').offsetXMm, 1);
      await agent.updateSettings(
        '10.0.0.5',
        const PrinterSettings(type: PrinterType.label),
      );
      expect(agent.settingsOf('10.0.0.5').type, PrinterType.receipt);
      agent.dispose();
    },
  );

  test('không tự thêm máy in vào trạm: chỉ có máy khi người dùng thêm', () async {
    final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
    // Mới vào: chưa có máy in nào ngoài máy in chính.
    expect(agent.gateway.printers, isEmpty);
    expect(agent.gateway.extras.items, isEmpty);
    // Người dùng chọn thêm: có máy; thêm trùng không được; xoá được và thêm lại được.
    expect(await agent.addPrinter('10.0.0.6'), isTrue);
    expect(await agent.addPrinter('10.0.0.6'), isFalse);
    expect(agent.removeExtraPrinter('10.0.0.6'), isTrue);
    expect(agent.gateway.printers, isEmpty);
    expect(await agent.addPrinter('10.0.0.6'), isTrue);
    agent.dispose();
  });

  test('tự động cắt giấy: mặc định bật, lưu riêng từng máy', () async {
    final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
    agent.gateway.extras.add('10.0.0.6');
    expect(agent.settingsOf('10.0.0.5').autoCut, isTrue);
    expect(agent.settingsOf('10.0.0.6').autoCut, isTrue);
    await agent.updateSettings(
      '10.0.0.6',
      const PrinterSettings(autoCut: false),
    );
    expect(agent.settingsOf('10.0.0.6').autoCut, isFalse);
    expect(agent.settingsOf('10.0.0.5').autoCut, isTrue);
    await agent.updateSettings(
      '10.0.0.5',
      const PrinterSettings(autoCut: false),
    );
    expect(AgentConfig.load().autoCut, isFalse);
    expect(
      agent.gateway.extras.byAddress('10.0.0.6')!.settings.autoCut,
      isFalse,
    );
    agent.dispose();
  });

  test('tắt cắt giấy: xoá máy rồi thêm lại vẫn tắt (nhớ theo máy)', () async {
    final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
    // Máy thêm: tắt cắt giấy + tắt còi, rồi xoá khỏi trạm.
    expect(await agent.addPrinter('10.0.0.6'), isTrue);
    await agent.updateSettings(
      '10.0.0.6',
      const PrinterSettings(autoCut: false, beep: false),
    );
    expect(agent.removeExtraPrinter('10.0.0.6'), isTrue);
    expect(agent.gateway.extras.byAddress('10.0.0.6'), isNull);
    // Thêm lại: cài đặt quay về, không phải chỉnh lại.
    expect(await agent.addPrinter('10.0.0.6'), isTrue);
    final back = agent.settingsOf('10.0.0.6');
    expect(back.autoCut, isFalse);
    expect(back.beep, isFalse);
    // Máy khác chưa từng chỉnh vẫn theo mặc định.
    expect(await agent.addPrinter('10.0.0.7'), isTrue);
    expect(agent.settingsOf('10.0.0.7').autoCut, isTrue);
    agent.dispose();
  });

  test('máy in chính xoá rồi chọn lại: vẫn nhớ tắt cắt giấy', () async {
    final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
    await agent.updateSettings(
      '10.0.0.5',
      const PrinterSettings(autoCut: false),
    );
    await agent.removePrinter();
    expect(agent.config.hasPrinter, isFalse);
    expect(await agent.addPrinter('10.0.0.5'), isTrue);
    expect(agent.config.autoCut, isFalse);
    expect(agent.settingsOf('10.0.0.5').autoCut, isFalse);
    agent.dispose();
  });

  test(
    'máy tem 300dpi + ruy-băng: lưu riêng từng máy, giữ qua lần mở sau',
    () async {
      final agent = DesktopAgent(
        const AgentConfig(printer: '10.0.0.5', printerType: PrinterType.label),
      );
      agent.gateway.extras.add('10.0.0.6', type: PrinterType.label);
      // Mặc định: 203dpi, không gửi lệnh ruy-băng.
      expect(agent.settingsOf('10.0.0.5').dpi, 203);
      expect(agent.settingsOf('10.0.0.5').ribbon, RibbonMode.auto);
      await agent.updateSettings(
        '10.0.0.6',
        agent.settingsOf('10.0.0.6').copyWith(dpi: 300, ribbon: RibbonMode.on),
      );
      // Máy kia không bị ảnh hưởng.
      expect(agent.settingsOf('10.0.0.5').dpi, 203);
      expect(agent.settingsOf('10.0.0.6').dpi, 300);
      expect(agent.settingsOf('10.0.0.6').ribbon, RibbonMode.on);
      // Máy chính lưu xuống cấu hình rồi đọc lại.
      await agent.updateSettings(
        '10.0.0.5',
        agent.settingsOf('10.0.0.5').copyWith(dpi: 300, ribbon: RibbonMode.off),
      );
      final loaded = AgentConfig.load();
      expect(loaded.labelDpi, 300);
      expect(loaded.labelRibbon, RibbonMode.off);
      agent.dispose();
      // Mở lại Agent: máy thêm vẫn 300dpi + ruy-băng.
      final again = DesktopAgent(AgentConfig.load());
      expect(again.settingsOf('10.0.0.6').dpi, 300);
      expect(again.settingsOf('10.0.0.6').ribbon, RibbonMode.on);
      again.dispose();
    },
  );

  test('xoá máy tem rồi thêm lại: nhớ 300dpi + ruy-băng', () async {
    final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
    expect(await agent.addPrinter('10.0.0.8'), isTrue);
    await agent.updateSettings(
      '10.0.0.8',
      agent.settingsOf('10.0.0.8').copyWith(dpi: 300, ribbon: RibbonMode.on),
    );
    expect(agent.removeExtraPrinter('10.0.0.8'), isTrue);
    expect(await agent.addPrinter('10.0.0.8'), isTrue);
    expect(agent.settingsOf('10.0.0.8').dpi, 300);
    expect(agent.settingsOf('10.0.0.8').ribbon, RibbonMode.on);
    agent.dispose();
  });

  test('khe lẻ lưu riêng từng máy', () async {
    final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
    agent.gateway.extras.add('10.0.0.6', type: PrinterType.label);
    await agent.updateSettings('10.0.0.6', const PrinterSettings(gapMm: 2.5));
    await agent.updateSettings('10.0.0.5', const PrinterSettings(gapMm: 1.5));
    expect(agent.settingsOf('10.0.0.6').gapMm, 2.5);
    expect(agent.settingsOf('10.0.0.5').gapMm, 1.5);
    // Lưu lại: mở lại app vẫn còn.
    expect(agent.gateway.extras.byAddress('10.0.0.6')!.settings.gapMm, 2.5);
    expect(AgentConfig.load().labelGapMm, 1.5);
    agent.dispose();
  });

  test('withGap: khe lẻ theo máy, 0 = theo lệnh', () {
    const base = TsplLabelSpec(widthMm: 72, heightMm: 22, gapMm: 2);
    expect(AgentPrinter.withGap(base, 2.5).gapMm, 2.5);
    expect(AgentPrinter.withGap(base, 0).gapMm, 2);
  });

  testWidgets(
    'máy tem: in thử + hình tem chỉnh vị trí, không có ô cấu hình thừa; máy hoá đơn: khổ giấy',
    (t) async {
      await t.binding.setSurfaceSize(const Size(600, 1400));
      final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
      agent.gateway.extras.add('10.0.0.6'); // không dò mạng trong test
      agent.gateway.extras.update('10.0.0.6', type: PrinterType.label);
      // Máy in đang kết nối: có nút in thử.
      for (final a in ['10.0.0.5', '10.0.0.6']) {
        agent.service.watchdog.report(
          DesktopPrinter(kind: AgentPrinterKind.lan, address: a),
          AgentPrinterState.connected,
        );
      }
      Future<void> show(String address) async {
        await t.pumpWidget(
          GetMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: PrinterSettingsPanel(agent: agent, address: address),
              ),
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 100));
      }

      await show('10.0.0.6');
      expect(find.text('Căn chỉnh tem'), findsOneWidget);
      // Đầu in của máy tem: độ phân giải + ruy-băng (máy hoá đơn không có).
      expect(find.text('Độ phân giải đầu in'), findsOneWidget);
      expect(find.text('Máy in ruy-băng mực'), findsOneWidget);
      // Khổ tem tự nhận từ lần in gần nhất — không có ô chọn khổ.
      expect(find.text('Số tem / hàng'), findsNothing);
      expect(find.text('Công tắc'), findsNothing);
      expect(find.text('In tem thử'), findsWidgets);
      expect(find.text('In nhiều tem bị lệch dần?'), findsNothing);
      expect(find.text('Khổ giấy'), findsNothing);
      // Loại máy chỉ để xem, không có nút đổi.
      expect(find.text('Máy in tem'), findsOneWidget);
      expect(find.text('Nhận diện lại'), findsNothing);
      expect(find.text('Hoá đơn'), findsNothing);
      // Bấm mũi tên phải: dời 0,5mm và lưu cho đúng máy này.
      await t.tap(find.byIcon(Icons.keyboard_arrow_right_rounded));
      await t.pump();
      expect(agent.settingsOf('10.0.0.6').offsetXMm, 0.5);
      expect(agent.settingsOf('10.0.0.5').offsetXMm, 0);
      expect(find.textContaining('sang phải 0,5mm'), findsOneWidget);

      await show('10.0.0.5');
      expect(find.text('Khổ giấy'), findsOneWidget);
      expect(find.text('Còi báo'), findsOneWidget);
      expect(find.text('Tự động cắt giấy'), findsOneWidget);
      // "In thử" của máy hoá đơn nằm ở chân chi tiết máy in (cùng hàng "Xoá máy in"), không trong panel.
      expect(find.text('In thử'), findsNothing);
      expect(find.text('Căn chỉnh tem'), findsNothing);
      expect(find.text('Độ phân giải đầu in'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      agent.dispose();
      await t.binding.setSurfaceSize(null);
    },
  );

  group('máy tem thật qua socket: dò khe + nhận biết 300dpi', () {
    /// Máy in tem giả: ghi lại byte của TỪNG kết nối (một lệnh in = một kết nối).
    Future<(ServerSocket, List<String>)> fakePrinter(WidgetTester t) async {
      final received = <String>[];
      final server = (await t.runAsync(
        () => ServerSocket.bind(InternetAddress.loopbackIPv4, 0),
      ))!;
      server.listen((c) {
        final b = BytesBuilder();
        c.listen(
          b.add,
          onDone: () {
            received.add(latin1.decode(b.takeBytes()));
            c.destroy();
          },
        );
      });
      return (server, received);
    }

    /// Chờ [cond]: xen kẽ chờ I/O thật (runAsync) và pump — việc nối tiếp sau mỗi bước I/O
    /// (hàng đợi gửi, await socket) chạy trong vùng giả lập, chỉ tiến khi pump.
    Future<void> waitFor(WidgetTester t, bool Function() cond) async {
      for (var i = 0; i < 200 && !cond(); i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 25)),
        );
        await t.pump(const Duration(milliseconds: 25));
      }
      await t.pump();
    }

    Future<DesktopAgent> showLabelPanel(WidgetTester t, String address) async {
      await t.binding.setSurfaceSize(const Size(700, 2400));
      final agent = DesktopAgent(
        AgentConfig(printer: address, printerType: PrinterType.label),
      );
      agent.service.watchdog.report(
        DesktopPrinter(kind: AgentPrinterKind.lan, address: address),
        AgentPrinterState.connected,
      );
      await t.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrinterSettingsPanel(agent: agent, address: address),
            ),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 100));
      return agent;
    }

    testWidgets('bấm "Dò lại khe": máy nhận GAPDETECT và báo khách', (t) async {
      final (server, received) = await fakePrinter(t);
      final address = '127.0.0.1:${server.port}';
      final agent = await showLabelPanel(t, address);
      final button = find.text('Vừa đổi cuộn tem? Dò lại khe');
      expect(button, findsOneWidget);
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pump();
      await waitFor(t, () => received.isNotEmpty);
      await t.pump(const Duration(milliseconds: 200));
      expect(received, hasLength(1));
      expect(received.single, contains('GAPDETECT'));
      expect(find.textContaining('đang cuốn vài tem'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      agent.dispose();
      await t.runAsync(server.close);
    });

    testWidgets('nhận biết độ phân giải: in 2 tem thử, chọn tem B → lưu 300dpi', (
      t,
    ) async {
      final (server, received) = await fakePrinter(t);
      final address = '127.0.0.1:${server.port}';
      final agent = await showLabelPanel(t, address);
      expect(agent.settingsOf(address).dpi, 203);
      final button = find.text('Nhận biết tự động (in 2 tem thử)');
      expect(button, findsOneWidget);
      await t.ensureVisible(button);
      await t.tap(button);
      await t.pump();
      await waitFor(t, () => received.length >= 2);
      await t.pump(const Duration(milliseconds: 300));
      // Hai tem: A dựng cho 203dpi (72 byte/dòng), B cho 300dpi (107 byte/dòng).
      expect(received, hasLength(2));
      expect(received[0], contains('BITMAP 0,0,72,'));
      expect(received[1], contains('BITMAP 0,0,107,'));
      expect(find.text('Tem nào có khung đủ bốn cạnh?'), findsOneWidget);
      await t.tap(find.text('Tem B (ra sau)'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 200));
      expect(agent.settingsOf(address).dpi, 300);
      await t.pumpWidget(const SizedBox());
      agent.dispose();
      await t.runAsync(server.close);
    });

    testWidgets('chọn tem A → 203dpi; "không tem nào đủ" → không đổi gì', (
      t,
    ) async {
      final (server, received) = await fakePrinter(t);
      final address = '127.0.0.1:${server.port}';
      final agent = await showLabelPanel(t, address);
      await agent.updateSettings(
        address,
        agent.settingsOf(address).copyWith(dpi: 300),
      );
      await t.pump();
      Future<void> run(String choice) async {
        received.clear();
        final b = find.text('Nhận biết tự động (in 2 tem thử)');
        await t.ensureVisible(b);
        await t.tap(b);
        await t.pump();
        await waitFor(t, () => received.length >= 2);
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.text(choice));
        await t.pump();
        await t.pump(const Duration(milliseconds: 200));
      }

      await run('Không tem nào đủ');
      expect(agent.settingsOf(address).dpi, 300, reason: 'giữ nguyên');
      await run('Tem A (ra trước)');
      expect(agent.settingsOf(address).dpi, 203);
      await t.pumpWidget(const SizedBox());
      agent.dispose();
      await t.runAsync(server.close);
    });

    testWidgets('hình tem vẽ lại kiểu vàng bạc khi chọn 300dpi hoặc ruy-băng', (
      t,
    ) async {
      final (server, _) = await fakePrinter(t);
      final address = '127.0.0.1:${server.port}';
      final agent = await showLabelPanel(t, address);
      bool jewelry() => t
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<OffsetPreviewPainter>()
          .single
          .jewelry;
      expect(jewelry(), isFalse);
      await agent.updateSettings(
        address,
        agent.settingsOf(address).copyWith(dpi: 300),
      );
      await t.pump();
      expect(jewelry(), isTrue);
      await agent.updateSettings(
        address,
        agent.settingsOf(address).copyWith(dpi: 203),
      );
      await t.pump();
      expect(jewelry(), isFalse);
      await agent.updateSettings(
        address,
        agent.settingsOf(address).copyWith(ribbon: RibbonMode.on),
      );
      await t.pump();
      expect(jewelry(), isTrue);
      await t.pumpWidget(const SizedBox());
      agent.dispose();
      await t.runAsync(server.close);
    });
  });
}
