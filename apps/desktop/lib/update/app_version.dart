/// Phiên bản app dạng `0.2.0+3` (số phiên bản + số build) để so sánh với bản mới trên GitHub Releases.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.parts, [this.build = 0]);

  /// Các số của phiên bản (`0.2.0` → `[0, 2, 0]`).
  final List<int> parts;
  final int build;

  /// `0.2.0`, `0.2.0+3`, `v0.2.0+3`; `null` khi không đọc được.
  static AppVersion? parse(String? text) {
    final m = RegExp(
      r'^\s*v?([0-9]+(?:\.[0-9]+)*)(?:\+([0-9]+))?\s*$',
    ).firstMatch(text ?? '');
    if (m == null) return null;
    return AppVersion([
      for (final p in m.group(1)!.split('.')) int.parse(p),
    ], int.tryParse(m.group(2) ?? '') ?? 0);
  }

  /// Bản đang chạy: CI đóng dấu qua `--dart-define=APP_VERSION=<version trong pubspec>`. Chạy từ mã nguồn
  /// (không có dấu) thì `null` — tắt tự cập nhật, khỏi ghi đè bản đang phát triển.
  static AppVersion? get current => parse(_raw);
  static const String _raw = String.fromEnvironment('APP_VERSION');

  @override
  int compareTo(AppVersion other) {
    final n = parts.length > other.parts.length
        ? parts.length
        : other.parts.length;
    for (var i = 0; i < n; i++) {
      final a = i < parts.length ? parts[i] : 0;
      final b = i < other.parts.length ? other.parts[i] : 0;
      if (a != b) return a.compareTo(b);
    }
    return build.compareTo(other.build);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(parts.join('.'), build);

  @override
  String toString() => '${parts.join('.')}${build > 0 ? '+$build' : ''}';
}
