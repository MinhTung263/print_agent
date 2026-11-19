import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

void main() {
  plannerTests();
  suggestTests();
  const pay = AgentPrintRoute(
    function: AgentPrintFunction.payment,
    printerName: 'Xprinter',
    templateId: 1,
  );

  test('dòng trống (bản ghi mặc định khi tạo tài khoản) hợp lệ', () {
    expect(
      AgentPrintRouteValidator.isValid(const [
        AgentPrintRoute(function: AgentPrintFunction.provisional),
      ]),
      isTrue,
    );
  });

  test('đủ cặp máy in + mẫu in: hợp lệ', () {
    expect(AgentPrintRouteValidator.isValid(const [pay]), isTrue);
  });

  test('có máy in mà thiếu mẫu in: chặn', () {
    final r = AgentPrintRouteValidator.validate(const [
      AgentPrintRoute(
        function: AgentPrintFunction.payment,
        printerName: 'Xprinter',
      ),
    ]);
    expect(r[0], {AgentPrintRouteIssue.missingTemplate});
  });

  test('có mẫu in mà thiếu máy in: chặn', () {
    final r = AgentPrintRouteValidator.validate(const [
      AgentPrintRoute(function: AgentPrintFunction.payment, templateId: 3),
    ]);
    expect(r[0], {AgentPrintRouteIssue.missingPrinter});
  });

  test('trùng tên chức năng: báo cả hai dòng, không phân biệt hoa thường', () {
    final r = AgentPrintRouteValidator.validate([
      pay,
      pay.copyWith(name: 'THANH TOÁN'),
      const AgentPrintRoute(function: AgentPrintFunction.label),
    ]);
    expect(r[0], contains(AgentPrintRouteIssue.duplicateName));
    expect(r[1], contains(AgentPrintRouteIssue.duplicateName));
    expect(r.containsKey(2), isFalse);
  });

  test('tên khác nhau cùng loại chức năng thì không trùng', () {
    expect(
      AgentPrintRouteValidator.isValid([
        pay,
        pay.copyWith(name: 'Thanh toán bếp'),
      ]),
      isTrue,
    );
  });

  test('số bản in dưới 1: chặn', () {
    final r = AgentPrintRouteValidator.validate([pay.copyWith(copies: 0)]);
    expect(r[0], {AgentPrintRouteIssue.invalidCopies});
  });

  test('fromValue khớp type_template 0–7', () {
    for (final f in AgentPrintFunction.values) {
      expect(AgentPrintFunction.fromValue(f.value), f);
    }
    expect(AgentPrintFunction.fromValue(9), isNull);
  });

  test('kho trong bộ nhớ lưu và đọc lại', () async {
    final s = AgentPrintRoutingMemoryStore();
    await s.save(const [pay]);
    expect((await s.load()).single.printerName, 'Xprinter');
    await s.setAskCopiesEachPrint(true);
    expect(await s.askCopiesEachPrint(), isTrue);
  });
}

void plannerTests() {
  const tpls = [
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

  test('thêm chức năng: tự điền máy mặc định + mẫu đúng loại', () {
    final r = AgentPrintRoutePlanner.create(
      AgentPrintFunction.payment,
      printers: ['A', 'B'],
      templates: tpls,
      defaultPrinter: 'B',
    );
    expect(r.printerName, 'B');
    expect(r.templateId, 5);
  });

  test(
    'chỉ có một máy in: tự chọn máy đó; nhiều máy mà không có mặc định: để trống',
    () {
      expect(
        AgentPrintRoutePlanner.create(
          AgentPrintFunction.payment,
          printers: ['A'],
          templates: tpls,
        ).printerName,
        'A',
      );
      expect(
        AgentPrintRoutePlanner.create(
          AgentPrintFunction.payment,
          printers: ['A', 'B'],
          templates: tpls,
        ).printerName,
        isNull,
      );
    },
  );

  test(
    'chưa có mẫu đúng loại: để trống mẫu; máy mặc định không còn: bỏ qua',
    () {
      final r = AgentPrintRoutePlanner.create(
        AgentPrintFunction.label,
        printers: ['A', 'B'],
        templates: tpls,
        defaultPrinter: 'X',
      );
      expect(r.templateId, isNull);
      expect(r.printerName, isNull);
    },
  );

  test('chức năng chưa dùng + tóm tắt', () {
    const r = AgentPrintRoute(
      function: AgentPrintFunction.payment,
      printerName: 'A',
      templateId: 5,
    );
    final unused = AgentPrintRoutePlanner.unused([r]);
    expect(unused.contains(AgentPrintFunction.payment), isFalse);
    expect(unused.length, AgentPrintFunction.values.length - 1);
    expect(AgentPrintRoutePlanner.summary(r), 'Thanh toán → A');
    expect(
      AgentPrintRoutePlanner.summary(
        const AgentPrintRoute(function: AgentPrintFunction.label),
      ),
      'Tem nhãn',
    );
  });
}

void suggestTests() {
  test('gợi ý theo tên máy: tem / bếp / hoá đơn', () {
    expect(AgentPrintRoutePlanner.suggest('4BARCODE 4B-2054'), [
      AgentPrintFunction.label,
    ]);
    expect(AgentPrintRoutePlanner.suggest('Máy in Bếp 1'), [
      AgentPrintFunction.kitchen,
      AgentPrintFunction.cancelDish,
    ]);
    expect(AgentPrintRoutePlanner.suggest('Xprinter XP-80'), [
      AgentPrintFunction.payment,
      AgentPrintFunction.provisional,
      AgentPrintFunction.paymentQr,
    ]);
  });

  test('không giành chức năng đã có máy khác nhận', () {
    const taken = AgentPrintRoute(
      function: AgentPrintFunction.payment,
      printerName: 'Máy quầy',
      templateId: 1,
    );
    expect(AgentPrintRoutePlanner.suggestFree('Xprinter', const [taken]), [
      AgentPrintFunction.provisional,
      AgentPrintFunction.paymentQr,
    ]);
  });
}
