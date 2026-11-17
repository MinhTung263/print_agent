import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

void main() {
  late FakeStation station;
  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(
      const MaterialAgentUiKit(),
      station: station = FakeStation(),
    );
    Get.locale = const Locale('vi', 'VN');
  });

  testWidgets('Thẻ nhật ký lệnh dựng qua bộ giao diện của app chủ', (t) async {
    AgentJobLogStore.add(
      AgentJobLog(
        at: DateTime.now(),
        isLabel: false,
        printerName: 'Máy in bếp',
        ok: false,
        viaLan: true,
        durationMs: 420,
        sender: 'Quầy 1',
        error: AgentJobError.outOfPaper,
      ),
    );
    await t.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: AgentJobLogCard())),
    );
    await t.pump();
    expect(find.textContaining('Máy in bếp'), findsWidgets);
    expect(find.textContaining('Quầy 1'), findsWidgets);
    expect(t.takeException(), isNull);
    // Nhật ký được gom 3s rồi mới ghi xuống bộ nhớ.
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('Công tắc làm Agent gọi trạm của app chủ', (t) async {
    await t.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: PrintStationToggle())),
    );
    await t.tap(find.byType(AgentSwitch));
    await t.pumpAndSettle();
    expect(station.enabledCalls, [true]);
    expect(t.takeException(), isNull);
  });

  testWidgets('Thẻ lối vào màn Agent theo trạng thái trạm', (t) async {
    await t.pumpWidget(
      const GetMaterialApp(home: Scaffold(body: AgentEntryCard())),
    );
    expect(find.byType(AgentEntryCard), findsOneWidget);
    station.relay.isStation.value = true;
    await t.pump();
    expect(t.takeException(), isNull);
  });
}
