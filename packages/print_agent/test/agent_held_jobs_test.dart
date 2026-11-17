import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_gateway.dart';
import 'support/fake_host.dart';
import 'support/fake_job_printer.dart';

void main() {
  late FakeHost host;
  late FakeJobPrinter printer;
  var now = DateTime(2026, 11, 15, 12);

  AgentJobHandler<FakePrinter> handler([FakeJobPrinter? using]) =>
      AgentJobHandler<FakePrinter>(
        watchdog: AgentPrinterWatchdog<FakePrinter>(FakeGateway()),
        printer: using ?? printer,
        heldStore: AgentHeldJobStore(now: () => now),
      );

  PrintRelayJob receipt(String key) => PrintRelayJob(
    kind: PrintRelayJobKind.receipt,
    printer: const PrintRelayPrinter(address: '10.0.0.9', id: 4, name: 'Bếp'),
    images: [
      Uint8List.fromList([1, 2, 3]),
    ],
    key: key,
    beep: true,
  );

  setUp(() {
    host = FakeHost();
    PrintAgentModule.init(host);
    printer = FakeJobPrinter();
    now = DateTime(2026, 11, 15, 12);
    AgentJobHandler.holdRetry = const Duration(milliseconds: 20);
  });

  test('hết giấy rồi app tắt: mở lại in tiếp đúng thứ tự, không đúp', () async {
    // Lần chạy trước: máy in hết giấy suốt (rồi app tắt — bỏ handler cũ).
    final before = FakeJobPrinter()
      ..failuresFirst.addAll(
        List.filled(1000, const AgentPrintFailure(AgentJobError.outOfPaper)),
      );
    final old = handler(before);
    unawaited(old.handle(receipt('a')));
    unawaited(old.handle(receipt('b')));
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(before.printed, isEmpty);

    // Mở lại app, đã thay giấy.
    final fresh = handler();
    expect(await fresh.restoreHeld(), 2);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(printer.printed.map((j) => j.dedupeKey), ['a', 'b']);
    expect(printer.printed.first.printer.name, 'Bếp');
    expect(printer.printed.first.beep, isTrue);
    // Đã lấy ra: lần sau không in lại.
    expect(await handler().restoreHeld(), 0);
  });

  test('in xong thì bỏ khỏi danh sách giữ', () async {
    printer.failuresFirst.add(
      const AgentPrintFailure(AgentJobError.outOfPaper),
    );
    expect(await handler().handle(receipt('c')), isTrue);
    expect(await handler().restoreHeld(), 0);
  });

  test('phiếu giữ quá lâu thì bỏ (phiếu bếp cũ không in ra nữa)', () async {
    final store = AgentHeldJobStore(now: () => now);
    await store.save(receipt('d'));
    now = now.add(AgentHeldJobStore.maxAge + const Duration(minutes: 1));
    expect(await store.takePending(), isEmpty);
  });

  test('theo công ty: công ty khác không in phiếu đang giữ', () async {
    await AgentHeldJobStore(now: () => now).save(receipt('e'));
    host.companyKey = '2';
    expect(await AgentHeldJobStore(now: () => now).takePending(), isEmpty);
    host.companyKey = '1';
    expect(await AgentHeldJobStore(now: () => now).takePending(), hasLength(1));
  });

  test(
    'cúp điện khi nhiều phiếu đang xếp hàng: phiếu đang chờ in lại đủ, phiếu đang in dở thì không',
    () async {
      // Máy in chậm: "a" đang in, "b" "c" xếp hàng chờ — rồi mất điện (bỏ handler cũ).
      final slow = FakeJobPrinter()..delay = const Duration(seconds: 3);
      final old = handler(slow);
      unawaited(old.handle(receipt('a')));
      unawaited(old.handle(receipt('b')));
      unawaited(old.handle(receipt('c')));
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Mở lại: chỉ "b" "c" (chưa in) quay lại; "a" có thể đã ra giấy nên không in lại.
      final fresh = handler();
      expect(await fresh.restoreHeld(), 2);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(printer.printed.map((j) => j.dedupeKey), ['b', 'c']);
    },
  );

  test('lệnh in ngay (không phải chờ): không ghi xuống máy', () async {
    expect(await handler().handle(receipt('f')), isTrue);
    expect(await handler().restoreHeld(), 0);
    final store = AgentHeldJobStore(now: () => now);
    expect(await store.takePending(), isEmpty);
  });

  test(
    'lệnh quá lớn khi phải chờ: không lưu (đỡ ghi đĩa lúc cao điểm)',
    () async {
      final slow = FakeJobPrinter()..delay = const Duration(milliseconds: 300);
      final h = handler(slow);
      final big = PrintRelayJob(
        kind: PrintRelayJobKind.receipt,
        printer: const PrintRelayPrinter(
          address: '10.0.0.9',
          id: 4,
          name: 'Bếp',
        ),
        images: [Uint8List(AgentJobHandler.maxPersistBytes + 1)],
        key: 'big',
      );
      unawaited(h.handle(receipt('x')));
      unawaited(h.handle(big));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(await handler().restoreHeld(), 0);
    },
  );

  PrintRelayJob label(String key) => PrintRelayJob(
    kind: PrintRelayJobKind.label,
    printer: const PrintRelayPrinter(address: '10.0.0.9', id: 4, name: 'Tem'),
    images: [
      Uint8List.fromList([1, 2, 3]),
    ],
    key: key,
  );

  group('nhắc dò lại khe sau khi máy tem có giấy lại', () {
    test('tem hết giấy rồi có giấy: nhắc một lần', () async {
      printer.failuresFirst.add(
        const AgentPrintFailure(AgentJobError.outOfPaper),
      );
      expect(await handler().handle(label('t1')), isTrue);
      expect(host.notices, hasLength(1));
      expect(host.notices.single, contains('Tem'), reason: 'tên máy in');
      expect(host.notices.single, contains('dò lại khe'));
    });

    test('mở nắp rồi đóng: không nhắc (không phải đổi cuộn tem)', () async {
      printer.failuresFirst.add(
        const AgentPrintFailure(AgentJobError.coverOpen),
      );
      expect(await handler().handle(label('t2')), isTrue);
      expect(host.notices, isEmpty);
    });

    test('phiếu hoá đơn hết giấy: không nhắc (không có khe tem)', () async {
      printer.failuresFirst.add(
        const AgentPrintFailure(AgentJobError.outOfPaper),
      );
      expect(await handler().handle(receipt('r1')), isTrue);
      expect(host.notices, isEmpty);
    });

    test('in bình thường không hết giấy: không nhắc', () async {
      expect(await handler().handle(label('t3')), isTrue);
      expect(host.notices, isEmpty);
    });
  });
}
