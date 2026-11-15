import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/l10n/agent_locale_keys.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/agent_doctor_card.dart';

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

  Future<void> pump(WidgetTester t, Map<String, bool> cloud) => t.pumpWidget(
    GetMaterialApp(
      home: Scaffold(body: AgentDoctorCard(cloud: AgentCloudInfo(cloud))),
    ),
  );

  testWidgets('mất Internet + chưa có máy in: báo việc cần xem, vai trò', (
    t,
  ) async {
    await pump(t, const {'MQTT': false});
    expect(t.takeException(), isNull);
    expect(
      find.text(LocaleKeys.printerSetting_agentDoctorInternetDown.tr),
      findsOneWidget,
    );
    expect(
      find.text(LocaleKeys.printerSetting_agentDoctorPrintersNone.tr),
      findsOneWidget,
    );
    expect(
      find.text(LocaleKeys.printerSetting_agentDoctorPrimary.tr),
      findsOneWidget,
    );
    // Không lộ tên kênh kỹ thuật.
    expect(find.textContaining('MQTT'), findsNothing);

    station.isPrimary.value = false;
    await t.pump();
    expect(
      find.text(LocaleKeys.printerSetting_agentDoctorStandby.tr),
      findsOneWidget,
    );
  });
}
