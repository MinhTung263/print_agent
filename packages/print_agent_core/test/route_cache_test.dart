import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_core/print_agent_core.dart';

class _Transport implements PrintRelayTransport {
  final _status = <String, StreamController<String?>>{};
  var _seq = 0;

  @override
  Stream<List<Map<Object?, Object?>>> watchStations() => Stream.value([
    {
      'id': 'agent-1',
      'name': 'PC',
      'lan': {'token': 't', 'port': 9101, 'ips': <String>[]},
    },
  ]);
  @override
  Future<String> submitJob(Map<String, Object?> data) async {
    final id = 'job${_seq++}';
    final c = _status[id] = StreamController<String?>.broadcast();
    Timer(const Duration(milliseconds: 20), () {
      c.add(PrintRelayStatus.printing);
      Timer(
        const Duration(milliseconds: 20),
        () => c.add(PrintRelayStatus.done),
      );
    });
    return id;
  }

  @override
  Stream<String?> watchJobStatus(String id) => _status[id]!.stream;
  @override
  Future<bool> removeStation(Map<Object?, Object?> station) async => false;
  @override
  Future<void> deleteJob(String id) async {}
  @override
  Future<void> ackJob(String id) async {}
  @override
  Future<void> holdJob(String id) async {}
  @override
  Future<bool> claimJob(String id) async => true;
  @override
  Future<void> completeJob(String id, {required bool success}) async {}
  @override
  Future<void> goOffline() async {}
  @override
  Future<void> goOnline(Map<String, Object?> info) async {}
  @override
  Stream<PrintRelayQueuedJob> watchJobs() => const Stream.empty();
  @override
  Stream<bool> watchConnection() => Stream.value(true);
}

/// Chờ tới khi [cond] đúng (tối đa 3s) — việc ghi nhớ đường chạy bất đồng bộ nên không
/// dùng độ trễ cố định (máy chậm / đang chạy nhiều bộ test thì lệch).
Future<void> _until(Future<bool> Function() cond) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (DateTime.now().isBefore(end) && !await cond()) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  test(
    'Smart Route Cache: in thẳng lỗi, qua Agent được → lần sau đi Agent luôn',
    () async {
      final mine = await PrintRelayLanServer.localIpv4s();
      if (mine.isEmpty) return; // không có mạng để dựng máy in "cùng dải"
      final prefix = mine.first.split('.').take(3).join('.');
      // Máy in cùng dải IP (in thẳng được theo suy đoán) — chưa nhớ gì thì không qua Agent.
      final printer = PrintRelayPrinter(address: '$prefix.250');
      final transport = _Transport();
      final relay = PrintRelay(
        queues: () async => [transport],
        onJob: (_) async => true,
      );
      PrintRelayJob job() => PrintRelayJob.receipt(
        printer: printer,
        image: Uint8List.fromList([1]),
        paperSize: 'size80',
      );

      expect(await relay.willRelay(printer), isFalse);
      expect(
        await relay.relay(printer, job, force: true),
        PrintRelayResult.done,
      );
      await _until(() => relay.willRelay(printer));
      expect(
        await relay.willRelay(printer),
        isTrue,
        reason: 'đã nhớ đường qua Agent',
      );

      relay.forgetRoute(printer);
      expect(await relay.willRelay(printer), isFalse);

      // Hết hạn thì tự quên.
      final saved = PrintRelay.routeCacheTtl;
      PrintRelay.routeCacheTtl = Duration.zero;
      addTearDown(() => PrintRelay.routeCacheTtl = saved);
      await relay.relay(printer, job, force: true);
      await Future<void>.delayed(
        const Duration(milliseconds: 100),
      ); // TTL 0: hết hạn ngay
      expect(await relay.willRelay(printer), isFalse);
    },
  );
}
