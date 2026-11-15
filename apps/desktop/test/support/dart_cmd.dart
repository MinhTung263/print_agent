import 'dart:io';

/// Lệnh `dart` của SDK Flutter đang chạy test (Windows là `dart.bat` — phải
/// chạy qua shell).
String get dartExecutable {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return 'dart';
  return Platform.isWindows ? '$root\\bin\\dart.bat' : '$root/bin/dart';
}

bool get runInShell => Platform.isWindows;

/// Tắt tiến trình chạy bằng [dartExecutable]. Windows chạy qua shell: `kill()`
/// chỉ giết `cmd.exe`, tiến trình dart con vẫn chạy — giết cả cây tiến trình.
Future<void> killProcessTree(Process process) async {
  if (Platform.isWindows) {
    await Process.run('taskkill', ['/PID', '${process.pid}', '/T', '/F']);
  } else {
    process.kill();
  }
}
