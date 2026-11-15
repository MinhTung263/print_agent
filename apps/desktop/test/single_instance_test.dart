import 'dart:io';

import 'package:print_agent_desktop/desktop/single_instance.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/dart_cmd.dart';

void main() {
  test(
    'bản mở sau báo bản đang chạy hiện cửa sổ rồi nhường',
    () async {
      final dir = Directory.systemTemp.createTempSync('agent_single');
      final first = await SingleInstance.acquire(dir);
      expect(first, isNotNull);
      final shown = first!.showRequests.first;
      // Khoá file là theo tiến trình — chạy bản thứ hai ở tiến trình riêng.
      final second = await Process.run(dartExecutable, [
        'run',
        'test/support/second_instance.dart',
        dir.path,
      ], runInShell: runInShell);
      expect(
        second.stdout.toString().trim(),
        'null',
        reason: '${second.stderr}',
      );
      await shown.timeout(const Duration(seconds: 5));
      await first.dispose();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
