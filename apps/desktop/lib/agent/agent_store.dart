import 'dart:convert';
import 'dart:io';

/// Lưu cấu hình Agent ra một file JSON trong thư mục cấu hình của người dùng:
/// - Windows: `%APPDATA%\EasyPOS\PrintAgent\`
/// - macOS: `~/Library/Application Support/EasyPOS/PrintAgent/`
/// - Linux: `$XDG_CONFIG_HOME/easypos-print-agent/` (mặc định `~/.config/...`)
abstract final class AgentStore {
  static Directory? _dirOverride;

  /// Thư mục khác (test).
  static set debugDirectory(Directory? dir) {
    _dirOverride = dir;
    _cache = null;
  }

  static Directory get directory {
    final override = _dirOverride;
    if (override != null) return override;
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'] ?? '.';
    if (Platform.isWindows) {
      final base = env['APPDATA'] ?? '$home\\AppData\\Roaming';
      return Directory('$base\\EasyPOS\\PrintAgent');
    }
    if (Platform.isMacOS) {
      return Directory('$home/Library/Application Support/EasyPOS/PrintAgent');
    }
    final xdg = env['XDG_CONFIG_HOME'];
    return Directory(
      '${xdg == null || xdg.isEmpty ? '$home/.config' : xdg}/easypos-print-agent',
    );
  }

  static File get _file =>
      File('${directory.path}${Platform.pathSeparator}config.json');

  static Map<String, String>? _cache;

  static Map<String, String> _all() {
    final cached = _cache;
    if (cached != null) return cached;
    var data = <String, String>{};
    try {
      final f = _file;
      if (f.existsSync()) {
        final raw = jsonDecode(f.readAsStringSync());
        if (raw is Map) {
          data = {
            for (final e in raw.entries)
              if (e.value != null) '${e.key}': '${e.value}',
          };
        }
      }
    } catch (_) {}
    return _cache = data;
  }

  static String? get(String key) => _all()[key];

  static void set(String key, String value) =>
      _write(() => _all()[key] = value);

  static void remove(String key) => _write(() => _all().remove(key));

  static void _write(void Function() change) {
    change();
    try {
      directory.createSync(recursive: true);
      // Ghi file tạm rồi đổi tên: tắt máy giữa chừng không làm hỏng cấu hình.
      final tmp = File('${_file.path}.tmp')
        ..writeAsStringSync(
          const JsonEncoder.withIndent('  ').convert(_all()),
          flush: true,
        );
      tmp.renameSync(_file.path);
    } catch (_) {}
  }
}
