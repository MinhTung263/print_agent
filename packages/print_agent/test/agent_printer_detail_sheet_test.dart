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

  testWidgets(
    'máy lỗi: có nút Kết nối lại (và Đổi mạng khi khác mạng); máy ổn thì không',
    (t) async {
      Future<bool> never() async => true;
      final reconnect = LocaleKeys.printerSetting_agentReconnect.tr;
      final switchNet = LocaleKeys.printerSetting_agentSwitchNetwork.tr;

      await pump(
        t,
        AgentPrinterDetail(
          name: 'HPRT',
          kind: 'lan',
          state: AgentPrinterDetailState.notReady,
          on: true,
          onReconnect: never,
        ),
      );
      expect(find.text(reconnect), findsOneWidget);
      expect(find.text(switchNet), findsNothing);

      await pump(
        t,
        AgentPrinterDetail(
          name: 'HPRT',
          kind: 'lan',
          state: AgentPrinterDetailState.notReady,
          on: true,
          onReconnect: never,
          onSwitchNetwork: never,
        ),
      );
      expect(find.text(reconnect), findsOneWidget);
      expect(find.text(switchNet), findsOneWidget);

      // Máy đang ổn: không có nút dù có callback.
      await pump(
        t,
        AgentPrinterDetail(
          name: 'HPRT',
          kind: 'lan',
          state: AgentPrinterDetailState.ready,
          on: true,
          onReconnect: never,
        ),
      );
      expect(find.text(reconnect), findsNothing);
      expect(t.takeException(), isNull);
    },
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

  testWidgets('có onRemove: hiện nút Xoá máy in; không có thì không hiện', (
    t,
  ) async {
    await pump(
      t,
      AgentPrinterDetail(
        name: 'Bếp',
        kind: 'lan',
        state: AgentPrinterDetailState.ready,
        on: true,
        onRemove: () async => true,
      ),
    );
    expect(
      find.text(LocaleKeys.printerSetting_agentPrinterRemove.tr),
      findsOneWidget,
    );
    await pump(
      t,
      const AgentPrinterDetail(
        name: 'Bếp',
        kind: 'lan',
        state: AgentPrinterDetailState.ready,
        on: true,
      ),
    );
    expect(
      find.text(LocaleKeys.printerSetting_agentPrinterRemove.tr),
      findsNothing,
    );
  });
}
