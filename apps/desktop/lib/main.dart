import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'agent/agent_config.dart';
import 'agent/agent_store.dart';
import 'agent/print_agent.dart';
import 'desktop/autostart.dart';
import 'desktop/desktop_shell.dart';
import 'desktop/single_instance.dart';
import 'ui/agent_page.dart';
import 'ui/agent_theme.dart';
import 'ui/login_page.dart';

/// EasyPOS Print Agent (Windows / Linux / macOS): nhận lệnh in hoá đơn của công
/// ty qua MQTT (cùng hàng đợi với app EasyPOS) rồi in ESC/POS thẳng ra máy in
/// LAN — máy tính không phải cài driver máy in. Chạy nền dưới khay hệ thống.
///
/// - `--background`: mở thẳng xuống khay (khi tự chạy lúc bật máy).
/// - `--preview`: xem trước giao diện bằng dữ liệu mẫu, không kết nối.
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final preview = args.contains('--preview');
  final instance = preview
      ? null
      : await SingleInstance.acquire(AgentStore.directory);
  if (!preview && instance == null) {
    // Đã có Agent chạy trên máy này: đã báo nó hiện cửa sổ — bản này thoát.
    exit(0);
  }

  final config = AgentConfig.load();
  final agent = PrintAgent(config);
  // Chưa đăng nhập thì luôn hiện cửa sổ (chạy ẩn cũng không làm được gì).
  final startHidden = args.contains(Autostart.backgroundArg) && config.ready;
  await DesktopShell.initWindow(startHidden: startHidden);
  final shell = DesktopShell(agent);
  await shell.start();
  instance?.showRequests.listen((_) => unawaited(shell.showWindow()));
  unawaited(Autostart.instance.init());

  if (preview) {
    agent.startPreview();
  } else if (config.ready && config.autoStart) {
    unawaited(agent.start());
  }
  runApp(
    MaterialApp(
      title: 'EasyPOS Print Agent',
      debugShowCheckedModeBanner: false,
      theme: agentTheme(),
      home: ListenableBuilder(
        listenable: agent,
        builder: (_, _) => agent.config.ready
            ? AgentPage(agent: agent)
            : LoginPage(agent: agent),
      ),
    ),
  );
}
