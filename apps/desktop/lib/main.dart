import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart' show UsbPrinters;

import 'agent/agent_config.dart';
import 'agent/agent_printer.dart';
import 'agent/agent_store.dart';
import 'agent/desktop_agent.dart';
import 'desktop/autostart.dart';
import 'desktop/desktop_shell.dart';
import 'desktop/firewall_guard.dart';
import 'desktop/single_instance.dart';
import 'network/local_network_banner.dart';
import 'ui/agent_theme.dart';
import 'ui/dashboard/add_printer_action.dart';
import 'ui/dashboard/agent_settings_card.dart';
import 'ui/dashboard/printer_settings_panel.dart';
import 'ui/dashboard/printer_test_print_action.dart';
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
  // Nút "Thêm máy in" trên sơ đồ / bảng trạm in này.
  PrintAgentUi.onAddPrinter = () => desktopAddPrinter(agent);
  // Nút "Xoá máy in" trong chi tiết máy in trên sơ đồ: bỏ máy in đã chọn để chọn lại.
  PrintAgentUi.onRemovePrinter = (printer) async {
    final address = (printer.refAddress ?? '').trim();
    if (agent.removeExtraPrinter(address)) return true;
    // Chỉ xoá máy in chính khi đúng là nó (không xoá nhầm máy khác).
    if (address != agent.config.printer.trim()) return false;
    await agent.removePrinter();
    return true;
  };
  // Nút in thử nằm trong phần cài đặt riêng của máy (máy tem: "In tem thử"): không hiện
  // thêm nút "In thử" chung.
  PrintAgentUi.hasOwnTestPrint = (printer) =>
      (printer.refAddress ?? '').isNotEmpty;
  // Cài đặt riêng từng máy in (loại, khổ giấy, căn chỉnh tem): hiện trong chi tiết máy in
  // khi bấm máy đó trên sơ đồ.
  PrintAgentUi.printerSettings = (printer) {
    final address = printer.refAddress ?? '';
    if (address.isEmpty) return null;
    return PrinterSettingsPanel(agent: agent, address: address);
  };
  // "In thử" của máy hoá đơn: cùng hàng với "Xoá máy in" ở chân chi tiết máy in.
  PrintAgentUi.printerFooterAction = (printer) {
    final address = printer.refAddress ?? '';
    if (address.isEmpty || !PrinterTestPrintAction.applies(agent, address)) {
      return null;
    }
    return PrinterTestPrintAction(agent: agent, address: address);
  };
  // Máy in USB dò rất nhanh (rút / cắm lại hiện ngay); máy LAN dò thưa hơn để khỏi chen cổng in.
  AgentPrinterWatchdog.fastProbe = (p) =>
      UsbPrinters.isLocal(p.refAddress ?? '');
  // Máy in LAN chỉ hiện xanh khi mở được cổng in (hoặc từ chối nhưng đúng máy theo MAC).
  AgentPrinterWatchdog.aliveCheck = (p) =>
      AgentPrinter.reachable(p.refAddress ?? '', mac: p.refMac);
  // Chưa đăng nhập thì luôn hiện cửa sổ (chạy ẩn cũng không làm được gì).
  final startHidden = args.contains(Autostart.backgroundArg) && config.ready;
  await DesktopShell.initWindow(startHidden: startHidden);
  final shell = DesktopShell(agent, startHidden: startHidden);
  await shell.start();
  instance.showRequests.listen((_) => unawaited(shell.showWindow()));
  unawaited(Autostart.instance.init());
  if (config.ready) unawaited(FirewallGuard.ensure());
  unawaited(agent.start());
  // Mở cả khi chưa đăng nhập: trang web báo được "Trạm in chưa đăng nhập".
  unawaited(agent.web.start());

  runApp(
    GetMaterialApp(
      title: 'Agent',
      debugShowCheckedModeBanner: false,
      theme: agentTheme(),
      // Cửa sổ ẩn xuống khay / thu nhỏ: dừng animation để về ~0% CPU.
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: shell.visible,
        builder: (_, visible, _) =>
            TickerMode(enabled: visible, child: child ?? const SizedBox()),
      ),
      locale: const Locale('vi', 'VN'),
      home: ListenableBuilder(
        listenable: agent,
        builder: (_, _) => agent.config.ready
            ? AgentPage(
                side: [const LocalNetworkBanner(), const AgentSettingsCard()],
              )
            : LoginPage(agent: agent),
      ),
    ),
  );
}
