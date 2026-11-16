import 'dart:io';

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
import 'package:print_agent_desktop/store/printer_auto_add_plan.dart'
    show FoundPrinter;
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

  test(
    'quét mạng tìm thấy máy in: tự thành máy in của trạm, máy đã xoá không thêm lại',
    () async {
      final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
      final found = [
        const FoundPrinter(address: '10.0.0.5'), // máy in chính: bỏ qua
        const FoundPrinter(address: '10.0.0.6', mac: 'AA:BB:CC:DD:EE:01'),
        const FoundPrinter(address: '10.0.1.7', model: 'XP-420B'),
      ];
      expect(agent.registerScanned(found), 2);
      expect(
        agent.gateway.extras.byAddress('10.0.0.6')!.mac,
        'AA:BB:CC:DD:EE:01',
      );
      expect(agent.gateway.extras.byAddress('10.0.1.7')!.name, 'XP-420B');
      // Quét lại: không thêm trùng.
      expect(agent.registerScanned(found), 0);
      // Người dùng xoá máy 10.0.0.6: quét lần sau không tự thêm lại.
      expect(agent.removeExtraPrinter('10.0.0.6'), isTrue);
      expect(agent.registerScanned(found), 0);
      expect(agent.gateway.extras.contains('10.0.0.6'), isFalse);
      // Chủ động thêm lại thì được.
      await agent.addPrinter('10.0.0.6');
      expect(agent.gateway.extras.contains('10.0.0.6'), isTrue);
      agent.dispose();
    },
  );

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
      // Khổ tem tự nhận từ lần in gần nhất — không có ô chọn khổ.
      expect(find.text('Số tem / hàng'), findsNothing);
      expect(find.text('Công tắc'), findsNothing);
      expect(find.text('In tem thử'), findsWidgets);
      expect(find.text('In nhiều tem bị lệch dần?'), findsOneWidget);
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
      expect(find.text('In thử'), findsOneWidget);
      expect(find.text('Căn chỉnh tem'), findsNothing);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      agent.dispose();
      await t.binding.setSurfaceSize(null);
    },
  );
}
