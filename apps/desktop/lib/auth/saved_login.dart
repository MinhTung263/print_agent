import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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

/// Lưu trong kho bảo mật của hệ điều hành, KHÔNG ghi mật khẩu ra file cấu
/// hình: macOS Keychain, Windows mã hoá DPAPI theo tài khoản Windows, Linux
/// libsecret (GNOME Keyring / KWallet).
class SecureSavedLoginStore implements SavedLoginStore {
  SecureSavedLoginStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Keychain thường: không cần ký app / quyền keychain-access-groups.
            mOptions: MacOsOptions(
              accountName: 'EasyPOS Agent',
              usesDataProtectionKeychain: false,
            ),
          );

  static const String _key = 'saved_login';

  final FlutterSecureStorage _storage;

  @override
  Future<SavedLogin?> read() async {
    try {
      final raw = await _storage.read(key: _key);
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
  Future<void> save(SavedLogin login) async {
    try {
      await _storage.write(
        key: _key,
        value: jsonEncode({'u': login.username, 'p': login.password}),
      );
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {}
  }
}
