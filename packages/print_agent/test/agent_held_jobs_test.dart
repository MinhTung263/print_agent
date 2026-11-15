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
}
