import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/printers/label_dpi_guess.dart';

void main() {
  test('tên model ghi 300 → máy 300dpi', () {
    for (final name in [
      '4BARCODE 3B 300B',
      '4BARCODE 3B-300B',
      'ZT230-300',
      'TTP-346M 300dpi',
      'Godex G530 300 DPI',
      'xx_300',
    ]) {
      expect(LabelDpiGuess.fromModel(name), 300, reason: name);
    }
  });

  test('không ghi 300 → không đoán (giữ 203dpi phổ thông)', () {
    for (final name in ['XP-420B', 'Gprinter GP-1324D', 'Zebra GK420t']) {
      expect(LabelDpiGuess.fromModel(name), isNull, reason: name);
    }
    expect(LabelDpiGuess.fromModel(null), isNull);
    expect(LabelDpiGuess.fromModel('   '), isNull);
  });

  test('số khác có chứa 300 không bị nhầm: 1300, 3000, 2300B', () {
    for (final name in ['TSC TE1300', 'Model 3000', 'ABC 2300B']) {
      expect(LabelDpiGuess.fromModel(name), isNull, reason: name);
    }
  });
}
