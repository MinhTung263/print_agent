import 'dart:convert';

import 'secret_store.dart';

/// Tài khoản + mật khẩu đã ghi nhớ (ô "Ghi nhớ mật khẩu" ở màn đăng nhập).
class SavedLogin {
  const SavedLogin({required this.username, required this.password});

  final String username;
  final String password;
}

/// Nơi giữ [SavedLogin]. Lỗi đọc / ghi (máy không có kho bảo mật...) thì coi
/// như chưa lưu — không chặn đăng nhập.
abstract interface class SavedLoginStore {
  Future<SavedLogin?> read();
  Future<void> save(SavedLogin login);
  Future<void> clear();
}

/// Lưu trong kho bảo mật của hệ điều hành ([SecretStore]), KHÔNG ghi mật
/// khẩu ra file cấu hình.
class SecureSavedLoginStore implements SavedLoginStore {
  SecureSavedLoginStore([SecretStore? store])
    : _store = store ?? SecureSecretStore();

  static const String _key = 'saved_login';

  final SecretStore _store;

  @override
  Future<SavedLogin?> read() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null) return null;
      final m = jsonDecode(raw);
      if (m is! Map) return null;
      final user = m['u'], pass = m['p'];
      if (user is! String || pass is! String || user.isEmpty) return null;
      return SavedLogin(username: user, password: pass);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(SavedLogin login) => _store.write(
    _key,
    jsonEncode({'u': login.username, 'p': login.password}),
  );

  @override
  Future<void> clear() => _store.write(_key, null);
}
