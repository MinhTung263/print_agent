import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:print_agent/print_agent.dart';

class _FakePort implements WebPrintPort {
  final requests = <WebPrintRequest>[];
  WebPrintResult result = const WebPrintResult(WebPrintStatus.done);

  @override
  Map<String, Object?> info() => {'app': 'easypos-print-agent', 'api': 1};

  @override
  Future<WebPrintResult> print(WebPrintRequest request) async {
    requests.add(request);
    return result;
  }
}

String _png({int width = 10, int height = 4}) => base64Encode(
  img.encodePng(img.Image(width: width, height: height, numChannels: 4)),
);

void main() {
  group('WebOriginPolicy', () {
    const policy = WebOriginPolicy();

    test('chỉ nhận trang EasyPOS qua https', () {
      expect(policy.allows('https://app.easypos.vn'), isTrue);
      expect(policy.allows('https://easypos.vn'), isTrue);
      expect(policy.allows('http://app.easypos.vn'), isFalse);
      expect(policy.allows('https://easypos.vn.evil.com'), isFalse);
      expect(policy.allows('https://notEasypos.vn'), isFalse);
      expect(policy.allows(null), isTrue, reason: 'không phải trình duyệt');
    });

    test('thêm trang thử nghiệm qua cấu hình', () {
      final p = WebOriginPolicy.parse(' http://localhost:4200/ , ');
      expect(p.allows('http://localhost:4200'), isTrue);
      expect(p.allows('http://localhost:5000'), isFalse);
    });
  });

  group('WebOriginPolicy.allowLocalHttp', () {
    test('mặc định (bản thật) không nhận trang http', () {
      const p = WebOriginPolicy();
      expect(p.allows('http://192.168.1.20:8080'), isFalse);
      expect(p.allows('http://localhost:8080'), isFalse);
    });

    test('bản debug nhận http ở localhost / mạng nội bộ, không nhận ngoài', () {
      const p = WebOriginPolicy(allowLocalHttp: true);
      expect(p.allows('http://192.168.1.20:8080'), isTrue);
      expect(p.allows('http://10.0.0.5'), isTrue);
      expect(p.allows('http://172.20.1.1:3000'), isTrue);
      expect(p.allows('http://localhost:4200'), isTrue);
      expect(p.allows('http://8.8.8.8'), isFalse);
      expect(p.allows('http://evil.com'), isFalse);
      expect(p.allows('https://app.easypos.vn'), isTrue);
    });
  });

  group('WebPrintRequest', () {
    test('đọc đủ trường, nhận data URL', () {
      final r = WebPrintRequest.parse({
        'jobId': 'HD001-1',
        'image': 'data:image/png;base64,${_png()}',
        'printer': 'lan:192.168.1.50:9100',
        'paper': 'size58',
        'copies': 2,
        'openDrawer': true,
        'companyId': '12',
      });
      expect(r.target.lanAddress, '192.168.1.50:9100');
      expect(r.paper, 'size58');
      expect(r.copies, 2);
      expect(r.openDrawer, isTrue);
      expect(r.companyId, 12);
      expect(r.image, isNotEmpty);
    });

    test('mặc định máy in của trạm in', () {
      final r = WebPrintRequest.parse({'jobId': 'a', 'image': _png()});
      expect(r.target.isBuiltIn, isTrue);
      expect(r.copies, 1);
    });

    test('từ chối dữ liệu sai', () {
      Matcher code(String c) =>
          throwsA(isA<WebRequestError>().having((e) => e.code, 'code', c));
      expect(() => WebPrintRequest.parse({'image': _png()}), code('badJobId'));
      expect(() => WebPrintRequest.parse({'jobId': 'a'}), code('noImage'));
      expect(
        () => WebPrintRequest.parse({'jobId': 'a', 'image': '%%%'}),
        code('badImage'),
      );
      expect(
        () => WebPrintRequest.parse({
          'jobId': 'a',
          'image': _png(),
          'printer': 'lan:8.8.8.8',
        }),
        code('badPrinter'),
      );
      expect(
        () => WebPrintRequest.parse({
          'jobId': 'a',
          'image': _png(),
          'copies': 99,
        }),
        code('badCopies'),
      );
    });

    test('chỉ máy in LAN trong mạng nội bộ', () {
      expect(WebPrintTarget.isPrivateAddress('10.0.0.5'), isTrue);
      expect(WebPrintTarget.isPrivateAddress('172.20.1.1'), isTrue);
      expect(WebPrintTarget.isPrivateAddress('172.32.1.1'), isFalse);
      expect(WebPrintTarget.isPrivateAddress('192.168.1.5:99999'), isFalse);
      expect(WebPrintTarget.isPrivateAddress('127.0.0.1'), isFalse);
    });
  });

  group('WebReceiptImage', () {
    test('thu về đúng khổ, nền trong suốt thành trắng', () {
      final src = img.Image(width: 800, height: 100, numChannels: 4);
      final out = img.decodePng(
        WebReceiptImage.fitSync(img.encodePng(src), 576),
      )!;
      expect(out.width, 576);
      final px = out.getPixel(10, 10);
      expect([px.r, px.g, px.b], [255, 255, 255]);
    });

    test('ảnh hẹp giữ nguyên bề rộng; ảnh hỏng báo lỗi', () {
      final src = img.Image(width: 300, height: 50);
      final out = img.decodePng(
        WebReceiptImage.fitSync(img.encodePng(src), 576),
      )!;
      expect(out.width, 300);
      expect(
        () => WebReceiptImage.fitSync(Uint8List.fromList([1, 2, 3]), 576),
        throwsFormatException,
      );
    });
  });

  group('WebBridgeServer', () {
    late _FakePort port;
    late WebBridgeServer server;
    late HttpClient client;
    late int listening;

    setUp(() async {
      port = _FakePort();
      server = WebBridgeServer(port, ports: const [0]);
      listening = (await server.start())!;
      client = HttpClient();
    });

    tearDown(() async {
      client.close(force: true);
      await server.stop();
    });

    Future<(int, Map<String, Object?>, HttpHeaders)> send(
      String method,
      String path, {
      String? origin = 'https://app.easypos.vn',
      Object? body,
      Map<String, String> headers = const {},
    }) async {
      final req = await client.open(method, '127.0.0.1', listening, path);
      if (origin != null) req.headers.set('Origin', origin);
      headers.forEach(req.headers.set);
      if (body != null) {
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode(body));
      }
      final res = await req.close();
      final text = await utf8.decodeStream(res);
      final json = text.isEmpty
          ? <String, Object?>{}
          : jsonDecode(text) as Map<String, Object?>;
      return (res.statusCode, json, res.headers);
    }

    test('preflight trả CORS + Private Network Access', () async {
      final (status, _, h) = await send(
        'OPTIONS',
        '/v1/print',
        headers: {
          'Access-Control-Request-Method': 'POST',
          'Access-Control-Request-Private-Network': 'true',
        },
      );
      expect(status, HttpStatus.noContent);
      expect(h.value('access-control-allow-origin'), 'https://app.easypos.vn');
      expect(h.value('access-control-allow-private-network'), 'true');
      expect(h.value('access-control-allow-headers'), contains('Content-Type'));
    });

    test('trang lạ bị từ chối, không in', () async {
      final (status, json, h) = await send(
        'POST',
        '/v1/print',
        origin: 'https://evil.example',
        body: {'jobId': 'a', 'image': _png()},
      );
      expect(status, HttpStatus.forbidden);
      expect(json['error'], 'origin');
      expect(h.value('access-control-allow-origin'), isNull);
      expect(port.requests, isEmpty);
    });

    test('info', () async {
      final (status, json, _) = await send('GET', '/v1/info');
      expect(status, HttpStatus.ok);
      expect(json['app'], 'easypos-print-agent');
    });

    test('in: chuyển lệnh cho trạm, trả kết quả', () async {
      port.result = const WebPrintResult(WebPrintStatus.held, message: 'x');
      final (status, json, _) = await send(
        'POST',
        '/v1/print',
        body: {'jobId': 'HD1', 'image': _png(), 'beep': true},
      );
      expect(status, HttpStatus.ok);
      expect(json, {'status': 'held', 'message': 'x'});
      expect(port.requests.single.jobId, 'HD1');
      expect(port.requests.single.beep, isTrue);
    });

    test('lệnh sai trả 400 kèm mã lỗi', () async {
      final (status, json, _) = await send(
        'POST',
        '/v1/print',
        body: {'image': _png()},
      );
      expect(status, HttpStatus.badRequest);
      expect(json['error'], 'badJobId');
      expect(port.requests, isEmpty);
    });

    test('đường không có trả 404', () async {
      final (status, _, _) = await send('GET', '/khong-co');
      expect(status, HttpStatus.notFound);
    });
  });
}
