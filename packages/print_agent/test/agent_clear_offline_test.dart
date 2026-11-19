import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/agent_map_header.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

void main() {
  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    Get.locale = const Locale('vi', 'VN');
    KnownAgents.items.clear();
  });

  Widget host(int Function() offline, VoidCallback onClear) => GetMaterialApp(
    home: Scaffold(
      body: AgentMapHeader(
        isAgent: true,
        onRefresh: () {},
        offlineAgents: offline,
        onClearOffline: onClear,
      ),
    ),
  );

  testWidgets('có máy ngoại tuyến: hiện nút xoá và bấm gọi xoá', (t) async {
    var cleared = 0;
    await t.pumpWidget(host(() => 2, () => cleared++));
    expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
    await t.tap(find.byIcon(Icons.delete_sweep_rounded));
    expect(cleared, 1);
  });

  testWidgets('không có máy ngoại tuyến: không hiện nút xoá', (t) async {
    await t.pumpWidget(host(() => 0, () {}));
    expect(find.byIcon(Icons.delete_sweep_rounded), findsNothing);
  });
}
