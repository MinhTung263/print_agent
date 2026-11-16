import 'dart:async';

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

/// Bộ giao diện thay vòng chờ bằng chữ để biết widget của module có dùng
/// `PrintAgentUi.kit.spinner` (app chủ tự chọn kiểu vòng chờ) hay không.
class _MarkerKit extends MaterialAgentUiKit {
  const _MarkerKit();

  @override
  Widget spinner({double size = 18, Color? color}) =>
      const Text('VONG_CHO', textDirection: TextDirection.ltr);
}

void main() {
  setUp(() {
    PrintAgentModule.init(FakeHost());
    Get.locale = const Locale('vi', 'VN');
  });

  testWidgets('MaterialAgentUiKit: vòng chờ mặc định kiểu Material', (t) async {
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    await t.pumpWidget(
      MaterialApp(home: Scaffold(body: PrintAgentUi.kit.spinner(size: 20))),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('nút In thử đang in dùng vòng chờ của bộ giao diện app chủ', (
    t,
  ) async {
    PrintAgentUi.init(const _MarkerKit(), station: FakeStation());
    final done = Completer<AgentTestPrintResult>();
    await t.pumpWidget(
      GetMaterialApp(
        home: Scaffold(
          body: AgentPrinterDetailSheet(
            detail: AgentPrinterDetail(
              name: 'Bếp',
              kind: 'lan',
              state: AgentPrinterDetailState.ready,
              on: true,
              onTestPrint: () => done.future,
            ),
          ),
        ),
      ),
    );
    expect(find.text('VONG_CHO'), findsNothing);
    await t.tap(find.text(LocaleKeys.printerSetting_agentTestPrint.tr).last);
    await t.pump();
    expect(find.text('VONG_CHO'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    done.complete(AgentTestPrintResult.done);
    await t.pump();
    await t.pump(const Duration(seconds: 3));
  });
}
