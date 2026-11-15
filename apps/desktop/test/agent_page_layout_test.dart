import 'dart:io';

import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/print_agent.dart';
import 'package:print_agent_desktop/ui/agent_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(
    () => AgentStore.debugDirectory = Directory.systemTemp.createTempSync(
      'agent_cfg',
    ),
  );
  for (final width in [420.0, 1280.0]) {
    testWidgets('Màn Agent dựng được ở bề ngang $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final agent = PrintAgent(
        const AgentConfig(companyId: 5261, ownerId: 1, name: 'Quầy thu ngân'),
      )..startPreview();
      await tester.pumpWidget(MaterialApp(home: AgentPage(agent: agent)));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
      expect(find.text('Máy Agent'), findsOneWidget);
    });
  }
}
