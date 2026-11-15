import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../agent/print_agent.dart';
import 'autostart.dart';

/// Chạy nền như app Android: biểu tượng ở khay hệ thống, đóng cửa sổ chỉ ẩn
/// xuống khay (Agent vẫn nhận lệnh in), chỉ thoát hẳn khi chọn "Thoát".
class DesktopShell with TrayListener, WindowListener {
  DesktopShell(this.agent);

  final PrintAgent agent;

  static const _keyOpen = 'open';
  static const _keyToggle = 'toggle';
  static const _keyAutostart = 'autostart';
  static const _keyQuit = 'quit';

  /// Chuẩn bị cửa sổ (ẩn) — gọi trước `runApp`.
  static Future<void> initWindow({required bool startHidden}) async {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'EasyPOS Print Agent',
      size: Size(1100, 760),
      minimumSize: Size(420, 560),
      center: true,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      // Đóng cửa sổ = ẩn xuống khay (xử lý ở [onWindowClose]).
      await windowManager.setPreventClose(true);
      if (!startHidden) {
        await windowManager.show();
        await windowManager.focus();
      }
    });
  }

  Future<void> start() async {
    windowManager.addListener(this);
    trayManager.addListener(this);
    await trayManager.setIcon(
      Platform.isWindows
          ? 'assets/tray/tray_icon.ico'
          : 'assets/tray/tray_icon.png',
    );
    agent.addListener(_refreshTray);
    Autostart.instance.enabled.addListener(_refreshTray);
    await _refreshTrayNow();
  }

  Future<void> showWindow() async {
    await windowManager.show();
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.focus();
  }

  /// Thoát hẳn: rút khỏi danh sách Agent, gỡ biểu tượng khay, đóng ứng dụng.
  Future<void> quit() async {
    agent.removeListener(_refreshTray);
    Autostart.instance.enabled.removeListener(_refreshTray);
    await agent.shutdown().timeout(
      const Duration(seconds: 3),
      onTimeout: () {},
    );
    await trayManager.destroy();
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  String? _lastTray;

  void _refreshTray() => unawaited(_refreshTrayNow());

  Future<void> _refreshTrayNow() async {
    final on = agent.state != AgentState.off;
    final status = switch (agent.state) {
      AgentState.off => 'Đang tắt',
      AgentState.connecting => 'Đang kết nối…',
      AgentState.online => 'Đang nhận lệnh in',
      AgentState.offline => 'Mất kết nối — đang thử lại',
    };
    final auto = Autostart.instance.enabled.value;
    // Menu chỉ dựng lại khi nội dung đổi (agent báo thay đổi rất thường xuyên).
    final signature = '$status|$on|$auto|${agent.config.ready}';
    if (signature == _lastTray) return;
    _lastTray = signature;
    if (!Platform.isLinux) {
      await trayManager.setToolTip('EasyPOS Print Agent — $status');
    }
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(label: 'EasyPOS Print Agent · $status', disabled: true),
          MenuItem.separator(),
          MenuItem(key: _keyOpen, label: 'Mở cửa sổ'),
          if (agent.config.ready)
            MenuItem(key: _keyToggle, label: on ? 'Tắt Agent' : 'Bật Agent'),
          if (Autostart.supported)
            MenuItem.checkbox(
              key: _keyAutostart,
              label: 'Tự chạy khi bật máy',
              checked: auto,
            ),
          MenuItem.separator(),
          MenuItem(key: _keyQuit, label: 'Thoát'),
        ],
      ),
    );
  }

  // --- Khay -------------------------------------------------------------------
  // Linux (AppIndicator) không báo sự kiện bấm biểu tượng — bấm là hiện menu.

  @override
  void onTrayIconMouseDown() => unawaited(showWindow());

  @override
  void onTrayIconRightMouseDown() => unawaited(trayManager.popUpContextMenu());

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case _keyOpen:
        unawaited(showWindow());
      case _keyToggle:
        unawaited(agent.state == AgentState.off ? agent.start() : agent.stop());
      case _keyAutostart:
        unawaited(Autostart.instance.set(!Autostart.instance.enabled.value));
      case _keyQuit:
        unawaited(quit());
    }
  }

  // --- Cửa sổ -----------------------------------------------------------------

  @override
  void onWindowClose() => unawaited(windowManager.hide());
}
