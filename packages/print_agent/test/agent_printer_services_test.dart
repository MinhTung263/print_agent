import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_gateway.dart';
import 'support/fake_host.dart';

void main() {
  late FakeHost host;
  late FakeGateway gateway;
  late AgentPrinterWatchdog<FakePrinter> watchdog;

  const kitchen = FakePrinter(
    refId: 3,
    refKind: AgentPrinterKind.lan,
    refAddress: '10.0.0.9',
    refName: 'Bếp',
  );
  const usb = FakePrinter(
    refId: 4,
    refKind: AgentPrinterKind.usb,
    refAddress: 'USB:1',
    refName: 'Tem',
  );

  setUp(() {
    PrintAgentModule.init(host = FakeHost());
    gateway = FakeGateway();
    watchdog = AgentPrinterWatchdog<FakePrinter>(gateway);
  });

  group('AgentPrinterWatchdog', () {
    test(
      'lượt dò đầu: mọi máy in lên sơ đồ CÙNG LÚC (không hiện dần từng máy)',
      () async {
        gateway.printers = [kitchen, usb];
        final sizes = <int>[];
        final sub = watchdog.statuses.listen((l) {
          if (l.isNotEmpty) sizes.add(l.length);
        });
        await watchdog.checkNow();
        await sub.cancel();
        expect(sizes, isNotEmpty);
        expect(
          sizes.first,
          2,
          reason: 'lần cập nhật đầu tiên đã có đủ 2 máy in (đang kiểm tra)',
        );
      },
    );

    test('prune bỏ máy in đã xoá khỏi cài đặt', () {
      gateway.printers = [kitchen, usb];
      watchdog.report(kitchen, AgentPrinterState.connected);
      watchdog.report(usb, AgentPrinterState.disconnected);
      gateway.printers = [usb];
      watchdog.prune();
      expect(watchdog.statuses.map((s) => s.printer), [usb]);
    });

    test('prune bỏ máy in tích hợp khi thiết bị không còn máy in tích hợp', () {
      watchdog.report(gateway.builtInPrinter(), AgentPrinterState.connected);
      watchdog.prune();
      expect(watchdog.statuses, isEmpty);
    });

    test('máy in đổi IP: thay dòng cũ, giữ ghi chú', () {
      const moved = FakePrinter(
        refId: 3,
        refKind: AgentPrinterKind.lan,
        refAddress: '10.0.0.23',
        refName: 'Bếp',
      );
      watchdog.report(kitchen, AgentPrinterState.disconnected);
      watchdog.report(
        moved,
        AgentPrinterState.connected,
        note: '10.0.0.9 → 10.0.0.23',
        replaced: kitchen,
      );
      expect(watchdog.statuses.single.printer, moved);
      expect(watchdog.statuses.single.note, '10.0.0.9 → 10.0.0.23');
    });

    test(
      'rút / cắm lại máy in chính: trạng thái đổi ngay, không chờ lượt 60s',
      () async {
        gateway
          ..hasBuiltIn = true
          ..builtInConnected = true
          ..ready = true;
        watchdog.start();
        addTearDown(watchdog.stop);
        AgentPrinterState? state() => watchdog.statuses
            .where((s) => s.printer.refKind == AgentPrinterKind.builtIn)
            .firstOrNull
            ?.state;
        Future<void> probe() async {
          watchdog.watchClosely(true);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          watchdog.watchClosely(false);
        }

        await probe();
        expect(state(), AgentPrinterState.connected);

        gateway
          ..ready =
              false // rút USB / tắt máy in
          ..builtInComesBack = false;
        await probe();
        expect(state(), AgentPrinterState.disconnected);
        expect(gateway.builtInRestarts, greaterThan(0));

        gateway.ready = true; // cắm lại
        await probe();
        expect(state(), AgentPrinterState.connected);
      },
    );

    test(
      'máy in vừa báo kết nối: lệnh in không hỏi lại (đường nhanh)',
      () async {
        watchdog.report(kitchen, AgentPrinterState.connected);
        gateway.readyChecks = 0;
        expect(await watchdog.waitUntilReady(kitchen), kitchen);
        expect(gateway.readyChecks, 0);
        // allowFresh: false → vẫn hỏi lại đầy đủ.
        expect(
          await watchdog.waitUntilReady(kitchen, allowFresh: false),
          kitchen,
        );
        expect(gateway.readyChecks, 1);
        // Mất kết nối / quên xác nhận: không còn đường nhanh.
        watchdog.forgetFresh(kitchen);
        expect(watchdog.isFresh(kitchen), isFalse);
        watchdog.report(kitchen, AgentPrinterState.disconnected);
        gateway.readyChecks = 0;
        await watchdog.waitUntilReady(kitchen);
        expect(gateway.readyChecks, 1);
      },
    );

    test(
      'đường nhanh phủ hết chu kỳ dò nền (15s) và lệnh in thành công làm mới xác nhận',
      () async {
        // Xác nhận hết hạn trước vòng dò kế tiếp = cứ vài lệnh lại có lệnh chậm 1–4 giây.
        expect(
          AgentPrinterWatchdog.freshFor,
          greaterThan(const Duration(seconds: 15)),
        );
        watchdog.forgetFresh(kitchen);
        expect(watchdog.isFresh(kitchen), isFalse);
        watchdog.markFresh(kitchen);
        expect(watchdog.isFresh(kitchen), isTrue);
        gateway.readyChecks = 0;
        expect(await watchdog.waitUntilReady(kitchen), kitchen);
        expect(gateway.readyChecks, 0);
      },
    );

    test(
      'máy USB rút / cắm lại: trạng thái đổi trong vài trăm ms (dò nhanh), không chờ vòng 3–15s',
      () async {
        AgentPrinterWatchdog.fastProbe = (p) =>
            p.refKind == AgentPrinterKind.usb;
        AgentPrinterWatchdog.fastEvery = const Duration(milliseconds: 60);
        addTearDown(() {
          AgentPrinterWatchdog.fastProbe = null;
          AgentPrinterWatchdog.fastEvery = const Duration(milliseconds: 1500);
          watchdog.stop();
        });
        gateway
          ..printers = [usb]
          ..usbAttached = true;
        watchdog.start();
        AgentPrinterState? state() => watchdog.statuses
            .where((s) => s.printer.refAddress == usb.refAddress)
            .firstOrNull
            ?.state;
        Future<void> settle() =>
            Future<void>.delayed(const Duration(milliseconds: 250));

        await settle();
        expect(state(), AgentPrinterState.connected);
        gateway.usbAttached = false; // rút cáp
        await settle();
        expect(state(), AgentPrinterState.disconnected);
        gateway.usbAttached = true; // cắm lại
        await settle();
        expect(state(), AgentPrinterState.connected);
      },
    );

    test(
      'máy USB Windows cắm sang cổng khác: lệnh in tìm lại theo địa chỉ mới',
      () async {
        const old = FakePrinter(
          refId: 5,
          refKind: AgentPrinterKind.builtIn,
          refAddress: r'usbp:\\?\usb#vid_0483&pid_5740#6&1&0&1#{g}',
          refName: 'Bill',
        );
        const moved = FakePrinter(
          refId: 5,
          refKind: AgentPrinterKind.builtIn,
          refAddress: r'usbp:\\?\usb#vid_0483&pid_5740#6&1&0&2#{g}',
          refName: 'Bill',
        );
        gateway.ready = false;
        gateway.relocated = moved;
        // Địa chỉ mới sẵn sàng ngay khi được tìm thấy.
        gateway.readyFor = {moved.refAddress!};
        final result = await watchdog.waitUntilReady(old);
        expect(result?.refAddress, moved.refAddress);
      },
    );

    test('waitUntilReady trả máy in khi sẵn sàng', () async {
      expect(await watchdog.waitUntilReady(kitchen), kitchen);
      expect(watchdog.statuses.single.state, AgentPrinterState.connected);
    });
  });

  group('AgentPrinterReconnect', () {
    late AgentPrinterReconnect<FakePrinter> reconnect;
    setUp(() => reconnect = AgentPrinterReconnect(gateway, watchdog));

    test('USB chưa cắm → báo rút cáp, sơ đồ mất kết nối', () async {
      final r = await reconnect.run(usb);
      expect(r.outcome, ReconnectOutcome.usbUnplugged);
      expect(watchdog.statuses.single.state, AgentPrinterState.disconnected);
    });

    test('USB cắm sẵn → kết nối', () async {
      gateway.usbAttached = true;
      final r = await reconnect.run(usb);
      expect(r.ok, isTrue);
      expect(watchdog.statuses.single.state, AgentPrinterState.connected);
    });

    test('máy in tích hợp: khởi động lại tối đa 2 lần', () async {
      gateway
        ..hasBuiltIn = true
        ..builtInComesBack = false;
      final r = await reconnect.run(gateway.builtInPrinter());
      expect(r.outcome, ReconnectOutcome.builtInFailed);
      expect(gateway.builtInRestarts, 2);
    });
  });

  group('AgentPrinterRemote', () {
    late List<(String, Map<String, Object?>)> sent;
    late AgentPrinterRemote<FakePrinter> remote;
    setUp(() {
      sent = [];
      remote = AgentPrinterRemote<FakePrinter>(
        watchdog: watchdog,
        sendControl: (id, cmd) async {
          sent.add((id, cmd));
          return true;
        },
        senderName: () => 'Quầy 1',
      );
    });

    test('máy gửi: gửi lệnh kèm tên máy', () async {
      await remote.send(
        stationId: 'a1',
        key: 'id:3',
        on: false,
        printerName: 'Bếp',
      );
      expect(sent.single.$1, 'a1');
      expect(sent.single.$2, {
        'cmd': 'printer',
        'key': 'id:3',
        'on': false,
        'name': 'Bếp',
        'by': 'Quầy 1',
      });
    });

    test('máy Agent: tắt máy in đang quản lý + thông báo', () async {
      watchdog.report(kitchen, AgentPrinterState.connected);
      await remote.apply({
        'key': 'id:3',
        'on': false,
        'by': 'Quầy 1',
        'name': 'Bếp',
      });
      expect(AgentPrinterSwitches.off, contains('id:3'));
      expect(host.notices.single, 'Quầy 1 đã tạm ngưng in Bếp từ máy khác');
      await AgentPrinterSwitches.setKeyOn('id:3', true);
    });

    test('máy Agent: bỏ qua khoá lạ', () async {
      await remote.apply({'key': 'id:99', 'on': false});
      expect(AgentPrinterSwitches.off, isNot(contains('id:99')));
      expect(host.notices, isEmpty);
    });
  });
}
