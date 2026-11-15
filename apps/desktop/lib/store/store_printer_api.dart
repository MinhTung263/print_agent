import 'dart:convert';
import 'dart:io';

import '../auth/auth_service.dart';
import '../auth/auth_session.dart';
import 'store_printer.dart';

/// Lỗi gọi API máy in của cửa hàng.
class StoreApiException implements Exception {
  const StoreApiException(this.message);

  final String message;

  @override
  String toString() => 'StoreApiException: $message';
}

/// Danh sách máy in của cửa hàng trên máy chủ EasyPOS (cùng API app bán
/// hàng: `print-setting`).
abstract interface class StorePrinterRepository {
  Future<List<StorePrinter>> list();
  Future<void> create(StorePrinter printer);
}

class StorePrinterApi implements StorePrinterRepository {
  StorePrinterApi(this._session, {required int? Function() companyId})
    : _companyId = companyId;

  static const _listPath = '/api/client/page/print-setting/get-with-paging';
  static const _createPath = '/api/client/page/print-setting/create';

  final AuthSession _session;
  final int? Function() _companyId;

  @override
  Future<List<StorePrinter>> list() async {
    final json = await _send(
      'GET',
      Uri.parse(
        '${AuthService.host}$_listPath',
      ).replace(queryParameters: {'page': '0', 'size': '200'}),
    );
    final data = json is Map ? json['data'] : null;
    if (data is! List) throw const StoreApiException('Danh sách máy in lỗi');
    return [for (final m in data) ?StorePrinter.fromJson(m)];
  }

  @override
  Future<void> create(StorePrinter printer) async {
    final company = _companyId();
    if (company == null) throw const StoreApiException('Chưa đăng nhập');
    final json = await _send(
      'POST',
      Uri.parse('${AuthService.host}$_createPath'),
      body: printer.toCreateJson(company),
    );
    if (json is Map && json['status'] == false) {
      throw StoreApiException(json['reason']?.toString() ?? 'Tạo máy in lỗi');
    }
  }

  /// Gửi kèm token; bị từ chối (401/403) thì lấy token mới và thử lại một lần.
  Future<Object?> _send(
    String method,
    Uri uri, {
    Map<String, Object?>? body,
  }) async {
    var token = await _session.token() ?? await _session.renew();
    for (var attempt = 0; ; attempt++) {
      if (token == null) {
        throw const StoreApiException('Chưa có phiên đăng nhập');
      }
      final (status, json) = await _request(method, uri, token, body);
      if ((status == 401 || status == 403) && attempt == 0) {
        token = await _session.renew();
        continue;
      }
      if (status < 200 || status >= 300) {
        throw StoreApiException('Máy chủ trả lỗi ($status)');
      }
      return json;
    }
  }

  static Future<(int, Object?)> _request(
    String method,
    Uri uri,
    String token,
    Map<String, Object?>? body,
  ) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.openUrl(method, uri);
      req.headers.contentType = ContentType.json;
      req.headers.set('Authorization', 'Bearer $token');
      if (body != null) req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 30));
      final text = await res.transform(utf8.decoder).join();
      Object? json;
      try {
        json = text.isEmpty ? null : jsonDecode(text);
      } catch (_) {}
      return (res.statusCode, json);
    } on StoreApiException {
      rethrow;
    } catch (e) {
      throw StoreApiException('Không kết nối được máy chủ: $e');
    } finally {
      client.close();
    }
  }
}
