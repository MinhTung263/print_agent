import 'dart:convert';

import 'app_version.dart';

/// Một tệp bộ cài: địa chỉ tải + mã băm SHA-256 để kiểm tra trước khi chạy.
class UpdateAsset {
  const UpdateAsset(this.url, this.sha256);

  final Uri url;
  final String sha256;

  /// Tên tệp (đoạn cuối của địa chỉ, đã giải mã `%2B` → `+`).
  String get fileName => Uri.decodeComponent(url.pathSegments.last);
}

/// `update.json` đính kèm mỗi bản phát hành (do CI tạo, xem `.github/scripts/make_release.py`):
/// `{version, build, notes?, windows:{url, sha256}, linux:{url, sha256}}`.
class UpdateManifest {
  const UpdateManifest(
    this.version,
    this.windows,
    this.linux, {
    this.macos,
    this.notes,
  });

  final AppVersion version;
  final UpdateAsset? windows;
  final UpdateAsset? linux;

  /// Ảnh đĩa `.dmg` cho macOS (khách tải về cài tay — macOS không tự cài được vì chưa ký Developer ID).
  final UpdateAsset? macos;
  final String? notes;

  /// Tải bộ cài chỉ từ trang phát hành GitHub của dự án: `update.json` bị sửa / giả mạo cũng không kéo
  /// Agent tải tệp từ nơi khác.
  static const String trustedPrefix =
      'https://github.com/MinhTung263/print_agent/releases/download/';

  /// `null` khi không hợp lệ (sai định dạng, địa chỉ lạ, mã băm sai).
  static UpdateManifest? parse(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final v = AppVersion.parse(
        '${j['version']}${(j['build'] ?? 0) == 0 ? '' : '+${j['build']}'}',
      );
      if (v == null) return null;
      UpdateAsset? asset(Object? o) {
        if (o is! Map) return null;
        final url = '${o['url']}';
        final hash = '${o['sha256']}'.toLowerCase();
        if (!url.startsWith(trustedPrefix) ||
            !RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
          return null;
        }
        final uri = Uri.tryParse(url);
        return uri == null ? null : UpdateAsset(uri, hash);
      }

      final windows = asset(j['windows']);
      final linux = asset(j['linux']);
      final macos = asset(j['macos']);
      if (windows == null && linux == null && macos == null) return null;
      return UpdateManifest(
        v,
        windows,
        linux,
        macos: macos,
        notes: j['notes'] is String ? j['notes'] as String : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Bộ cài cho hệ điều hành [os] (`windows` / `linux`); macOS không phát hành tự động.
  UpdateAsset? assetFor(String os) => switch (os) {
    'windows' => windows,
    'linux' => linux,
    'macos' => macos,
    _ => null,
  };
}
