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

  /// Máy chủ API theo môi trường (giống app).
  static const Map<String, String> _hosts = {
    'Production': 'https://api.easypos.vn',
    'Staging': 'http://10.100.140.9:8085',
    'Test': 'http://10.100.140.9:8082',
    'Test 88': 'http://10.100.140.9:8888',
  };

  static List<String> get envs => _hosts.keys.toList();

  static String _url(String env) =>
      '${_hosts[env] ?? _hosts['Production']}$_path';

  static Future<LoginResult> login({
    required String env,
    required String username,
    required String password,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    final Object? json;
    int status = 0;
    try {
      final req = await client.postUrl(Uri.parse(_url(env)));
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
}
