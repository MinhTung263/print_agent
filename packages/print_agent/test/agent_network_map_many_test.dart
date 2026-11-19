import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

void main() {
  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    Get.locale = const Locale('vi', 'VN');
  });

  testWidgets(
    'cửa hàng nhiều máy in (30): dựng đủ, không lỗi bố cục, xếp tối đa 6 cột',
    (t) async {
      await t.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        GetMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentNetworkMap(
                center: const AgentMapNode(
                  icon: Icons.hub_rounded,
                  title: 'Máy này',
                  kind: AgentMapNodeKind.agent,
                ),
                nodes: [
                  for (var i = 0; i < 30; i++)
                    AgentMapNode(
                      icon: Icons.print,
                      title: 'May$i',
                      lines: const [],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pump();
      expect(t.takeException(), isNull);
      for (var i = 0; i < 30; i++) {
        expect(find.text('May$i'), findsOneWidget);
      }
      // Hàng đầu (6 máy) cùng một tung độ; máy thứ 7 xuống hàng dưới.
      final y0 = t.getCenter(find.text('May0')).dy;
      expect(t.getCenter(find.text('May5')).dy, y0);
      expect(t.getCenter(find.text('May6')).dy, greaterThan(y0 + 80));
    },
  );
}
