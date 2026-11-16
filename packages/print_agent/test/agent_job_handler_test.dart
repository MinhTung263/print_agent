import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_gateway.dart';
import 'support/fake_host.dart';
import 'support/fake_job_printer.dart';

void main() {
  late FakeJobPrinter printer;
  late AgentJobHandler<FakePrinter> jobs;

  setUp(() {
    PrintAgentModule.init(FakeHost());
    printer = FakeJobPrinter();
    jobs = AgentJobHandler<FakePrinter>(
      watchdog: AgentPrinterWatchdog<FakePrinter>(FakeGateway()),
      printer: printer,
    );
    AgentJobHandler.holdRetry = const Duration(milliseconds: 10);
  });

  PrintRelayJob receipt(String ip, {String? key, void Function()? onHeld}) {
    final job = PrintRelayJob(
      kind: PrintRelayJobKind.receipt,
      printer: PrintRelayPrinter(address: ip),
      images: [
        Uint8List.fromList([1]),
      ],
      key: key ?? PrintRelayJob.newKey(),
    );
    return onHeld == null ? job : job.withOnHeld(onHeld);
  }

  test('cùng mã lệnh tới 2 lần (LAN rồi MQTT): chỉ in một lần', () async {
    final a = jobs.handle(receipt('10.0.0.9', key: 'k1'));
    final b = jobs.handle(receipt('10.0.0.9', key: 'k1'));
    expect(await a, isTrue);
    expect(await b, isTrue);
    expect(printer.printed, hasLength(1));
  });

  test(
    'đường nhanh: máy in vừa khoẻ → in ngay không hỏi lại; in lỗi "không kết nối" → hỏi đầy đủ rồi in lại một lần',
    () async {
      final gateway = FakeGateway();
      final dog = AgentPrinterWatchdog<FakePrinter>(gateway);
      final handler = AgentJobHandler<FakePrinter>(
        watchdog: dog,
        printer: printer,
      );
      const lan = FakePrinter(
        refKind: AgentPrinterKind.lan,
        refAddress: '10.0.0.9',
        refName: 'Bếp',
      );
      dog.report(lan, AgentPrinterState.connected);
      gateway.readyChecks = 0;
      expect(await handler.handle(receipt('10.0.0.9', key: 'fast')), isTrue);
      expect(gateway.readyChecks, 0, reason: 'vừa khoẻ → không hỏi lại');
      expect(printer.printed, hasLength(1));

      // Thực tế máy mất: lần in đầu báo không kết nối → hỏi đầy đủ rồi in lại đúng một lần.
      dog.report(lan, AgentPrinterState.connected);
      printer.failuresFirst.add(
        const AgentPrintFailure(AgentJobError.unreachable),
      );
      expect(await handler.handle(receipt('10.0.0.9', key: 'retry')), isTrue);
      expect(gateway.readyChecks, 1);
      expect(printer.printed.map((j) => j.key), ['fast', 'retry']);

      // Đã gửi rồi mà "không phản hồi": KHÔNG in lại (tránh hai bản).
      dog.report(lan, AgentPrinterState.connected);
      printer.failuresFirst.add(
        const AgentPrintFailure(AgentJobError.notReady),
      );
      expect(
        await handler.handle(receipt('10.0.0.9', key: 'noretry')),
        isFalse,
      );
      expect(printer.printed.map((j) => j.key), ['fast', 'retry']);
    },
  );

  test('hết giấy: giữ lệnh, báo held, thay giấy xong tự in', () async {
    printer.failuresFirst.addAll(const [
      AgentPrintFailure(AgentJobError.outOfPaper),
      AgentPrintFailure(AgentJobError.outOfPaper),
    ]);
    var held = 0;
    final ok = await jobs.handle(receipt('10.0.0.9', onHeld: () => held++));
    expect(ok, isTrue);
    expect(held, 1);
    expect(printer.printed, hasLength(1));
  });

  test('cùng máy in: lệnh ra đúng thứ tự gửi (FIFO)', () async {
    printer.delay = const Duration(milliseconds: 20);
    final first = receipt('10.0.0.9', key: 'first');
    final second = receipt('10.0.0.9', key: 'second');
    await Future.wait([jobs.handle(first), jobs.handle(second)]);
    expect(printer.printed.map((j) => j.key), ['first', 'second']);
  });

  test('máy in khác không chờ máy in đang giữ lệnh', () async {
    printer.failuresFirst.addAll(
      List.filled(5, const AgentPrintFailure(AgentJobError.coverOpen)),
    );
    final kitchen = jobs.handle(receipt('10.0.0.9', key: 'bep'));
    await Future<void>.delayed(const Duration(milliseconds: 5));
    final bar = await jobs.handle(receipt('10.0.0.20', key: 'bar'));
    expect(bar, isTrue);
    expect(printer.printed.first.key, 'bar');
    expect(await kitchen, isTrue);
  });
}
