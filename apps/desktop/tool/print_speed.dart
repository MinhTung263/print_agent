// Đo tốc độ in qua đường hàng đợi MQTT (giống trang web thử in): gửi vài phiếu nhỏ tới MỘT máy in
// của một Agent đang chạy, đo từng chặng.
//
//   fvm dart run tool/print_speed.dart <companyId> <companyOwnerId> --printer=<IP> [--station=<tên hoặc #mã>]
//                                      [--count=3] [--env=Production] [--mode=all|cloud|lan|web]
//                                      [--height=140]
//
// Ba đường gửi lệnh tới Agent:
//   cloud : qua hàng đợi MQTT trên Internet (như trang web thử in / máy khác mạng)
//   lan   : máy bán hàng cùng mạng gửi thẳng TCP tới Agent (cổng nội bộ, mã `lan` trong thông tin trạm)
//   web   : trang web gọi API nội bộ của Agent `POST /v1/print` (cổng 9102) — qua 127.0.0.1 và qua IP mạng
//
// Mỗi lần gửi IN RA GIẤY một phiếu nhỏ (~2cm) — chọn máy in đang bật. Chặng đo:
//   gửi    : từ lúc publish tới khi broker nhận (PUBACK)
//   nhận   : tới khi Agent báo "printing" (Agent đã nhận, giải mã, kiểm tra máy in)
//   in xong: tới khi Agent báo "done"
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'relay_crypto.dart';

