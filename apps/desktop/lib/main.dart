import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';

import 'agent/agent_config.dart';
import 'agent/agent_store.dart';
import 'agent/desktop_agent.dart';
import 'desktop/autostart.dart';
import 'desktop/desktop_shell.dart';
import 'desktop/single_instance.dart';
import 'ui/agent_theme.dart';
import 'ui/dashboard/agent_settings_card.dart';
import 'ui/login_page.dart';

/// EasyPOS Print Agent (Windows / Linux / macOS): nhận lệnh in của công ty qua
/// hàng đợi chung với app EasyPOS rồi in ESC/POS thẳng ra máy in LAN / USB —
/// máy tính không phải cài driver máy in. Chạy nền dưới khay hệ thống. Màn Máy
/// Agent dùng chung với app (module `print_agent`).
///
/// `--background`: mở thẳng xuống khay (khi tự chạy lúc bật máy).
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final instance = await SingleInstance.acquire(AgentStore.directory);
  if (instance == null) {
    // Đã có Agent chạy trên máy này: đã báo nó hiện cửa sổ — bản này thoát.
    exit(0);
  }

  final config = AgentConfig.load();
  final agent = DesktopAgent(config);
  // Chưa đăng nhập thì luôn hiện cửa sổ (chạy ẩn cũng không làm được gì).
  final startHidden = args.contains(Autostart.backgroundArg) && config.ready;
  await DesktopShell.initWindow(startHidden: startHidden);
  final shell = DesktopShell(agent);
  await shell.start();
  instance.showRequests.listen((_) => unawaited(shell.showWindow()));
  unawaited(Autostart.instance.init());
  unawaited(agent.start());

  runApp(
    GetMaterialApp(
      title: 'Trạm in EasyPOS',
      debugShowCheckedModeBanner: false,
      theme: agentTheme(),
      locale: const Locale('vi', 'VN'),
      home: ListenableBuilder(
        listenable: agent,
        builder: (_, _) => agent.config.ready
            ? AgentPage(agentSide: [AgentSettingsCard(agent: agent)])
            : LoginPage(agent: agent),
      ),
    ),
  );
}
