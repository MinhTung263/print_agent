import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/paper_size.dart';
import 'package:print_agent_desktop/printers/paper_size_detector.dart';

void main() {
  PaperSizeGuess g(String? m) => PaperSizeDetector.guess(m);

  test('tên máy ghi khổ 58 → 58mm (đoán được)', () {
    for (final m in [
      'XP-58IIH',
      'POS-58',
      'Printer 58mm',
      'PT-210',
      'ZJ-5890K',
    ]) {
      expect(g(m).size, PaperSize.size58, reason: m);
      expect(g(m).detected, isTrue, reason: m);
    }
  });

  test('tên máy ghi khổ 80 hoặc model 80mm quen thuộc → 80mm (đoán được)', () {
    for (final m in ['XP-80C', 'POS-80', 'Epson TM-T88V', 'TM-T20III', 'N80']) {
      expect(g(m).size, PaperSize.size80, reason: m);
      expect(g(m).detected, isTrue, reason: m);
    }
  });

  test('không biết → gợi ý 80mm, đánh dấu chưa đoán được', () {
    for (final m in [null, '', 'Gprinter USB Printer', 'Máy in mạng (LAN)']) {
      expect(g(m).size, PaperSize.size80, reason: '$m');
      expect(g(m).detected, isFalse, reason: '$m');
      expect(g(m).pill, '80mm · gợi ý');
    }
  });

  test('cả 58 và 80 xuất hiện → không đoán', () {
    expect(g('XP-58/80').detected, isFalse);
  });
}
