import 'dart:convert';
import 'dart:io';

/// Một công ty tài khoản được vào — `ownerId` là `companyOwnerId` (app dùng giá
/// trị này để tính khoá hàng đợi in, KHÔNG phải mã người dùng).
class CompanyChoice {
  const CompanyChoice({
    required this.id,
    required this.ownerId,
    required this.name,
    this.address = '',
  });

  final int id;
  final int ownerId;
  final String name;
  final String address;
}

class LoginResult {
  const LoginResult({required this.fullName, required this.companies});

  final String fullName;
  final List<CompanyChoice> companies;
}

/// Token gọi API của một công ty (`id_token` + `refreshToken`).
class AuthTokens {
  const AuthTokens({required this.idToken, this.refreshToken});

  final String idToken;
  final String? refreshToken;
}

class LoginException implements Exception {
  const LoginException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Đăng nhập tài khoản EasyPOS — chỉ để biết công ty (mã + chủ), không giữ token
/// hay mật khẩu.
abstract final class AuthService {
  static const _path = '/api/client/common/authenticate';

  /// Luôn đăng nhập máy chủ thật (Production) — trạm in cài cho khách.
  static const String host = 'https://api.easypos.vn';
  static const String _host = host;
  static const _refreshPath = '/api/p/client/common/refresh-all-tokens';

  static Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    final Object? json;
    int status = 0;
    try {
      final req = await client.postUrl(Uri.parse('$_host$_path'));
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'username': username, 'password': password}));
      final res = await req.close().timeout(const Duration(seconds: 30));
      status = res.statusCode;
      final body = await res.transform(utf8.decoder).join();
      try {
        json = jsonDecode(body);
      } catch (_) {
        throw LoginException('Máy chủ trả lỗi ($status)');
      }
    } on LoginException {
      rethrow;
    } catch (_) {
      throw const LoginException('Không kết nối được máy chủ EasyPOS');
    } finally {
      client.close();
    }
    final data = json is Map && json['data'] is Map
        ? json['data'] as Map
        : null;
    final companies = [
      if (data?['companies'] is List)
        for (final c in data!['companies'] as List)
          if (c is Map && c['id'] is int)
            CompanyChoice(
              id: c['id'] as int,
              ownerId: c['companyOwnerId'] is int
                  ? c['companyOwnerId'] as int
                  : 0,
              name: c['name']?.toString() ?? 'Công ty ${c['id']}',
              address: c['address']?.toString() ?? '',
            ),
    ];
    // Tài khoản thuộc nhiều công ty: API trả `status: false` (LOGIN_ERROR) KÈM
    // danh sách công ty để chọn — giống app, coi là đăng nhập đúng, sang bước
    // chọn công ty. Chỉ báo lỗi khi không có danh sách (sai tài khoản / mật khẩu).
    if (data == null ||
        (json is Map && json['status'] != true && companies.isEmpty)) {
      final reason = json is Map ? json['reason']?.toString() : null;
      throw LoginException(
        reason?.isNotEmpty ?? false ? reason! : 'Đăng nhập không thành công',
      );
    }
    if (companies.isEmpty) {
      throw const LoginException('Tài khoản chưa thuộc công ty nào');
    }
    return LoginResult(
      fullName: data['fullName']?.toString() ?? username,
      companies: companies,
    );
  }

  /// Đăng nhập vào công ty [companyId] để lấy token gọi API (danh sách máy in
  /// của cửa hàng...). Ném [LoginException] khi không lấy được.
  static Future<AuthTokens> companyToken({
    required String username,
    required String password,
    required int companyId,
  }) async {
    final json = await _post(_path, {
      'username': username,
      'password': password,
      'companyId': companyId,
    });
    return _tokens(json) ??
        (throw LoginException(
          (json is Map ? json['reason']?.toString() : null) ??
              'Không lấy được phiên đăng nhập',
        ));
  }

  /// Gia hạn token bằng [refreshToken]; `null` khi hết hạn / bị thu hồi.
  static Future<AuthTokens?> refresh(
    String refreshToken,
    String idToken,
  ) async {
    try {
      return _tokens(
        await _post(_refreshPath, {
          'refreshToken': refreshToken,
        }, token: idToken),
      );
    } on LoginException {
      return null;
    }
  }

  static AuthTokens? _tokens(Object? json) {
    final data = json is Map && json['data'] is Map
        ? json['data'] as Map
        : null;
    var token = data?['id_token']?.toString() ?? data?['idToken']?.toString();
    if (token == null || token.isEmpty) return null;
    if (token.startsWith('Bearer ')) token = token.substring(7);
    final refresh = data?['refreshToken']?.toString();
    return AuthTokens(
      idToken: token,
      refreshToken: refresh == null || refresh.isEmpty ? null : refresh,
    );
  }

  static Future<Object?> _post(
    String path,
    Map<String, Object?> body, {
    String? token,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.postUrl(Uri.parse('$_host$path'));
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      req.write(jsonEncode(body));
      final res = await req.close().timeout(const Duration(seconds: 30));
      final text = await res.transform(utf8.decoder).join();
      try {
        return jsonDecode(text);
      } catch (_) {
        throw LoginException('Máy chủ trả lỗi (${res.statusCode})');
      }
    } on LoginException {
      rethrow;
    } catch (_) {
      throw const LoginException('Không kết nối được máy chủ EasyPOS');
    } finally {
      client.close();
    }
  }
}
