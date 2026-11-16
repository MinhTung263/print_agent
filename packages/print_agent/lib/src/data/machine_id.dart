import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Mã định danh MÁY của hệ điều hành máy tính — cố định qua các lần cài lại ứng dụng, để
/// Agent giữ cùng một mã trạm (không sinh trạm mới mỗi lần cài):
/// - Windows: `MachineGuid` trong registry;
/// - macOS: `IOPlatformUUID` (phần cứng);
/// - Linux: `/etc/machine-id`.
/// Chỉ dùng để băm ra mã trạm, không gửi mã gốc đi.
abstract final class MachineId {
  /// Mã máy của thiết bị này; `null` khi không đọc được (hoặc không phải máy tính).
  static Future<String?> read() async {
    try {
      if (Platform.isWindows) {
        final out = await _run('reg', [
          'query',
          r'HKLM\SOFTWARE\Microsoft\Cryptography',
          '/v',
          'MachineGuid',
        ]);
        return parseWindows(out);
      }
      if (Platform.isMacOS) {
        final out = await _run('ioreg', [
          '-rd1',
          '-c',
          'IOPlatformExpertDevice',
        ]);
        return parseMac(out);
      }
      if (Platform.isLinux) {
        for (final path in ['/etc/machine-id', '/var/lib/dbus/machine-id']) {
          final f = File(path);
          if (await f.exists()) {
            final id = parseLinux(await f.readAsString());
            if (id != null) return id;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Tên người dùng hệ điều hành đang chạy app: nhiều người dùng cùng đăng nhập một máy
  /// mỗi người chạy một Agent riêng nên mã trạm phải khác nhau.
  static String get osUser =>
      Platform.environment['USERNAME'] ?? Platform.environment['USER'] ?? '';

  static Future<String> _run(String cmd, List<String> args) async {
    final r = await Process.run(
      cmd,
      args,
      stdoutEncoding: utf8,
    ).timeout(const Duration(seconds: 3));
    return '${r.stdout}';
  }

  /// `    MachineGuid    REG_SZ    8b1c...` → GUID.
  static String? parseWindows(String out) {
    final m = RegExp(
      r'MachineGuid\s+REG_SZ\s+([0-9A-Fa-f-]{8,})',
    ).firstMatch(out);
    return _clean(m?.group(1));
  }

  /// `"IOPlatformUUID" = "ABCD-..."` → UUID.
  static String? parseMac(String out) {
    final m = RegExp(r'"IOPlatformUUID"\s*=\s*"([^"]+)"').firstMatch(out);
    return _clean(m?.group(1));
  }

  static String? parseLinux(String out) => _clean(out.trim());

  static String? _clean(String? v) {
    final s = (v ?? '').trim().toLowerCase();
    if (s.length < 8) return null;
    // Mã mẫu của bản sao máy ảo / tệp rỗng: không dùng làm mã máy.
    if (RegExp(r'^[0-]+$').hasMatch(s)) return null;
    return s;
  }
}
