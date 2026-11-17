import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/printers/usb_printer_relevance.dart';

void main() {
  bool ok(String name, {String? id}) =>
      UsbPrinterRelevance.isUsable(name, deviceId: id);

  test('máy in phiếu / tem quen thuộc: giữ', () {
    for (final n in [
      'ZHU HAI HOWBEST Receipt Printer',
      '4BARCODE 3B-300B',
      'HPRT TP806',
      'Xprinter XP-80C',
      'XP-420B',
      'EPSON TM-T82',
      'Star TSP143',
      'Rongta RP326',
      'GP-1324D',
      'Munbyn ITPP941',
      'TSC TTP-244',
      'Zebra ZD220',
      'Receipt Printer',
      'POS-80',
    ]) {
      expect(ok(n), isTrue, reason: n);
    }
  });

  test('máy in văn phòng / khổ lớn / đa năng: bỏ', () {
    for (final n in [
      'HP-Designjet-T920',
      'HP DesignJet T520',
      'HP LaserJet Pro M404',
      'HP DeskJet 2130',
      'Canon PIXMA G3010',
      'Canon imageCLASS MF445',
      'EPSON L3150 Series',
      'Epson EcoTank ET-2810',
      'Brother HL-L2321D',
      'Brother DCP-T420W',
      'Samsung ML-2165',
      'Lexmark MS431',
      'Kyocera ECOSYS',
      'Ricoh SP 111',
    ]) {
      expect(ok(n), isFalse, reason: n);
    }
  });

  test('hàng in ảo / phần mềm: bỏ', () {
    for (final n in [
      'Microsoft Print to PDF',
      'Microsoft XPS Document Writer',
      'OneNote (Desktop)',
      'Fax',
      'CUPS-PDF',
      'Snagit 2023',
    ]) {
      expect(ok(n), isFalse, reason: n);
    }
  });

  test('máy không khai tên: giữ (bỏ nhầm máy thật tệ hơn hiện thừa)', () {
    expect(ok('USB 1fc9:2016:03365B35'), isTrue);
    expect(ok(''), isTrue);
  });

  test('chuỗi IEEE 1284 quyết định khi tên không rõ', () {
    // Tên lạ nhưng tự báo hiểu ESC/POS → giữ.
    expect(
      ok('Máy lạ', id: 'MFG:ACME;MDL:X1;CMD:ESC/POS;CLS:PRINTER;'),
      isTrue,
    );
    expect(ok('Máy lạ', id: 'MFG:ACME;MDL:X1;CMD:TSPL2;CLS:PRINTER;'), isTrue);
    // Tên lạ, chỉ hiểu PCL / PostScript → bỏ.
    expect(
      ok('Máy lạ', id: 'MFG:ACME;MDL:Y9;CMD:PCL,PJL,POSTSCRIPT;CLS:PRINTER;'),
      isFalse,
    );
    // Máy phiếu thật dù tên có chữ "Receipt" mà lệnh văn phòng: tên thắng (đã khai là phiếu).
    expect(
      ok('Receipt Printer', id: 'MFG:ZHU HAI;MDL:HOWBEST;CMD:PCL;CLS:PRINTER;'),
      isTrue,
    );
    // Lệnh phiếu thắng cả tên giống máy văn phòng.
    expect(
      ok('HP Something', id: 'MFG:HP;MDL:Special;CMD:ESC/POS,PCL;CLS:PRINTER;'),
      isTrue,
    );
  });

  test('decidedByName: kết luận được mà không cần hỏi máy', () {
    expect(UsbPrinterRelevance.decidedByName('Xprinter XP-80C'), isTrue);
    expect(UsbPrinterRelevance.decidedByName('HP-Designjet-T920'), isFalse);
    expect(
      UsbPrinterRelevance.decidedByName('Microsoft Print to PDF'),
      isFalse,
    );
    expect(UsbPrinterRelevance.decidedByName('Máy lạ'), isNull);
  });
}
