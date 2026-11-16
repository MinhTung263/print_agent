import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/network/local_network_banner.dart';
import 'package:print_agent_desktop/network/local_network_check.dart';

LocalNetworkCheck _check({
  String? gateway = '192.168.1.1',
  required ProbeResult Function(int port) probe,
  bool internet = true,
}) => LocalNetworkCheck(
  gateway: () async => gateway,
  probe: (host, port) async => probe(port),
  internet: () async => internet,
);

void main() {
  group('LocalNetworkCheck', () {
    test('gateway từ chối cổng (có phản hồi) → ổn', () async {
      final r = await _check(probe: (_) => ProbeResult.refused).check();
      expect(r, LocalNetworkAccess.ok);
    });

    test('nối được một cổng → ổn', () async {
      final r = await _check(
        probe: (p) =>
            p == 443 ? ProbeResult.connected : ProbeResult.unreachable,
      ).check();
      expect(r, LocalNetworkAccess.ok);
    });

    test(
      'mọi cổng "No route to host" + Internet vào được → bị chặn quyền',
      () async {
        final r = await _check(probe: (_) => ProbeResult.unreachable).check();
        expect(r, LocalNetworkAccess.blocked);
      },
    );

    test(
      '"No route to host" nhưng mất Internet → chưa kết luận (mạng hỏng)',
      () async {
        final r = await _check(
          probe: (_) => ProbeResult.unreachable,
          internet: false,
        ).check();
        expect(r, LocalNetworkAccess.unknown);
      },
    );

    test('hết giờ / lỗi khác → chưa kết luận, không báo nhầm', () async {
      final r = await _check(probe: (_) => ProbeResult.timeout).check();
      expect(r, LocalNetworkAccess.unknown);
    });

    test('không biết gateway → chưa kết luận', () async {
      final r = await _check(
        gateway: null,
        probe: (_) => ProbeResult.unreachable,
      ).check();
      expect(r, LocalNetworkAccess.unknown);
    });

    test('đọc gateway từ kết quả route -n get default', () {
      const out = '''
   route to: default
destination: default
       mask: default
    gateway: 192.168.1.1
  interface: en0
''';
      expect(LocalNetworkCheck.parseGateway(out), '192.168.1.1');
      expect(LocalNetworkCheck.parseGateway('không có'), isNull);
    });
  });

  group('LocalNetworkBanner', () {
    Future<void> pump(WidgetTester t, LocalNetworkCheck check) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LocalNetworkBanner(check: check)),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('bị chặn: hiện cảnh báo + nút mở cài đặt / kiểm tra lại', (
      t,
    ) async {
      await pump(t, _check(probe: (_) => ProbeResult.unreachable));
      expect(find.textContaining('Chưa cho phép Agent'), findsOneWidget);
      expect(find.text('Mở cài đặt'), findsOneWidget);
      expect(find.text('Kiểm tra lại'), findsOneWidget);
    });

    testWidgets('mạng thông: không hiện gì', (t) async {
      await pump(t, _check(probe: (_) => ProbeResult.refused));
      expect(find.textContaining('Chưa cho phép Agent'), findsNothing);
    });

    testWidgets('bấm Kiểm tra lại: hết bị chặn thì cảnh báo biến mất', (
      t,
    ) async {
      var blocked = true;
      await pump(
        t,
        _check(
          probe: (_) => blocked ? ProbeResult.unreachable : ProbeResult.refused,
        ),
      );
      expect(find.text('Mở cài đặt'), findsOneWidget);
      blocked = false;
      await t.tap(find.text('Kiểm tra lại'));
      await t.pumpAndSettle();
      expect(find.text('Mở cài đặt'), findsNothing);
    });
  });
}
