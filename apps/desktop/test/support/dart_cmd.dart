import 'dart:io';

/// Lệnh `dart` của SDK Flutter đang chạy test (Windows là `dart.bat` — phải
/// chạy qua shell).
String get dartExecutable {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return 'dart';
  return Platform.isWindows ? '$root\\bin\\dart.bat' : '$root/bin/dart';
}

bool get runInShell => Platform.isWindows;
