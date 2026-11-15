import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_gateway.dart';
import 'support/fake_host.dart';
import 'support/fake_job_printer.dart';

int _pngWidth(Uint8List png) => ByteData.sublistView(png, 16, 20).getUint32(0);

void main() {
  late FakeJobPrinter printer;
  late AgentService<FakePrinter> service;

  setUp(() {
    PrintAgentModule.init(FakeHost());
    printer = FakeJobPrinter();
    service = AgentService<FakePrinter>(
      gateway: FakeGateway(),
      printer: printer,
    );
  });

  final lan = FakePrinter(
    refId: 3,
    refKind: AgentPrinterKind.lan,
    refAddress: '10.0.0.9',
    refName: 'Bếp',
  );

  testWidgets('in thử máy in của máy này: phiếu ảnh ghi tên máy in', (t) async {
    await t.runAsync(() async {
      final r = await service.testPrint.local(lan);
      expect(r, AgentTestPrintResult.done);
      expect(printer.printed, hasLength(1));
      final job = printer.printed.single;
      expect(job.printer.address, '10.0.0.9');
      expect(job.dedupeKey, startsWith('test:'));
      expect(job.paperSize, 'size80');
      expect(job.images.single.take(4), [0x89, 0x50, 0x4E, 0x47]);
      expect(_pngWidth(job.images.single), 576);
    });
  });

  testWidgets('mỗi lần bấm là một phiếu mới (không bị coi là lệnh trùng)', (
    t,
  ) async {
    await t.runAsync(() async {
      await service.testPrint.local(lan);
      await service.testPrint.local(lan);
      expect(printer.printed, hasLength(2));
    });
  });

  testWidgets('máy in lỗi → failed', (t) async {
    await t.runAsync(() async {
      printer.failure = const AgentPrintFailure(AgentJobError.notReady);
      expect(await service.testPrint.local(lan), AgentTestPrintResult.failed);
    });
  });

  testWidgets('in thử máy in của Agent khác không có mã trạm → offline', (
    t,
  ) async {
    await t.runAsync(() async {
      final r = await service.testPrint.peer(
        const {'name': 'Quầy'},
        const {'name': 'Bếp', 'kind': 'lan', 'addr': '10.0.0.9'},
      );
      expect(r, AgentTestPrintResult.offline);
    });
  });
}
