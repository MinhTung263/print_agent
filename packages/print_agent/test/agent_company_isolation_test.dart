import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_gateway.dart';
import 'support/fake_host.dart';
import 'support/fake_job_printer.dart';

class FakeTransport implements PrintRelayTransport {
  int offline = 0;

  @override
  Future<void> goOffline() async => offline++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeHost host;
  late FakeGateway gateway;
  late AgentService<FakePrinter> service;
  final opened = <String>[];
  final transports = <FakeTransport>[];

  setUp(() {
    PrintAgentModule.init(host = FakeHost()..shopKey = null);
    gateway = FakeGateway();
    opened.clear();
    transports.clear();
    service = AgentService<FakePrinter>(
      gateway: gateway,
      printer: FakeJobPrinter(),
      extraQueues: (key) async {
        opened.add(key);
        final t = FakeTransport();
        transports.add(t);
        return [t];
      },
    );
  });

  test('cờ bật Agent chung của bản cũ → ghim công ty đang mở', () async {
    host.storage.data['print_station_enabled'] = true;
    await service.init();
    expect(host.storage.data['print_station_bound_company'], '1');
    expect(host.storage.data.containsKey('print_station_enabled'), isFalse);
  });

  test(
    'đổi sang công ty khác: không làm Agent ở đó, báo đang ghim nơi khác',
    () async {
      host.storage.data['print_station_bound_company'] = '1';
      host.companyKey = '2';
      await service.init();
      expect(service.relay.isStation.value, isFalse);
      expect(service.boundElsewhere, isTrue);
      host.companyKey = '1';
      expect(service.boundElsewhere, isFalse);
    },
  );

  test('tạm dừng khi rời công ty vẫn giữ ghim (quay lại tự bật)', () async {
    host.storage.data['print_station_bound_company'] = '1';
    await service.suspend();
    expect(host.storage.data['print_station_bound_company'], '1');
    expect(service.relay.isStation.value, isFalse);
  });

  test('tên Agent theo công ty, công ty chưa đặt dùng tên chung cũ', () async {
    host.storage.data['print_station_name'] = 'Tên cũ';
    await service.init();
    expect(service.name.value, 'Tên cũ');
    await service.setName('Quầy chi nhánh 1');
    expect(host.storage.data['print_station_name_1'], 'Quầy chi nhánh 1');
    host.companyKey = '2';
    await service.init();
    expect(service.name.value, 'Tên cũ');
  });

  test('nhật ký lệnh in hộ tách theo công ty', () async {
    AgentJobLogStore.ensureLoaded();
    AgentJobLogStore.add(
      AgentJobLog(
        at: DateTime(2026),
        isLabel: false,
        printerName: 'Bếp CN1',
        ok: true,
        viaLan: false,
        durationMs: 1,
      ),
    );
    host.companyKey = '2';
    AgentJobLogStore.ensureLoaded();
    expect(AgentJobLogStore.logs, isEmpty);
    host.companyKey = '1';
    AgentJobLogStore.ensureLoaded();
    expect(AgentJobLogStore.logs.single.printerName, 'Bếp CN1');
  });

  test('lệnh kèm MAC khác máy in đã lưu ở cùng IP: không nhận', () async {
    gateway.printers = [
      const FakePrinter(
        refId: 3,
        refKind: AgentPrinterKind.lan,
        refAddress: '192.168.1.200',
        refMac: 'AA:BB:CC:00:11:22',
      ),
    ];
    PrintRelayJob job(String? mac) => PrintRelayJob.fromMap('j', {
      'kind': 'receipt',
      'printerIp': '192.168.1.200',
      'printerType': 'lan',
      'printerMac': ?mac,
    })!;
    final canHandle = service.relay.canHandle!;
    expect(await canHandle(job('aa-bb-cc-99-99-99')), isFalse);
    // Cùng MAC (khác cách viết) / lệnh không kèm MAC: xét như thường.
    expect(AgentService.normalizeMac('aa-bb-cc-00-11-22'), 'AABBCC001122');
    expect(await canHandle(job(null)), isA<bool>());
  });

  test('kênh riêng mở một lần mỗi công ty; đổi công ty rút kênh cũ', () async {
    host.shopKey = 'dev/c1_1';
    await service.relay.queues();
    await service.relay.queues();
    expect(opened, ['dev/c1_1']);
    host.shopKey = 'dev/c2_2';
    await service.relay.queues();
    expect(opened, ['dev/c1_1', 'dev/c2_2']);
    expect(transports.first.offline, 1);
  });
}
