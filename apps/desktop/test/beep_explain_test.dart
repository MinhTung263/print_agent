import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/printers/data/desktop_printer_discovery.dart';

String _why({String? mac, bool sameSubnet = true}) =>
    DesktopPrinterDiscovery.explainUnreachableLan(
      ip: '192.168.1.100',
      port: 9100,
      mac: mac,
      sameSubnet: sameSubnet,
    );

void main() {
  test('IP do điện thoại dùng (MAC ngẫu nhiên): nói rõ không phải máy in', () {
    final m = _why(mac: '56:23:38:9f:da:cd');
    expect(m, contains('thiết bị khác'));
    expect(m, contains('Đổi IP'));
    expect(m, isNot(contains('bận')));
  });

  test(
    'MAC thật của hãng nhưng cổng in đóng: báo cổng đóng / có thể trùng IP',
    () {
      final m = _why(mac: '00:61:6D:1A:C1:13');
      expect(m, contains('cổng 9100 đóng'));
    },
  );

  test('không ai trả lời: máy in tắt / đổi IP', () {
    expect(_why(), contains('Không có thiết bị nào trả lời'));
  });

  test('khác dải mạng: báo khác mạng', () {
    expect(
      _why(sameSubnet: false, mac: '56:23:38:9f:da:cd'),
      contains('không cùng dải'),
    );
  });
}
