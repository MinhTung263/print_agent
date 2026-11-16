import 'dart:async';
import 'dart:io';

/// Kết quả thử nối một địa chỉ trong mạng nội bộ.
enum ProbeResult {
  /// Nối được.
  connected,

  /// Máy bên kia từ chối (có phản hồi) — mạng thông.
  refused,

  /// "No route to host" — không tới được máy đó.
  unreachable,
  timeout,
  error,
}

/// Quyền truy cập mạng nội bộ của app.
enum LocalNetworkAccess {
  /// Nối được máy trong mạng.
  ok,

  /// Internet vào được nhưng máy trong mạng nội bộ thì không (macOS chặn quyền
  /// "Mạng cục bộ" của app).
  blocked,

  /// Chưa đủ dữ kiện kết luận (không mạng, không biết gateway...).
  unknown,
}

/// Phát hiện macOS đang chặn quyền "Mạng cục bộ" của Agent.
///
/// macOS 15+ chặn app nối tới máy trong LAN khi chưa được cấp quyền, lỗi trả
/// về là `No route to host` NGAY CẢ với gateway — trong khi Internet (đi qua
/// chính gateway đó) vẫn vào được. Nên: gateway không tới được + Internet vào
/// được ⇒ bị chặn quyền. Gateway có phản hồi (kể cả từ chối cổng) ⇒ ổn.
///
/// Các bước chạm mạng/hệ thống truyền vào được để test.
class LocalNetworkCheck {
  LocalNetworkCheck({
    Future<String?> Function()? gateway,
    Future<ProbeResult> Function(String host, int port)? probe,
    Future<bool> Function()? internet,
  }) : _gateway = gateway ?? defaultGateway,
       _probe = probe ?? defaultProbe,
       _internet = internet ?? defaultInternet;

  final Future<String?> Function() _gateway;
  final Future<ProbeResult> Function(String host, int port) _probe;
  final Future<bool> Function() _internet;

  /// Cổng thử trên gateway (router thường mở một trong số này).
  static const List<int> ports = [80, 443, 53];

  Future<LocalNetworkAccess> check() async {
    final gw = await _gateway();
    if (gw == null || gw.isEmpty) return LocalNetworkAccess.unknown;
    final results = await Future.wait([for (final p in ports) _probe(gw, p)]);
    if (results.any(
      (r) => r == ProbeResult.connected || r == ProbeResult.refused,
    )) {
      return LocalNetworkAccess.ok;
    }
    if (results.every((r) => r == ProbeResult.unreachable) &&
        await _internet()) {
      return LocalNetworkAccess.blocked;
    }
    return LocalNetworkAccess.unknown;
  }

  /// Gateway mặc định (macOS: `route -n get default`).
  static Future<String?> defaultGateway() async {
    try {
      final r = await Process.run('route', ['-n', 'get', 'default']);
      return parseGateway('${r.stdout}');
    } catch (_) {
      return null;
    }
  }

  /// Lấy địa chỉ IPv4 sau `gateway:` trong kết quả `route -n get default`.
  static String? parseGateway(String output) {
    final m = RegExp(
      r'^\s*gateway:\s*(\d+\.\d+\.\d+\.\d+)\s*$',
      multiLine: true,
    ).firstMatch(output);
    return m?.group(1);
  }

  static Future<ProbeResult> defaultProbe(String host, int port) async {
    try {
      final s = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 2),
      );
      s.destroy();
      return ProbeResult.connected;
    } on TimeoutException {
      return ProbeResult.timeout;
    } on SocketException catch (e) {
      return switch (e.osError?.errorCode) {
        61 || 111 => ProbeResult.refused, // ECONNREFUSED (macOS / Linux)
        65 || 113 => ProbeResult.unreachable, // EHOSTUNREACH
        _ => ProbeResult.error,
      };
    } catch (_) {
      return ProbeResult.error;
    }
  }

  static Future<bool> defaultInternet() async {
    try {
      final s = await Socket.connect(
        '1.1.1.1',
        443,
        timeout: const Duration(seconds: 3),
      );
      s.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
