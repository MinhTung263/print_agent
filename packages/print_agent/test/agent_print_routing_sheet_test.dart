import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/l10n/agent_locale_keys.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/routing/agent_print_routing_card.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/routing/agent_printer_functions.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

const _templates = [
  AgentPrintTemplate(
    id: 5,
    name: 'Bill 80',
    function: AgentPrintFunction.payment,
  ),
  AgentPrintTemplate(
    id: 6,
    name: 'Tạm tính 80',
    function: AgentPrintFunction.provisional,
  ),
];

AgentPrintRoutingMemoryStore _store({
  List<AgentPrintRoute> routes = const [],
}) => AgentPrintRoutingMemoryStore(
  routes: routes,
  templates: _templates,
  printers: const ['Xprinter', 'Máy bếp'],
  defaultPrinter: 'Xprinter',
);

void main() {
  printerFunctionsTests();
  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    Get.locale = const Locale('vi', 'VN');
  });

  Widget host(Widget child) => GetMaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('thẻ: tóm tắt + công tắc lưu xuống kho', (t) async {
    final store = _store(
      routes: const [
        AgentPrintRoute(
          function: AgentPrintFunction.payment,
          printerName: 'Xprinter',
          templateId: 5,
        ),
      ],
    );
    await t.pumpWidget(host(AgentPrintRoutingCard(store: store)));
    await t.pumpAndSettle();
    // Bảng: dòng Thanh toán có máy Xprinter; chức năng khác ghi "Chưa có máy".
    expect(find.text('Xprinter'), findsOneWidget);
    expect(
      find.text(LocaleKeys.printerSetting_routingNone.tr),
      findsNWidgets(AgentPrintFunction.values.length - 1),
    );
    await t.tap(find.byType(AgentSwitch).first);
    await t.pumpAndSettle();
    expect(await store.previewBeforePayment(), isFalse);
    await t.tap(find.byType(AgentSwitch).last);
    await t.pumpAndSettle();
    expect(await store.askCopiesEachPrint(), isTrue);
  });
}

void printerFunctionsTests() {
  Widget host(Widget child) => GetMaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  testWidgets('chi tiết máy in: bấm chức năng là tự lưu, bấm lại là bỏ', (
    t,
  ) async {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    Get.locale = const Locale('vi', 'VN');
    final store = _store();
    await t.pumpWidget(
      host(AgentPrinterFunctions(store: store, printerName: 'Xprinter')),
    );
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('fn_payment')));
    await t.pumpAndSettle();
    var saved = await store.load();
    expect(saved.single.function, AgentPrintFunction.payment);
    expect(saved.single.printerName, 'Xprinter');
    expect(saved.single.templateId, 5, reason: 'tự điền mẫu đúng loại');

    await t.tap(find.byKey(const ValueKey('fn_payment')));
    await t.pumpAndSettle();
    saved = await store.load();
    expect(saved, isEmpty);
  });

  testWidgets(
    'chức năng đang ở máy khác: chọn là thêm cho máy này, không đụng máy kia',
    (t) async {
      PrintAgentModule.init(FakeHost());
      PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
      Get.locale = const Locale('vi', 'VN');
      final store = _store(
        routes: const [
          AgentPrintRoute(
            function: AgentPrintFunction.payment,
            printerName: 'Máy bếp',
            templateId: 5,
          ),
        ],
      );
      await t.pumpWidget(
        host(AgentPrinterFunctions(store: store, printerName: 'Xprinter')),
      );
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('fn_payment')));
      await t.pumpAndSettle();
      var saved = await store.load();
      expect({for (final r in saved) r.printerName}, {'Máy bếp', 'Xprinter'});
      // Bỏ chọn ở máy này: chỉ bỏ dòng của máy này.
      await t.tap(find.byKey(const ValueKey('fn_payment')));
      await t.pumpAndSettle();
      saved = await store.load();
      expect(saved.single.printerName, 'Máy bếp');
    },
  );

  testWidgets(
    'máy chưa nhận chức năng nào: gợi ý theo tên, bấm "Dùng gợi ý" là xong',
    (t) async {
      PrintAgentModule.init(FakeHost());
      PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
      Get.locale = const Locale('vi', 'VN');
      final store = _store();
      await t.pumpWidget(
        host(AgentPrinterFunctions(store: store, printerName: 'Xprinter')),
      );
      await t.pumpAndSettle();
      expect(
        find.text(LocaleKeys.printerSetting_printerFunctionsSuggest.tr),
        findsOneWidget,
      );
      await t.tap(
        find.text(LocaleKeys.printerSetting_printerFunctionsSuggestApply.tr),
      );
      await t.pumpAndSettle();
      final saved = await store.load();
      expect(
        {for (final r in saved) r.function},
        {AgentPrintFunction.payment, AgentPrintFunction.provisional},
        reason:
            'Tạm tính + Thanh toán có mẫu; QR chưa có mẫu trong dữ liệu thử nên không đủ cặp',
      );
      // Đã nhận chức năng: không còn gợi ý.
      expect(
        find.text(LocaleKeys.printerSetting_printerFunctionsSuggest.tr),
        findsNothing,
      );
    },
  );

  testWidgets('máy tem: chỉ hiện chức năng Tem nhãn, gợi ý cũng chỉ Tem nhãn', (
    t,
  ) async {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
    Get.locale = const Locale('vi', 'VN');
    final store = AgentPrintRoutingMemoryStore(
      templates: const [
        AgentPrintTemplate(
          id: 6,
          name: 'Tem 40x30',
          function: AgentPrintFunction.label,
        ),
      ],
      printers: const ['4BARCODE'],
    );
    await t.pumpWidget(
      host(
        AgentPrinterFunctions(
          store: store,
          printerName: '4BARCODE',
          isLabelPrinter: true,
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('fn_label')), findsOneWidget);
    for (final f in AgentPrintFunction.values) {
      if (f == AgentPrintFunction.label) continue;
      expect(find.byKey(ValueKey('fn_${f.name}')), findsNothing);
    }
    await t.tap(
      find.text(LocaleKeys.printerSetting_printerFunctionsSuggestApply.tr),
    );
    await t.pumpAndSettle();
    expect((await store.load()).single.function, AgentPrintFunction.label);
  });
}
