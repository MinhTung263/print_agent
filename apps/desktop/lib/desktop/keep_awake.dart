import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Giữ máy KHÔNG ngủ khi đang làm Agent (máy ngủ = không nhận lệnh in):
/// - Windows: `SetThreadExecutionState(ES_CONTINUOUS | ES_SYSTEM_REQUIRED)`
///   (màn hình vẫn tắt được, chỉ chặn máy ngủ);
/// - macOS: `caffeinate -i -w <pid>` (tự hết khi app thoát);
/// - Linux: `systemd-inhibit` chặn ngủ.
abstract final class KeepAwake {
  static bool _on = false;
  static Process? _helper;

  static Future<void> set(bool on) async {
    if (on == _on) return;
    _on = on;
    try {
      if (Platform.isWindows) {
        _setThreadExecutionState(
          on ? _esContinuous | _esSystemRequired : _esContinuous,
        );
      } else if (on) {
        _helper = await Process.start(
          Platform.isMacOS ? 'caffeinate' : 'systemd-inhibit',
          Platform.isMacOS
              ? ['-i', '-w', '$pid']
              : [
                  '--what=sleep:idle',
                  '--who=Trạm in EasyPOS',
                  '--why=Đang nhận lệnh in',
                  'sleep',
                  'infinity',
                ],
        );
      } else {
        _helper?.kill();
        _helper = null;
      }
    } catch (e) {
      debugPrint('[AGENT] Không chặn được máy ngủ: $e');
    }
  }

  static const int _esContinuous = 0x80000000;
  static const int _esSystemRequired = 0x00000001;

  static int _setThreadExecutionState(int flags) =>
      DynamicLibrary.open(
        'kernel32.dll',
      ).lookupFunction<Uint32 Function(Uint32), int Function(int)>(
        'SetThreadExecutionState',
      )(flags);
}

/// Phát hiện máy vừa ngủ dậy: nhịp [tick] bị trễ hơn [gap] = máy đã ngủ (Dart
/// không chạy khi máy ngủ) → gọi [onWake] để kiểm tra lại máy in / kết nối.
class WakeDetector {
  WakeDetector(
    this.onWake, {
    this.tick = const Duration(seconds: 15),
    this.gap = const Duration(seconds: 60),
  });

  final void Function() onWake;
  final Duration tick;
  final Duration gap;
  Timer? _timer;
  DateTime _last = DateTime.now();

  void start() {
    _timer?.cancel();
    _last = DateTime.now();
    _timer = Timer.periodic(tick, (_) {
      final now = DateTime.now();
      if (now.difference(_last) > gap) onWake();
      _last = now;
    });
  }

  void stop() => _timer?.cancel();
}
