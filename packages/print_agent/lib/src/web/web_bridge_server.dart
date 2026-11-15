import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'web_origin_policy.dart';
import 'web_print_port.dart';
import 'web_print_request.dart';

/// Cổng web của trạm in: trang EasyPOS chạy trên trình duyệt CỦA MÁY NÀY gọi
/// `http://127.0.0.1:9102` để in — không cần cài driver máy in.
///
/// - `GET  /v1/info`  → thông tin trạm + máy in ([WebPrintPort.info]).
/// - `POST /v1/print` → in hoá đơn ([WebPrintRequest]), trả [WebPrintResult].
///
/// Mở theo [bindAddress]: mặc định MỌI địa chỉ của máy để trang web chạy trên
/// thiết bị KHÁC trong mạng quán cũng in được qua trạm in này. An toàn:
/// - yêu cầu từ máy khác BẮT BUỘC kèm `Origin` thuộc [WebOriginPolicy] (trang
///   web lạ / chương trình lạ trong mạng không gửi được);
/// - yêu cầu từ chính máy này (127.0.0.1) không có `Origin` vẫn nhận.
/// Trả lời preflight "Private Network Access" của Chrome.
class WebBridgeServer {
  WebBridgeServer(
    this._port, {
    WebOriginPolicy Function()? policy,
    this.ports = defaultPorts,
    this.bindAddress,
    void Function(String message)? log,
  }) : _policy = policy ?? (() => const WebOriginPolicy()),
       _log = log ?? ((_) {});

  /// Cổng thử lần lượt (trang web dò theo cùng thứ tự).
  static const List<int> defaultPorts = [9102, 19102];

  static const int maxRequestBytes = 16 * 1024 * 1024;

  final WebPrintPort _port;
  final WebOriginPolicy Function() _policy;
  final List<int> ports;

  /// `null` = mọi địa chỉ IPv4 của máy.
  final InternetAddress? bindAddress;
  final void Function(String message) _log;

  HttpServer? _server;

  /// Cổng đang mở; `null` khi chưa mở được.
  int? get port => _server?.port;

  Future<int?> start() async {
    if (_server != null) return _server!.port;
    for (final p in ports) {
      try {
        final server = await HttpServer.bind(
          bindAddress ?? InternetAddress.anyIPv4,
          p,
        );
        _server = server;
        server.listen((r) => unawaited(_serve(r)));
        _log('[WEB] Cổng web của trạm in mở ở cổng ${server.port}');
        return server.port;
      } on SocketException catch (e) {
        _log('[WEB] Không mở được cổng $p: ${e.message}');
      }
    }
    return null;
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<void> _serve(HttpRequest request) async {
    final res = request.response;
    try {
      final origin = request.headers.value('origin');
      final remote = request.connectionInfo?.remoteAddress;
      final fromOtherDevice = remote != null && !remote.isLoopback;
      final noOrigin = origin == null || origin.isEmpty;
      if ((fromOtherDevice && noOrigin) || !_policy().allows(origin)) {
        _log('[WEB] Từ chối trang $origin');
        return await _json(res, HttpStatus.forbidden, _error('origin'));
      }
      _cors(request, origin);
      final path = request.uri.path;
      switch ((request.method, path)) {
        case ('OPTIONS', _):
          res.statusCode = HttpStatus.noContent;
          await res.close();
        case ('GET', '/v1/info'):
          await _json(res, HttpStatus.ok, _port.info());
        case ('POST', '/v1/print'):
          await _print(request);
        default:
          await _json(res, HttpStatus.notFound, _error('notFound'));
      }
    } catch (e) {
      _log('[WEB] Lỗi xử lý ${request.uri.path}: $e');
      try {
        await _json(res, HttpStatus.internalServerError, _error('internal'));
      } catch (_) {}
    }
  }

  Future<void> _print(HttpRequest request) async {
    final res = request.response;
    final body = await _readBody(request);
    if (body == null) {
      return _json(res, HttpStatus.requestEntityTooLarge, _error('tooLarge'));
    }
    final WebPrintRequest job;
    try {
      job = WebPrintRequest.parse(jsonDecode(utf8.decode(body)));
    } on WebRequestError catch (e) {
      return _json(res, HttpStatus.badRequest, _error(e.code, e.message));
    } on FormatException {
      return _json(res, HttpStatus.badRequest, _error('badJson'));
    }
    final result = await _port.print(job);
    await _json(res, HttpStatus.ok, result.toJson());
  }

  void _cors(HttpRequest request, String? origin) {
    if (origin == null) return;
    final h = request.response.headers;
    h.set('Access-Control-Allow-Origin', origin);
    h.set('Vary', 'Origin');
    if (request.method != 'OPTIONS') return;
    h.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    h.set('Access-Control-Allow-Headers', 'Content-Type');
    h.set('Access-Control-Max-Age', '600');
    // Chrome hỏi trước khi trang công khai gọi vào máy nội bộ.
    if (request.headers.value('access-control-request-private-network') ==
        'true') {
      h.set('Access-Control-Allow-Private-Network', 'true');
    }
  }

  /// Đọc thân yêu cầu; `null` khi vượt [maxRequestBytes].
  static Future<Uint8List?> _readBody(HttpRequest request) async {
    if (request.contentLength > maxRequestBytes) return null;
    final out = BytesBuilder(copy: false);
    await for (final chunk in request) {
      out.add(chunk);
      if (out.length > maxRequestBytes) return null;
    }
    return out.takeBytes();
  }

  static Map<String, Object?> _error(String code, [String? message]) => {
    'status': 'error',
    'error': code,
    'message': ?message,
  };

  static Future<void> _json(
    HttpResponse res,
    int status,
    Map<String, Object?> body,
  ) async {
    res.statusCode = status;
    res.headers.contentType = ContentType.json;
    res.write(jsonEncode(body));
    await res.close();
  }
}
