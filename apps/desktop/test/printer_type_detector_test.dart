import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/printer_type.dart';
import 'package:print_agent_desktop/printers/printer_type_detector.dart';
import 'package:printer_label/desktop.dart' show PrinterLanguage;

void main() {
  PrinterType? decide(PrinterLanguage? l, [String? model]) =>
      PrinterTypeDetector.decide(language: l, model: model).type;

  test('trả lời lệnh tem → máy in tem', () {
    expect(decide(PrinterLanguage.label), PrinterType.label);
  });

  test('trả lời cả hai kiểu → chọn Tem (máy hoá đơn không hiểu lệnh tem)', () {
    expect(decide(PrinterLanguage.both), PrinterType.label);
  });

  test(
    'chỉ trả lời lệnh hoá đơn → máy in hoá đơn, trừ khi tên model là máy tem',
    () {
      expect(decide(PrinterLanguage.receipt), PrinterType.receipt);
      expect(
        decide(PrinterLanguage.receipt, 'Xprinter XP-80C'),
        PrinterType.receipt,
      );
      expect(
        decide(PrinterLanguage.receipt, 'Xprinter XP-420B'),
        PrinterType.label,
      );
    },
  );

  test('không trả lời: dựa vào tên model; không có gì thì chưa rõ (null)', () {
    expect(decide(PrinterLanguage.unknown, 'TSC TTP-244'), PrinterType.label);
    expect(decide(null, 'Gprinter GP-1324D'), PrinterType.label);
    expect(decide(PrinterLanguage.unknown), isNull);
    expect(decide(null, 'XP-80C'), isNull);
  });

  test('ghi chú nêu lý do để người dùng biết khi nào cần chọn tay', () {
    final g = PrinterTypeDetector.decide(language: PrinterLanguage.both);
    expect(g.note, contains('cả lệnh hoá đơn và lệnh tem'));
    expect(
      PrinterTypeDetector.decide(language: null).note,
      contains('chọn loại'),
    );
  });
}
