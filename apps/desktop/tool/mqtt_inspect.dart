// Xem hàng đợi in MQTT của một cửa hàng (giải mã bằng cùng khoá với app).
//
//   fvm dart run tool/mqtt_inspect.dart <companyId> <companyOwnerId> [env] [--watch]
//
// - Mặc định: liệt kê các máy Agent đang trực tuyến rồi thoát.
// - --watch: theo dõi trực tiếp (Agent bật / tắt, lệnh in, giành lệnh, kết quả)
//   tới khi Ctrl+C.
// - --clear=<mã>: xoá thông tin trực tuyến (retained) của Agent có mã `#<mã>`
//   (VD --clear=6775) hoặc theo phiên; --clear=all: xoá mọi Agent. Agent CÒN CHẠY
//   sẽ tự báo lại khi nối lại / đổi thông tin — muốn gỡ hẳn thì tắt Agent trên
//   máy đó.
// env mặc định Production. companyOwnerId là `companyOwnerId` của cửa hàng (KHÔNG
// phải mã người dùng) — xem trong danh sách cửa hàng khi đăng nhập Agent web.
import 'dart:async';
import 'dart:io';

import 'package:print_agent_desktop/relay/relay_crypto.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

Future<void> main(List<String> args) async {
  final watch = args.contains('--watch');
  final clearArg = args
      .where((a) => a.startsWith('--clear='))
      .map((a) => a.substring('--clear='.length).replaceAll('#', '').trim())
      .firstOrNull;
  final rest = args.where((a) => !a.startsWith('--')).toList();
  if (rest.length < 2) {
    stderr.writeln(
      'Cách dùng: dart run tool/mqtt_inspect.dart <companyId> '
      '<companyOwnerId> [env=Production] [--watch | --clear=<mã>|all]',
    );
    exit(64);
  }
  final env = rest.length > 2 ? rest[2] : 'Production';
  final shopKey = RelayCrypto.shopKey(
    env: env,
    companyId: int.parse(rest[0]),
    ownerId: int.parse(rest[1]),
  );
  final crypto = RelayCrypto(shopKey);
  final root = crypto.topicRoot;
  stdout
    ..writeln('Cửa hàng : $shopKey')
    ..writeln('Topic    : $root/#  (broker.emqx.io:1883)')
    ..writeln('');

  final client =
      MqttServerClient('broker.emqx.io', 'inspect_${RelayCrypto.randomId()}')
        ..logging(on: false)
        ..keepAlivePeriod = 30;
  await client.connect();
  client.subscribe(watch ? '$root/#' : '$root/stations/+', MqttQos.atLeastOnce);

  final stations = <String, Map<Object?, Object?>>{};
  client.updates!.listen((events) {
    for (final e in events) {
      final rel = e.topic.substring(root.length + 1); // stations/x, jobs/x...
      final parts = rel.split('/');
      final kind = parts.first;
      final id = parts.length > 1 ? parts[1] : '';
      final bytes = (e.payload as MqttPublishMessage).payload.message;
      final data = bytes.isEmpty ? null : crypto.decrypt(bytes);
      final at = _now();
      switch (kind) {
        case 'stations':
          if (data is Map) {
            stations[id] = data;
            if (watch)
              stdout.writeln('$at  🟢 Agent trực tuyến  ${_agent(data)}');
          } else {
            final old = stations.remove(id);
            if (watch) {
              stdout.writeln(
                '$at  ⚪ Agent rời mạng   ${old == null ? 'phiên $id' : _agent(old)}',
              );
            }
          }
        case 'jobs':
          if (data is Map) {
            stdout.writeln(
              '$at  🧾 Lệnh ${data['kind']} $id  từ "${data['sender'] ?? '?'}" → '
              '${data['printerName'] ?? ''} (${data['printerType']} '
              '${data['printerIp']})${data['targetStation'] != null ? '  nhắm Agent ${_short(data['targetStation'])}' : ''}',
            );
          }
        case 'claims':
          if (data is Map)
            stdout.writeln('$at     ↳ giành lệnh $id bởi phiên ${data['by']}');
        case 'status':
          stdout.writeln('$at     ↳ lệnh $id: $data');
      }
    }
  });

  if (watch) {
    stdout.writeln('Đang theo dõi… (Ctrl+C để dừng)\n');
    await ProcessSignal.sigint.watch().first;
  } else {
    // Thông tin trạm là retained: broker gửi ngay khi đăng ký.
    await Future<void>.delayed(const Duration(seconds: 4));
    if (stations.isEmpty) {
      stdout.writeln('Không có máy Agent nào trực tuyến trên MQTT.');
    } else {
      stdout.writeln('Máy Agent đang trực tuyến (${stations.length}):');
      for (final e in stations.entries) {
        final s = e.value;
        stdout.writeln('  • ${_agent(s)}');
        stdout.writeln('      topic: $root/stations/${e.key}');
        final printers = s['printers'];
        if (printers is Map && printers['names'] is List) {
          for (final p in printers['names'] as List) {
            if (p is! Map) continue;
            stdout.writeln(
              '      - ${p['name']}  ${p['addr'] ?? p['kind']}  '
              '${p['ok'] == true ? 'kết nối' : 'mất kết nối'}'
              '${p['on'] == false ? ' (đã tắt nhận lệnh)' : ''}',
            );
          }
        }
      }
    }
  }
  if (clearArg != null && clearArg.isNotEmpty) {
    final targets = [
      for (final e in stations.entries)
        if (clearArg == 'all' ||
            e.key == clearArg ||
            (e.value['id']?.toString().toLowerCase() ?? '').endsWith(
              clearArg.toLowerCase(),
            ))
          e,
    ];
    if (targets.isEmpty) {
      stdout.writeln('\nKhông thấy Agent khớp "$clearArg" để xoá.');
    }
    for (final e in targets) {
      // Tin rỗng + retain = broker xoá tin trực tuyến đang giữ.
      client.publishMessage(
        '$root/stations/${e.key}',
        MqttQos.atLeastOnce,
        MqttClientPayloadBuilder().payload!,
        retain: true,
      );
      stdout.writeln('\nĐã xoá: ${_agent(e.value)}');
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  client.disconnect();
  exit(0);
}

String _agent(Map<Object?, Object?> s) {
  final name = (s['name']?.toString() ?? '').trim();
  final at = s['at'] is int
      ? DateTime.fromMillisecondsSinceEpoch(s['at']! as int)
      : null;
  return [
    '${name.isEmpty ? 'Máy Agent' : name} ${_short(s['id'])}',
    if (s['model'] != null) '${s['model']}',
    if (s['app'] != null) '${s['app']}',
    if (s['builtIn'] is Map) 'có máy in tích hợp',
    if (at != null) 'báo lúc ${_time(at)}',
  ].join(' · ');
}

String _short(Object? id) {
  final s = id?.toString() ?? '';
  if (s.isEmpty) return '';
  return '#${(s.length <= 4 ? s : s.substring(s.length - 4)).toUpperCase()}';
}

String _now() => _time(DateTime.now());

String _time(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
    '${t.second.toString().padLeft(2, '0')}';
