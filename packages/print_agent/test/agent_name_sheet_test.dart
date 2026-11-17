import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/l10n/agent_locale_keys.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/agent_map_header.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/sheets/agent_name_sheet.dart';

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
    PrintAgentUi.onAddPrinter = null;
  });

  Widget host(Widget child) => GetMaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  FilledButton saveButton(WidgetTester t) => t.widget<FilledButton>(
    find.ancestor(
      of: find.text(LocaleKeys.printerSetting_agentNameSave.tr),
      matching: find.byType(FilledButton),
    ),
  );

  testWidgets(
    'Hộp tên trạm in chỉ có đặt tên: không còn "Thêm máy in" gây hiểu nhầm',
    (t) async {
      PrintAgentUi.onAddPrinter = () async {};
      await t.pumpWidget(host(const AgentNameSheet()));
      expect(
        find.text(LocaleKeys.printerSetting_agentAddPrinter.tr),
        findsNothing,
      );
      expect(
        find.text(LocaleKeys.printerSetting_agentNameSave.tr),
        findsOneWidget,
      );
    },
  );

  testWidgets('Lưu chỉ bấm được khi đã đổi tên (chưa đổi / để trống thì mờ)', (
    t,
  ) async {
    await t.pumpWidget(host(const AgentNameSheet()));
    expect(saveButton(t).onPressed, isNull, reason: 'chưa đổi gì');
    await t.enterText(find.byType(TextField), 'Bếp tầng 2');
    await t.pump();
    expect(saveButton(t).onPressed, isNotNull);
    await t.enterText(find.byType(TextField), '   ');
    await t.pump();
    expect(saveButton(t).onPressed, isNull, reason: 'tên trống');
    await t.enterText(find.byType(TextField), 'Bếp tầng 2');
    await t.pump();
    saveButton(t).onPressed!();
    await t.pumpAndSettle();
    expect(station.displayName, 'Bếp tầng 2');
  });

  testWidgets(
    '"Thêm máy in" nằm ở đầu sơ đồ của máy Agent (chỉ khi có hook), máy bán hàng thì không',
    (t) async {
      var opened = 0;
      PrintAgentUi.onAddPrinter = () async => opened++;
      await t.pumpWidget(host(AgentMapHeader(isAgent: true, onRefresh: () {})));
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      await t.tap(find.byIcon(Icons.add_rounded));
      expect(opened, 1);

      await t.pumpWidget(
        host(AgentMapHeader(isAgent: false, onRefresh: () {})),
      );
      expect(find.byIcon(Icons.add_rounded), findsNothing);

      PrintAgentUi.onAddPrinter = null;
      await t.pumpWidget(host(AgentMapHeader(isAgent: true, onRefresh: () {})));
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    },
  );
}
