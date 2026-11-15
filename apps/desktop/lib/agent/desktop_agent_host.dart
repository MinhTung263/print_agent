import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:print_agent/print_agent.dart';

import 'agent_config.dart';
import 'agent_store.dart';

/// [AgentHost] của Agent máy tính: bộ nhớ là file cấu hình ([AgentStore]),
/// công ty theo cấu hình đăng nhập, thông báo qua bộ giao diện.
class DesktopAgentHost implements AgentHost {
  DesktopAgentHost(this._config);

  static const String app = 'vn.softdreams.easypos.desktop';

  /// Cấu hình hiện tại (đổi khi đăng nhập / đổi cài đặt).
  final AgentConfig Function() _config;

  @override
  final AgentStorage storage = const _DesktopStorage();

  @override
  String get companyKey => '${_config().companyId ?? 0}';

  /// Cùng công thức với app EasyPOS: `{môi trường}/c{công ty}_{chủ}`.
  @override
  String? get shopKey {
    final c = _config();
    if (!c.ready) return null;
    final env = c.env.replaceAll(RegExp('[^A-Za-z0-9]+'), '_').toLowerCase();
    return '$env/c${c.companyId}_${c.ownerId}';
  }

  @override
  String get appPackage => app;

  @override
  String? get appDeviceName => null;

  @override
  AgentDeviceInfo? get device => AgentDeviceInfo(
    name: Platform.localHostname,
    model: Platform.isWindows
        ? 'Windows'
        : (Platform.isMacOS ? 'macOS' : 'Linux'),
  );

  @override
  List<AgentPrinterRef> get printers => const [];

  @override
  void notify(
    String message, {
    AgentNoticeLevel level = AgentNoticeLevel.info,
    Duration? duration,
    String? actionLabel,
    void Function()? onAction,
  }) {
    try {
      PrintAgentUi.kit.notify(
        message: message,
        type: level,
        duration: duration,
      );
    } catch (_) {}
  }

  @override
  void log(String message) => debugPrint(message);
}

/// Giá trị JSON của module lưu thành chuỗi trong file cấu hình (khoá `m.`).
class _DesktopStorage implements AgentStorage {
  const _DesktopStorage();

  static String _key(String key) => 'm.$key';

  @override
  Object? get(String key) {
    final raw = AgentStore.get(_key(key));
    if (raw == null) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return raw;
    }
  }

  @override
  Future<void> put(String key, Object? value) async {
    if (value == null) {
      AgentStore.remove(_key(key));
    } else {
      AgentStore.set(_key(key), jsonEncode(value));
    }
  }
}
