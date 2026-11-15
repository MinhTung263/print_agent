import 'package:print_agent_desktop/ui/agent_map/agent_map_node.dart';
import 'package:print_agent_desktop/ui/agent_map/agent_network_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sơ đồ máy bán hàng: máy này là gốc, nối tới các Agent + máy in của Agent.
void main() {
  AgentMapNode n(String t, {bool agent = false}) => AgentMapNode(
    icon: Icons.print_rounded,
    title: t,
    kind: agent ? AgentMapNodeKind.agent : AgentMapNodeKind.device,
  );

  for (final width in [390.0, 1000.0]) {
    for (final agents in [0, 1, 2, 3]) {
      testWidgets('máy này làm gốc · $agents Agent · rộng $width', (t) async {
        t.view.physicalSize = Size(width, 2400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AgentNetworkMap(
                  cloud: n('Đám mây'),
                  center: n('Máy này'),
                  linkClusters: true,
                  clusters: [
                    for (var i = 0; i < agents; i++)
                      AgentMapCluster(
                        agent: n('Agent $i', agent: true),
                        printers: [n('PDIT'), n('Epson'), n('Tích hợp')],
                      ),
                  ],
                  emptyText: 'Chưa có Agent',
                ),
              ),
            ),
          ),
        );
        expect(t.takeException(), isNull);
        expect(find.text('Máy này'), findsOneWidget);
      });
    }
  }
}
