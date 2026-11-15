import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/l10n/agent_locale_keys.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/sheets/agent_printer_detail_sheet.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

void main() {
  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    Get.locale = const Locale('vi', 'VN');
  });

  Future<void> pump(WidgetTester t, AgentPrinterDetail d) => t.pumpWidget(
    GetMaterialApp(
      home: Scaffold(body: AgentPrinterDetailSheet(detail: d)),
    ),
  );

  testWidgets('máy in LAN: tên, trạng thái, IP, MAC, mã, trạm in, công tắc', (
    t,
  ) async {
    await pump(
      t,
      AgentPrinterDetail(
        name: 'Bếp',
        kind: 'lan',
        state: AgentPrinterDetailState.ready,
        on: true,
        address: '192.168.1.12',
        mac: '00:5C:17:DA:C8:88',
        id: 42,
        station: 'Quầy thu ngân',
        onToggle: () {},
      ),
    );
    expect(t.takeException(), isNull);
    for (final text in [
      'Bếp',
      '192.168.1.12',
      '00:5C:17:DA:C8:88',
      '42',
      'Quầy thu ngân',
      LocaleKeys.printerSetting_agentPrinterDetailReady.tr,
      LocaleKeys.printerSetting_agentPrinterKindLan.tr,
      LocaleKeys.printerSetting_agentPrinterDetailReceive.tr,
    ]) {
      expect(find.text(text), findsOneWidget, reason: text);
    }
  });

  testWidgets('máy in có sẵn của trạm đang tắt: không IP, không công tắc', (
    t,
  ) async {
    await pump(
      t,
      const AgentPrinterDetail(
        name: 'Máy in tích hợp',
        kind: 'builtin',
        state: AgentPrinterDetailState.stationOff,
        on: true,
        address: 'builtin',
        paper: 'size58',
      ),
    );
    expect(find.text('58mm'), findsOneWidget);
    expect(find.text('builtin'), findsNothing);
    expect(
      find.text(LocaleKeys.printerSetting_agentPrinterDetailStationOff.tr),
      findsOneWidget,
    );
    expect(
      find.text(LocaleKeys.printerSetting_agentPrinterDetailReceive.tr),
      findsNothing,
    );
  });

  testWidgets('nút In thử: có khi in thử được, bấm thì gọi in', (t) async {
    final calls = <int>[];
    await pump(
      t,
      AgentPrinterDetail(
        name: 'Bếp',
        kind: 'lan',
        state: AgentPrinterDetailState.ready,
        on: true,
        onTestPrint: () async {
          calls.add(1);
          return AgentTestPrintResult.done;
        },
      ),
    );
    final label = LocaleKeys.printerSetting_agentTestPrint.tr;
    // Tiêu đề thẻ + nút cùng chữ "In thử".
    expect(find.text(label), findsNWidgets(2));
    await t.tap(find.text(label).last);
    await t.pump();
    expect(calls, [1]);
  });

  testWidgets('trạm in đang tắt: không có nút In thử', (t) async {
    await pump(
      t,
      const AgentPrinterDetail(
        name: 'Bếp',
        kind: 'lan',
        state: AgentPrinterDetailState.stationOff,
        on: true,
      ),
    );
    expect(
      find.text(LocaleKeys.printerSetting_agentTestPrint.tr),
      findsNothing,
    );
  });
}
