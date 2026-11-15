// Kịch bản thực tế của Agent máy tính với máy in giả (chạy trên CI Windows /
// Linux): máy in tắt-bật, bận, hết giấy, đổi IP, 2 máy in, chạy liên tục,
// máy gửi → LAN 9101 → Agent → máy in.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/desktop_agent_host.dart';
import 'package:print_agent_desktop/agent/desktop_job_printer.dart';
import 'package:print_agent_desktop/agent/desktop_printer.dart';
import 'package:print_agent_desktop/agent/desktop_printer_gateway.dart';

import 'support/fake_printer_process.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late AgentConfig config;
  late DesktopPrinterGateway gateway;
  late AgentJobHandler<DesktopPrinter> jobs;
  String? macFoundAt;
  final fakes = <FakePrinter>[];

  Future<FakePrinter> fake(int port, {List<String> extra = const []}) async {
    final f = await FakePrinter.start(port, extra: extra);
    fakes.add(f);
    return f;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('agent_scenarios_');
    AgentStore.debugDirectory = dir;
    config = const AgentConfig();
    macFoundAt = null;
    PrintAgentModule.init(DesktopAgentHost(() => config));
    gateway = DesktopPrinterGateway(
      () => config,
      onRelocated: (address) async => config = config.copyWith(
        printer: address,
        printerMac: config.printerMac,
      ),
      findByMac: (mac, port) async => macFoundAt,
    );
    jobs = AgentJobHandler<DesktopPrinter>(
      watchdog: AgentPrinterWatchdog<DesktopPrinter>(gateway),
      printer: DesktopJobPrinter(() => config, gateway),
    );
    AgentJobHandler.holdRetry = const Duration(milliseconds: 200);
    AgentJobHandler.breakerWindow = const Duration(seconds: 1);
    AgentJobHandler.readyTimeout = const Duration(seconds: 4);
  });

  tearDown(() async {
    for (final f in fakes) {
      await f.stop();
    }
    fakes.clear();
    AgentStore.debugDirectory = null;
  });

  Future<PrintRelayJob> toAgentPrinter({void Function()? onHeld}) async {
    final job = PrintRelayJob.receipt(
      printer: const PrintRelayPrinter.stationBuiltIn(stationId: 'me'),
      image: await receiptPng(),
    );
    return onHeld == null ? job : job.withOnHeld(onHeld);
  }

  Future<PrintRelayJob> toLan(String address, {void Function()? onHeld}) async {
    final job = PrintRelayJob.receipt(
      printer: PrintRelayPrinter(address: address),
      image: await receiptPng(),
    );
    return onHeld == null ? job : job.withOnHeld(onHeld);
  }

  test(
    'máy in tắt nguồn rồi bật lại: lỗi khi tắt, in lại được khi bật',
    () async {
      var printer = await fake(19200);
      config = AgentConfig(printer: printer.address);
      expect(await jobs.handle(await toAgentPrinter()), isTrue);

      await printer.stop();
      fakes.remove(printer);
      final sw = Stopwatch()..start();
      // 127.0.0.1 không còn tiến trình nghe = "từ chối" → coi như máy in bận,
      // thử lại vài lần rồi báo lỗi; không treo.
      expect(await jobs.handle(await toAgentPrinter()), isFalse);
      expect(sw.elapsed, lessThan(const Duration(seconds: 15)));

      printer = await fake(19200);
      await Future<void>.delayed(AgentJobHandler.breakerWindow);
      expect(await jobs.handle(await toAgentPrinter()), isTrue);
      await printer.waitTickets(1);
      expect(printer.tickets, 1);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'máy in bận (từ chối kết nối) ~1,5s rồi rảnh: tự thử lại và in được',
    () async {
      final printer = await fake(19201, extra: ['--start-after', '1500']);
      config = AgentConfig(printer: printer.address);
      expect(await jobs.handle(await toAgentPrinter()), isTrue);
      await printer.waitTickets(1);
      expect(printer.tickets, 1);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'hết giấy: giữ phiếu (không gửi dữ liệu), thay giấy xong tự in',
    () async {
      final printer = await fake(19202, extra: ['--paper-out']);
      config = AgentConfig(printer: printer.address);
      var held = 0;
      final result = jobs.handle(await toAgentPrinter(onHeld: () => held++));
      await Future<void>.delayed(const Duration(seconds: 1));
      expect(held, 1);
      expect(printer.tickets, 0);
      printer.command('p'); // thay giấy
      expect(await result.timeout(const Duration(seconds: 20)), isTrue);
      await printer.waitTickets(1);
      expect(printer.tickets, 1);
      expect(printer.sawDataWhileBlocked, isFalse);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    '2 máy in: máy bếp hết giấy không làm kẹt máy quầy',
    () async {
      final kitchen = await fake(19203, extra: ['--paper-out']);
      final bar = await fake(19204);
      final kitchenJob = jobs.handle(await toLan(kitchen.address));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final sw = Stopwatch()..start();
      expect(await jobs.handle(await toLan(bar.address)), isTrue);
      expect(sw.elapsed, lessThan(const Duration(seconds: 5)));
      await bar.waitTickets(1);
      expect(bar.tickets, 1);
      expect(kitchen.tickets, 0);
      kitchen.command('p');
      expect(await kitchenJob.timeout(const Duration(seconds: 20)), isTrue);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'máy in đổi IP: tìm lại theo MAC, in ra IP mới, lưu cấu hình',
    () async {
      final moved = await fake(19205);
      // IP cũ không còn máy nào (không phản hồi) — máy in đã nhận IP mới.
      config = const AgentConfig(
        printer: '10.255.255.1',
        printerMac: '00:47:50:0A:0B:0C',
      );
      macFoundAt = moved.address;
      expect(await jobs.handle(await toAgentPrinter()), isTrue);
      await moved.waitTickets(1);
      expect(moved.tickets, 1);
      expect(config.printer, moved.address);
      expect(config.printerMac, '00:47:50:0A:0B:0C');
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'chạy liên tục 200 phiếu tới 1 máy in: đủ phiếu, đúng thứ tự',
    () async {
      final printer = await fake(19206);
      config = AgentConfig(printer: printer.address);
      final sw = Stopwatch()..start();
      final results = await Future.wait([
        for (var i = 0; i < 200; i++) jobs.handle(await toAgentPrinter()),
      ]);
      final total = sw.elapsedMilliseconds;
      expect(results.every((ok) => ok), isTrue);
      await printer.waitTickets(200, timeout: const Duration(seconds: 60));
      expect(printer.tickets, 200);
      expect(printer.sawDataWhileBlocked, isFalse);
      // ignore: avoid_print
      print('200 phiếu: ${total}ms (~${total ~/ 200}ms/phiếu)');
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test(
    'máy gửi → LAN 9101 → Agent → máy in; gửi trùng chỉ in một lần',
    () async {
      final ips = await PrintRelayLanServer.localIpv4s();
      if (ips.isEmpty) {
        markTestSkipped('Máy không có IP mạng nội bộ');
        return;
      }
      final printer = await fake(19207);
      final server = PrintRelayLanServer(port: 19208);
      final lan = await server.start(
        (job) => PrintRelayStation.lanStatus(job, jobs.handle),
      );
      expect(lan, isNotNull);
      try {
        final job = await toLan(printer.address);
        final first = await PrintRelayLanClient.send(lan!, job);
        expect(first, PrintRelayResult.done);
        // Máy gửi gửi lại CÙNG lệnh (mất phản hồi) → Agent không in lần 2.
        final again = await PrintRelayLanClient.send(lan, job);
        expect(again, PrintRelayResult.done);
        await printer.waitTickets(1);
        await Future<void>.delayed(const Duration(milliseconds: 500));
        expect(printer.tickets, 1);
      } finally {
        await server.stop();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
