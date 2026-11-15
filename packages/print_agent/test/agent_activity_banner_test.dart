import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/l10n/agent_locale_keys.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/agent_activity_banner.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

void main() {
  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    Get.locale = const Locale('vi', 'VN');
    AgentPrintActivityStore.items.clear();
  });

  Future<void> pump(WidgetTester t) => t.pumpWidget(
    const GetMaterialApp(home: Scaffold(body: AgentActivityBanner())),
  );

  /// Chạy hết hẹn giờ của kho hoạt động (chốt an toàn 2 phút + giữ kết quả 5s).
  Future<void> drain(WidgetTester t) async {
    await t.pump(const Duration(minutes: 3));
    AgentPrintActivityStore.items.clear();
  }

  testWidgets('không có lệnh in: không hiện gì', (t) async {
    await pump(t);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('đang in: ghi máy in nào, từ máy nào, loại phiếu', (t) async {
    final seq = AgentPrintActivityStore.start(
      isLabel: false,
      builtIn: false,
      usb: false,
      ip: '10.0.0.9',
      sender: 'Quầy 1',
    );
    await pump(t);
    expect(find.text('10.0.0.9'), findsOneWidget);
    expect(
      find.textContaining(
        LocaleKeys.printerSetting_agentActivityPrintingReceipt.tr,
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Quầy 1'), findsOneWidget);
    AgentPrintActivityStore.finish(seq, ok: true);
    await t.pump();
    expect(
      find.textContaining(LocaleKeys.printerSetting_agentActivityDone.tr),
      findsOneWidget,
    );
    await drain(t);
  });

  testWidgets('chỉ hiện tối đa 3 lệnh mới nhất', (t) async {
    for (var i = 0; i < 5; i++) {
      AgentPrintActivityStore.start(
        isLabel: false,
        builtIn: false,
        usb: false,
        ip: '10.0.0.$i',
      );
    }
    await pump(t);
    expect(find.text('10.0.0.4'), findsOneWidget);
    expect(find.text('10.0.0.2'), findsOneWidget);
    expect(find.text('10.0.0.1'), findsNothing);
    await drain(t);
  });
}
