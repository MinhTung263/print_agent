import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:launch_at_startup/launch_at_startup.dart';

import '../agent/agent_store.dart';

/// Tự chạy Agent (ẩn dưới khay) khi đăng nhập máy — như app Android tự chạy
/// nền. Windows: khoá `HKCU\...\Run`; Linux: `~/.config/autostart/*.desktop`.
/// macOS chỉ dùng để phát triển nên không hỗ trợ.
class Autostart {
  Autostart._();

  static final Autostart instance = Autostart._();

  /// Tham số khi tự chạy: mở thẳng xuống khay, không hiện cửa sổ.
  static const String backgroundArg = '--background';

  static bool get supported => Platform.isWindows || Platform.isLinux;

  /// Đang bật tự chạy (`false` khi không hỗ trợ).
  final ValueNotifier<bool> enabled = ValueNotifier(false);

  Future<void> init() async {
    if (!supported) return;
    launchAtStartup.setup(
      appName: 'EasyPOS Print Agent',
      appPath: Platform.resolvedExecutable,
      args: const [backgroundArg],
    );
    // Lần đầu chạy: bật sẵn (Agent cần chạy nền mới nhận lệnh in). Người dùng
    // tắt ở Cài đặt / menu khay thì giữ nguyên lựa chọn đó.
    if (AgentStore.get('autostartInit') != '1') {
      await set(true);
      AgentStore.set('autostartInit', '1');
      return;
    }
    enabled.value = await _isEnabled();
    // Cài lại bản mới ở chỗ khác: đăng ký lại đường dẫn chạy.
    if (enabled.value) await _safe(launchAtStartup.enable);
  }

  Future<void> set(bool on) async {
    if (!supported) return;
    await _safe(on ? launchAtStartup.enable : launchAtStartup.disable);
    enabled.value = await _isEnabled();
  }

  Future<bool> _isEnabled() async {
    try {
      return await launchAtStartup.isEnabled();
    } catch (_) {
      return false;
    }
  }

  Future<void> _safe(Future<bool> Function() run) async {
    try {
      await run();
    } catch (e) {
      debugPrint('Tự chạy khi bật máy lỗi: $e');
    }
  }
}
