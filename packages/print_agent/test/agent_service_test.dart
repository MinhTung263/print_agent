import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_gateway.dart';
import 'support/fake_host.dart';
import 'support/fake_job_printer.dart';

void main() {
  late FakeHost host;
  late FakeGateway gateway;
  late FakeJobPrinter printer;
  late AgentService<FakePrinter> service;

  setUp(() {
    PrintAgentModule.init(host = FakeHost());
    gateway = FakeGateway();
    printer = FakeJobPrinter();
    service = AgentService<FakePrinter>(gateway: gateway, printer: printer);
  });

  PrintRelayJob receipt() => PrintRelayJob.fromMap('j1', {
    'kind': 'receipt',
    'printerIp': '10.0.0.9',
    'printerType': 'lan',
    'printerId': 3,
    'printerName': 'Bếp',
    'sender': 'Quầy 1',
    'image': 'AAAA',
  })!;

  test('mã Agent cố định, lưu lại', () {
    final id = service.stationId;
    expect(id, hasLength(16));
    expect(service.stationId, id);
    expect(host.storage.data['print_station_id'], id);
  });

  test('tên hiển thị: tên đặt → tên thiết bị → model', () async {
    expect(service.displayName, 'SUNMI T1-G');
    host.appDeviceName = 'Quầy bar';
    expect(service.displayName, 'Quầy bar');
    await service.setName(' Bếp chính ');
    expect(service.displayName, 'Bếp chính');
    expect(host.storage.data['print_station_name_1'], 'Bếp chính');
  });

  test('in lệnh được: đếm + ghi nhật ký', () async {
    final ok = await service.jobs.handle(receipt());
    expect(ok, isTrue);
    expect(printer.printed, hasLength(1));
    expect(service.jobs.printed.value, 1);
    final log = AgentJobLogStore.logs.first;
    expect(log.ok, isTrue);
    expect(log.sender, 'Quầy 1');
    expect(log.printerName, 'Bếp');
  });

  test('in lỗi: lý do máy in báo vào nhật ký', () async {
    printer.failure = const AgentPrintFailure(
      AgentJobError.sendFailed,
      detail: 'Gửi lỗi',
    );
    final ok = await service.jobs.handle(receipt());
    expect(ok, isFalse);
    expect(service.jobs.failed.value, 1);
    expect(AgentJobLogStore.logs.first.error, AgentJobError.sendFailed);
    expect(AgentJobLogStore.logs.first.detail, 'Gửi lỗi');
  });

  test(
    'máy in chưa sẵn sàng: không in, ghi lý do',
    () async {
      gateway.ready = false;
      final ok = await service.jobs
          .handle(receipt())
          .timeout(const Duration(seconds: 30));
      expect(ok, isFalse);
      expect(printer.printed, isEmpty);
      expect(AgentJobLogStore.logs.first.ok, isFalse);
    },
    timeout: const Timeout(Duration(seconds: 40)),
  );

  test('máy in tích hợp của Agent khác nhận ra theo địa chỉ ảo', () {
    final peer = PeerBuiltInPrinter(
      stationId: 'agent-9',
      agentName: 'T1-G',
      paper: 'size80',
      templates: const [],
      enabled: true,
      lastSeenAt: DateTime(2026),
    );
    expect(AgentService.isPeerBuiltIn(printer.peerBuiltIn(peer)), isTrue);
    expect(PeerBuiltInPrinter.stationIdOf(peer.address), 'agent-9');
    expect(
      AgentService.isPeerBuiltIn(
        const FakePrinter(refKind: AgentPrinterKind.lan, refAddress: '1.2.3.4'),
      ),
      isFalse,
    );
  });

  test('đồng bộ máy in tích hợp của Agent trực tuyến, giữ bật / tắt', () {
    PeerBuiltInPrinters.sync([
      {
        'id': 'agent-9',
        'name': 'T1-G',
        'builtIn': {'paper': 'size80'},
      },
    ]);
    final p = PeerBuiltInPrinters.items.single;
    expect(p.enabled, isFalse);
    expect(p.templates, ['temporaryPrintForm']);
    PeerBuiltInPrinters.setEnabled('agent-9', true);
    PeerBuiltInPrinters.sync([
      {
        'id': 'agent-9',
        'name': 'T1-G mới',
        'builtIn': {'paper': 'size58'},
      },
    ]);
    expect(PeerBuiltInPrinters.items.single.enabled, isTrue);
    expect(PeerBuiltInPrinters.items.single.paper, 'size58');
    expect(PeerBuiltInPrinters.enabledStationIds(), {'agent-9'});
  });

  test('ảnh rỗng: báo không có nội dung', () async {
    final job = PrintRelayJob(
      kind: PrintRelayJobKind.receipt,
      printer: const PrintRelayPrinter(address: '10.0.0.9'),
      images: <Uint8List>[],
      createdAt: 1,
    );
    expect(await service.jobs.handle(job), isFalse);
    expect(AgentJobLogStore.logs.first.error, AgentJobError.noContent);
  });
}
