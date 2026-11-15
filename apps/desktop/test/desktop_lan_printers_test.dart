import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/desktop_agent_host.dart';
import 'package:print_agent_desktop/agent/desktop_lan_printers.dart';
import 'package:print_agent_desktop/agent/desktop_printer.dart';
import 'package:print_agent_desktop/agent/desktop_printer_gateway.dart';

DesktopPrinter lan(
  String address, {
  Object? id,
  String name = '',
  String? mac,
}) => DesktopPrinter(
  kind: AgentPrinterKind.lan,
  address: address,
  name: name,
  id: id,
  mac: mac,
);

void main() {
  late Directory dir;
  var company = '1';
  var now = DateTime(2026, 11, 15, 8);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('lan_printers_');
    AgentStore.debugDirectory = dir;
    company = '1';
    now = DateTime(2026, 11, 15, 8);
  });

  tearDown(() => AgentStore.debugDirectory = null);

  DesktopLanPrinters store() =>
      DesktopLanPrinters(() => company, now: () => now);

  test('nhớ máy in đã in giúp; cùng mã máy in thì gộp (đổi IP / tên)', () {
    final s = store();
    expect(s.remember(lan('192.168.1.50', id: 7, name: 'Bếp')), isTrue);
    expect(s.remember(lan('192.168.1.50', id: 7, name: 'Bếp')), isFalse);
    expect(s.remember(lan('192.168.1.51', id: 7)), isTrue);
    expect(s.printers, hasLength(1));
    expect(s.printers.single.address, '192.168.1.51');
    expect(s.printers.single.name, 'Bếp', reason: 'lệnh không báo tên: giữ');
    // Lưu xuống file: mở lại vẫn còn.
    expect(store().printers.single.id, 7);
  });

  test('máy gửi không báo tên: không hiện IP lên sơ đồ', () {
    final s = store()..remember(lan('192.168.1.60'));
    expect(s.printers.single.name, DesktopLanPrinters.unnamed);
  });

  test('theo công ty: đổi công ty không thấy máy in của công ty kia', () {
    store().remember(lan('192.168.1.50', id: 1, name: 'Bếp'));
    company = '2';
    expect(store().printers, isEmpty);
    company = '1';
    expect(store().printers, hasLength(1));
  });

  test('tối đa ${DesktopLanPrinters.maxPrinters} máy; lâu không in thì bỏ', () {
    final s = store();
    for (var i = 0; i < DesktopLanPrinters.maxPrinters + 5; i++) {
      now = now.add(const Duration(minutes: 1));
      s.remember(lan('10.0.0.$i', id: i));
    }
    expect(s.printers, hasLength(DesktopLanPrinters.maxPrinters));
    expect(s.printers.any((p) => p.id == 0), isFalse, reason: 'bỏ máy cũ nhất');
    now = now.add(DesktopLanPrinters.keepFor + const Duration(days: 1));
    expect(store().printers, isEmpty);
  });

  test('tìm lại theo MAC ở IP mới: cập nhật địa chỉ', () {
    final s = store()..remember(lan('192.168.1.50', id: 3, mac: 'AA'));
    expect(s.moved(lan('192.168.1.50', id: 3), '192.168.1.80'), isTrue);
    expect(s.printers.single.address, '192.168.1.80');
  });

  test(
    'gateway: chỉ báo khi bật "In hộ máy in LAN", bỏ máy in của trạm',
    () async {
      var config = const AgentConfig(
        companyId: 1,
        ownerId: 1,
        printer: '192.168.1.9',
      );
      PrintAgentModule.init(DesktopAgentHost(() => config));
      final gateway = DesktopPrinterGateway(
        () => config,
        macOf: (ip) async => '00:5C:17:DA:C8:88',
      );
      var changes = 0;
      gateway.printersChanged.listen((_) => changes++);
      await gateway.printedFor(lan('192.168.1.50', id: 5, name: 'Bếp'));
      await gateway.printedFor(lan('192.168.1.9', name: 'Quầy'));
      expect(gateway.printers, isEmpty, reason: 'chưa bật in hộ');

      config = config.copyWith(acceptAll: true);
      expect(gateway.printers.map((p) => p.name), ['Bếp']);
      expect(gateway.printers.single.mac, '00:5C:17:DA:C8:88');
      await Future<void>.delayed(Duration.zero);
      expect(changes, greaterThan(0));
    },
  );
}
