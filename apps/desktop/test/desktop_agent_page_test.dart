import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/desktop_agent.dart';
import 'package:print_agent_desktop/ui/dashboard/agent_settings_card.dart';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('desktop_agent_');
    AgentStore.debugDirectory = dir;
  });
  tearDown(() {
    AgentStore.debugDirectory = null;
    dir.deleteSync(recursive: true);
  });

  test('chuyển mã Agent / tên của bản trước sang khoá của module', () {
    AgentStore.set('id', 'abcdef0123456789');
    final agent = DesktopAgent(const AgentConfig(name: 'Quầy bar'));
    expect(agent.service.stationId, 'abcdef0123456789');
    expect(agent.service.displayName, 'Quầy bar');
  });

  testWidgets('màn Máy Agent của module + thẻ cài đặt máy tính', (t) async {
    await t.binding.setSurfaceSize(const Size(1280, 900));
    final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
    await t.pumpWidget(
      GetMaterialApp(
        home: AgentPage(agentSide: [AgentSettingsCard(agent: agent)]),
      ),
    );
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(AgentPage), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.binding.setSurfaceSize(null);
  });
}
