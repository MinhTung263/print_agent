import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Kho bí mật (mật khẩu, token) — tách để test thay bằng bộ nhớ.
abstract interface class SecretStore {
  Future<String?> read(String key);

  /// `null` = xoá.
  Future<void> write(String key, String? value);
}

/// Kho bảo mật của hệ điều hành: macOS Keychain, Windows DPAPI, Linux
/// libsecret. Lỗi (máy không có kho) coi như không có dữ liệu.
class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? defaultStorage;

  static const FlutterSecureStorage defaultStorage = FlutterSecureStorage(
    // Keychain thường: không cần ký app / quyền keychain-access-groups.
    mOptions: MacOsOptions(
      accountName: 'EasyPOS Agent',
      usesDataProtectionKeychain: false,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key, String? value) async {
    try {
      value == null
          ? await _storage.delete(key: key)
          : await _storage.write(key: key, value: value);
    } catch (_) {}
  }
}

/// Kho trong bộ nhớ (test).
class MemorySecretStore implements SecretStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String? value) async =>
      value == null ? values.remove(key) : values[key] = value;
}
