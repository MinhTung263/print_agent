import 'package:flutter_test/flutter_test.dart';
import 'package:printer_label/desktop.dart' show BeepStyle;
import 'package:print_agent_desktop/agent/printer_type.dart';
import 'package:print_agent_desktop/printers/printer_beep_plan.dart';

void main() {
  test('máy tem: SOUND → nhích tem (HOME) → ESC/POS; quay vòng khi hết', () {
    expect(PrinterBeepPlan.styleFor(PrinterType.label, 0), BeepStyle.tsplSound);
    expect(PrinterBeepPlan.styleFor(PrinterType.label, 1), BeepStyle.tsplHome);
    expect(PrinterBeepPlan.styleFor(PrinterType.label, 2), BeepStyle.escpos);
    expect(PrinterBeepPlan.styleFor(PrinterType.label, 3), BeepStyle.tsplSound);
    expect(PrinterBeepPlan.hasMore(PrinterType.label, 1), isTrue);
    expect(PrinterBeepPlan.hasMore(PrinterType.label, 2), isFalse);
  });

  test('máy hoá đơn: ESC/POS trước, rồi TSPL; không bao giờ HOME', () {
    expect(PrinterBeepPlan.of(PrinterType.receipt), [
      BeepStyle.escpos,
      BeepStyle.tsplSound,
    ]);
  });

  test(
    'chưa rõ loại: ESC/POS (nhị phân, an toàn) → TSPL kêu còi → nhích tem',
    () {
      expect(PrinterBeepPlan.of(null), [
        BeepStyle.escpos,
        BeepStyle.tsplSound,
        BeepStyle.tsplHome,
      ]);
    },
  );

  test('mọi cách bíp đều có mô tả để báo khách', () {
    for (final s in BeepStyle.values) {
      expect(PrinterBeepPlan.describe(s), isNotEmpty);
    }
  });
}