Future<void> main(List<String> args) async {
  String? opt(String name) => args
      .where((a) => a.startsWith('--$name='))
      .map((a) => a.substring(name.length + 3))
      .firstOrNull;
  final rest = args.where((a) => !a.startsWith('--')).toList();
  final printer = opt('printer');
  if (rest.length < 2 || printer == null) {
    stderr.writeln(
      'Cách dùng: dart run tool/print_speed.dart <companyId> <ownerId> '
      '--printer=<IP> [--station=<tên|#mã>] [--count=3] [--env=Production]',
    );
    exit(64);
  }
  final count = int.tryParse(opt('count') ?? '') ?? 3;
  final crypto = RelayCrypto(
    RelayCrypto.shopKey(
      env: opt('env') ?? 'Production',
      companyId: int.parse(rest[0]),
      ownerId: int.parse(rest[1]),
    ),
  );
  final root = crypto.topicRoot;

  final client =
      MqttServerClient('broker.emqx.io', 'speed_${RelayCrypto.randomId()}')
        ..logging(on: false)
        ..keepAlivePeriod = 30;
  await client.connect();

  final stations = <String, Map<Object?, Object?>>{};
  final status = <String, StreamController<(String, int)>>{};
  final t0 = Stopwatch()..start();
  client.updates!.listen((events) {
    for (final e in events) {
      final rel = e.topic.substring(root.length + 1).split('/');
      final bytes = (e.payload as MqttPublishMessage).payload.message;
      final data = bytes.isEmpty ? null : crypto.decrypt(bytes);
      if (rel.first == 'stations' && data is Map) {
        stations[rel[1]] = data;
      } else if (rel.first == 'status' &&
          rel.length > 1 &&
          data is String &&
          status.containsKey(rel[1])) {
        status[rel[1]]!.add((data, t0.elapsedMilliseconds));
      }
    }
  });
  // Đăng ký MỘT lần cho mọi lệnh (như trang web): đỡ một vòng chờ mạng mỗi lần gửi.
  client.subscribe('$root/stations/+', MqttQos.atLeastOnce);
  client.subscribe('$root/status/+', MqttQos.atLeastOnce);
  await Future<void>.delayed(const Duration(seconds: 2));

  final want = (opt('station') ?? '').toLowerCase().replaceAll('#', '');
  final live = stations.values.where((s) {
    final at = s['at'];
    return at is! num || DateTime.now().millisecondsSinceEpoch - at < 150000;
  }).toList();
  final station = live.where((s) {
    if (want.isEmpty) return true;
    final name = '${s['name']}'.toLowerCase();
    final id = '${s['id']}'.toLowerCase();
    return name.contains(want) || id.endsWith(want);
  }).toList();
  if (station.isEmpty) {
    stderr.writeln(
      'Không thấy Agent nào${want.isEmpty ? '' : ' khớp "$want"'} đang trực tuyến '
      '(thấy ${live.map((s) => s['name']).join(', ')}).',
    );
    exit(1);
  }
  final target = station.first;
  stdout.writeln(
    'Agent: ${target['name']} (${target['id']}) · máy in $printer · $count lần\n',
  );

  final image = _png1bit(384, int.tryParse(opt('height') ?? '') ?? 140);
  final mode = opt('mode') ?? 'all';
  final summary = <String, List<int>>{};

  Map<String, Object?> receiptJob() => {
    'kind': 'receipt',
    'status': 'pending',
    'createdAt': DateTime.now().millisecondsSinceEpoch,
    'printerId': null,
    'printerIp': printer,
    'printerType': 'lan',
    'targetStation': target['id'],
    'printerName': null,
    'sender': 'Do toc do',
    'key': RelayCrypto.randomId(),
    'size': 'size80',
    'quantity': 1,
    'openDrawer': false,
    'image': image,
  };

  // ---- cloud: hàng đợi MQTT ----
  Future<void> runCloud() async {
    stdout.writeln('== CLOUD (qua broker MQTT trên Internet) ==');
    final times = summary['cloud'] = [];
    for (var i = 1; i <= count; i++) {
      final id = RelayCrypto.randomId();
      final ctl = status[id] = StreamController<(String, int)>.broadcast();
      final seen = <String, int>{};
      ctl.stream.listen((e) => seen[e.$1] = e.$2);
      final start = t0.elapsedMilliseconds;
      final body = crypto.encrypt(receiptJob());
      final payload = MqttClientPayloadBuilder()..addUTF8String(body);
      client.publishMessage(
        '$root/jobs/$id',
        MqttQos.atLeastOnce,
        payload.payload!,
      );
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (!(seen.containsKey('done') ||
              seen.containsKey('failed') ||
              seen.containsKey('held')) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final printing = seen['printing'];
      final end = seen['done'] ?? seen['failed'] ?? seen['held'];
      stdout.writeln(
        '  Lần $i (${(body.length / 1024).toStringAsFixed(1)}KB): '
        'Agent nhận ${printing == null ? '-' : '${printing - start}ms'} · '
        'in xong ${end == null ? '-' : '${end - start}ms'}  '
        '[${seen.containsKey('done') ? 'done' : (seen.keys.isEmpty ? 'không phản hồi' : seen.keys.last)}]',
      );
      if (seen.containsKey('done')) times.add(end! - start);
      await ctl.close();
      status.remove(id);
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  // ---- lan: TCP thẳng tới Agent trong mạng nội bộ ----
  Future<void> runLan() async {
    stdout.writeln(
      '== LAN (máy bán hàng cùng mạng gửi thẳng TCP tới Agent) ==',
    );
    final lan = target['lan'];
    if (lan is! Map || lan['token'] is! String || lan['port'] is! int) {
      stdout.writeln('  Agent chưa báo thông tin cổng nội bộ — bỏ qua.\n');
      return;
    }
    final mine = <String>{
      for (final n in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      ))
        for (final a in n.addresses) a.address.split('.').take(3).join('.'),
    };
    final ip = [
      for (final x in lan['ips'] as List)
        if (mine.contains('$x'.split('.').take(3).join('.'))) '$x',
    ].firstOrNull;
    if (ip == null) {
      stdout.writeln(
        '  Không có IP của Agent cùng dải mạng với máy này — bỏ qua.\n',
      );
      return;
    }
    final times = summary['lan'] = [];
    for (var i = 1; i <= count; i++) {
      final sw = Stopwatch()..start();
      try {
        final socket = await Socket.connect(
          ip,
          lan['port'] as int,
          timeout: const Duration(seconds: 3),
        );
        final connected = sw.elapsedMilliseconds;
        final line =
            '${jsonEncode({'token': lan['token'], 'job': receiptJob()})}\n';
        socket.write(line);
        await socket.flush();
        final reply = await utf8
            .decodeStream(socket)
            .timeout(const Duration(seconds: 30));
        socket.destroy();
        final status = (jsonDecode(reply.trim()) as Map)['status'];
        stdout.writeln(
          '  Lần $i (${(line.length / 1024).toStringAsFixed(1)}KB): nối ${connected}ms · '
          'in xong ${sw.elapsedMilliseconds}ms  [$status]',
        );
        if (status == 'done') times.add(sw.elapsedMilliseconds);
      } catch (e) {
        stdout.writeln('  Lần $i: lỗi $e');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  // ---- web: API nội bộ của Agent (cổng 9102) ----
  Future<void> runWeb(String host, String label) async {
    stdout.writeln(
      '== WEB → API Agent ($label: http://$host:9102/v1/print) ==',
    );
    final times = summary['web $label'] = [];
    final http = HttpClient();
    for (var i = 1; i <= count; i++) {
      final sw = Stopwatch()..start();
      try {
        final req = await http.postUrl(Uri.parse('http://$host:9102/v1/print'));
        req.headers.contentType = ContentType.json;
        // Yêu cầu từ thiết bị khác bắt buộc có Origin của trang EasyPOS (như trình duyệt thật gửi).
        req.headers.set('Origin', 'https://app.easypos.vn');
        final body = jsonEncode({
          'jobId': 'speed-${RelayCrypto.randomId()}',
          'image': image,
          'printer': 'lan:$printer',
          'paper': 'size80',
          'sender': 'Do toc do',
        });
        req.write(body);
        final res = await req.close().timeout(const Duration(seconds: 30));
        final text = await utf8.decodeStream(res);
        final status = (jsonDecode(text) as Map)['status'];
        stdout.writeln(
          '  Lần $i (${(body.length / 1024).toStringAsFixed(1)}KB): in xong ${sw.elapsedMilliseconds}ms  [$status]',
        );
        if (status == 'done') times.add(sw.elapsedMilliseconds);
      } catch (e) {
        stdout.writeln('  Lần $i: lỗi $e');
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    http.close();
  }

  if (mode == 'all' || mode == 'cloud') await runCloud();
  if (mode == 'all' || mode == 'lan') await runLan();
  if (mode == 'all' || mode == 'web') {
    await runWeb('127.0.0.1', 'cùng máy');
    final ip = (await NetworkInterface.list(type: InternetAddressType.IPv4))
        .expand((n) => n.addresses)
        .map((a) => a.address)
        .where((a) => !a.startsWith('127.') && !a.startsWith('169.254.'))
        .firstOrNull;
    if (ip != null) await runWeb(ip, 'qua IP mạng $ip');
  }

  stdout.writeln('\n== TỔNG KẾT (gửi → in xong, các lần "done") ==');
  summary.forEach((k, v) {
    if (v.isEmpty) {
      stdout.writeln('  $k: không có lần nào thành công');
    } else {
      final sorted = [...v]..sort();
      stdout.writeln(
        '  ${k.padRight(34)} nhanh nhất ${sorted.first}ms · trung vị ${sorted[sorted.length ~/ 2]}ms · chậm nhất ${sorted.last}ms',
      );
    }
  });
  client.disconnect();
  exit(0);
}

/// PNG 1 bit/điểm (xám): các vạch ngang để nhìn thấy phiếu.
String _png1bit(int w, int h) {
  final rb = (w + 7) >> 3;
  final raw = Uint8List((rb + 1) * h);
  for (var y = 0; y < h; y++) {
    final o = y * (rb + 1);
    for (var i = 0; i < rb; i++) {
      raw[o + 1 + i] = 255;
    }
    final black =
        y < 4 || y >= h - 4 || (y ~/ 14).isEven && y > 20 && y < h - 20;
    if (black) {
      for (var x = 16; x < w - 16; x++) {
        raw[o + 1 + (x >> 3)] &= ~(0x80 >> (x & 7));
      }
    }
  }
  final out = BytesBuilder()..add([137, 80, 78, 71, 13, 10, 26, 10]);
  void chunk(String type, List<int> data) {
    out.add((ByteData(4)..setUint32(0, data.length)).buffer.asUint8List());
    final body = [...type.codeUnits, ...data];
    out
      ..add(body)
      ..add((ByteData(4)..setUint32(0, _crc32(body))).buffer.asUint8List());
  }

  chunk(
    'IHDR',
    (ByteData(13)
          ..setUint32(0, w)
          ..setUint32(4, h)
          ..setUint8(8, 1)
          ..setUint8(9, 0))
        .buffer
        .asUint8List(),
  );
  chunk('IDAT', ZLibEncoder().convert(raw));
  chunk('IEND', const []);
  return base64Encode(out.toBytes());
}

int _crc32(List<int> b) {
  var c = 0xFFFFFFFF;
  for (final v in b) {
    c ^= v;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
