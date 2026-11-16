import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/desktop_extra_printers.dart';
import 'package:print_agent_desktop/agent/desktop_printer_gateway.dart';

void main() {
  late Directory dir;
  var company = '1';

  setUp(() {
    dir = Directory.systemTemp.createTempSync('extra_printers_');
    AgentStore.debugDirectory = dir;
    company = '1';
  });
  tearDown(() => AgentStore.debugDirectory = null);

  DesktopExtraPrinters store() => DesktopExtraPrinters(() => company);

  test('thêm, không trùng, lưu lại giữa các lần mở', () {
    final s = store();
    expect(s.add('192.168.1.50'), isTrue);
    expect(s.add('192.168.1.50'), isFalse);
    expect(s.add('  '), isFalse);
    expect(store().items.map((e) => e.address), ['192.168.1.50']);
  });

  test('cập nhật tên + loại → tiêu đề "Máy in tem · XP-420B"', () {
    final s = store()..add('192.168.1.51');
    s.update('192.168.1.51', name: 'XP-420B', type: PrinterType.label);
    expect(s.byAddress('192.168.1.51')!.title, 'Máy in tem · XP-420B');
  });

  test('xoá và đổi IP theo MAC', () {
    final s = store()
      ..add('192.168.1.51')
      ..add('192.168.1.52');
    expect(s.moved('192.168.1.51', '192.168.1.99'), isTrue);
    expect(s.contains('192.168.1.99'), isTrue);
    expect(s.remove('192.168.1.52'), isTrue);
    expect(s.remove('192.168.1.52'), isFalse);
  });

  test('mỗi công ty một danh sách riêng', () {
    store().add('192.168.1.51');
    company = '2';
    expect(store().items, isEmpty);
  });

  test('tối đa ${DesktopExtraPrinters.maxPrinters} máy', () {
    final s = store();
    for (var i = 0; i < DesktopExtraPrinters.maxPrinters; i++) {
      expect(s.add('10.0.0.$i'), isTrue);
    }
    expect(s.add('10.0.1.1'), isFalse);
  });

  test(
    'sơ đồ: máy thêm luôn hiện (kể cả khi tắt "In hộ"), không lặp máy chính',
    () {
      final config = AgentConfig(companyId: 1, printer: '192.168.1.10');
      final gateway = DesktopPrinterGateway(() => config);
      gateway.extras
        ..add('192.168.1.10')
        ..add('192.168.1.60', type: PrinterType.label);
      expect(gateway.printers.map((p) => p.address), ['192.168.1.60']);
    },
  );
}
