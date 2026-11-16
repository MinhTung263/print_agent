@Tags(['network'])
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_core/print_agent_core.dart';

void main() {
  test(
    'MQTT: máy gửi -> trạm in hộ -> done; khoá khác không đọc được',
    () async {
      final secret = 'test-${DateTime.now().microsecondsSinceEpoch}';
      final stationT = MqttPrintRelayTransport(secret: secret);
      final senderT = MqttPrintRelayTransport(secret: secret);
      final spyT = MqttPrintRelayTransport(secret: 'khoa-khac');

      PrintRelayJob? printed;
      final station = PrintRelayStation(
        transport: stationT,
        onJob: (job) async {
          printed = job;
          return true;
        },
      );
      expect(await station.start(), isTrue);

      final spyJobs = <Object?>[];
      final spySub = spyT.watchJobs().listen((j) => spyJobs.add(j.data));

      final client = PrintRelayClient(
        resultTimeout: const Duration(seconds: 15),
      );
      expect(await client.hasOnlineStation(senderT), isTrue);

      final job = PrintRelayJob.receipt(
        printer: const PrintRelayPrinter(address: '192.168.1.143'),
        image: Uint8List.fromList(List.generate(2000, (i) => i % 256)),
        paperSize: 'size80',
      );
      final sw = Stopwatch()..start();
      final result = await client.send(senderT, job);
      // ignore: avoid_print
      print('MQTT relay: $result sau ${sw.elapsedMilliseconds}ms');
      expect(result, PrintRelayResult.done);
      expect(printed?.printer.address, '192.168.1.143');
      expect(printed?.images.first.length, 2000);
      expect(spyJobs, isEmpty);

      await spySub.cancel();
      await station.stop();
      await stationT.dispose();
      await senderT.dispose();
      await spyT.dispose();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'MQTT: máy mở SAU vẫn thấy trạm (hỏi ping, không trông vào tin retained)',
    () async {
      final secret = 'late-${DateTime.now().microsecondsSinceEpoch}';
      final stationT = MqttPrintRelayTransport(secret: secret);
      final station = PrintRelayStation(
        transport: stationT,
        onJob: (_) async => true,
        stationId: 'agent-late',
      );
      expect(await station.start(), isTrue);
      // Trạm đã lên mạng từ lâu; máy gửi mới mở sau.
      await Future<void>.delayed(const Duration(seconds: 2));
      final lateT = MqttPrintRelayTransport(secret: secret);
      final stations = await lateT
          .watchStations()
          .firstWhere((list) => list.isNotEmpty)
          .timeout(const Duration(seconds: 8));
      expect(stations.single['id'], 'agent-late');
      expect(stations.single['at'], isA<int>());

      await station.stop();
      await stationT.dispose();
      await lateT.dispose();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
