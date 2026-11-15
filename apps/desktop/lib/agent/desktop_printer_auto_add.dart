import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';
import 'package:printer_label/printer_label.dart' show PrinterLabel;

import '../store/printer_auto_add.dart';
import '../store/printer_auto_add_plan.dart';
import '../store/store_printer_api.dart';
import 'agent_store.dart';
import 'desktop_agent.dart';

/// Dựng [PrinterAutoAdd] cho trạm in máy tính: dò cổng in 9100 trong các dải
/// mạng của máy + đọc MAC từ bảng ARP, thêm vào cửa hàng qua API máy in.
PrinterAutoAdd desktopPrinterAutoAdd(DesktopAgent agent) => PrinterAutoAdd(
  repository: StorePrinterApi(
    agent.auth,
    companyId: () => agent.config.companyId,
  ),
  scan: _scan,
  enabled: () =>
      agent.config.ready && agent.isOn && agent.service.isPrimary.value,
  companyKey: () => agent.config.companyId?.toString(),
  readStore: AgentStore.get,
  writeStore: AgentStore.set,
  onAdded: (added) => PrintAgentModule.host.notify(
    added.length == 1
        ? 'Đã thêm máy in mới "${added.first.name}" vào cửa hàng — máy bán '
              'hàng chọn được ngay'
        : 'Đã thêm ${added.length} máy in mới vào cửa hàng — máy bán hàng '
              'chọn được ngay',
    level: AgentNoticeLevel.success,
  ),
  log: PrintAgentModule.host.log,
);

Future<List<FoundPrinter>> _scan() async {
  final found = await LanPrinterScanner.scan();
  if (found.isEmpty) return const [];
  // Vừa mở kết nối tới từng máy in: bảng ARP đã có MAC.
  final arp = await ArpTable.read();
  // Tên model (SNMP / mDNS... — không gửi gì vào cổng in) để đặt tên máy in.
  final models = await Future.wait([
    for (final f in found)
      PrinterLabel.getLanPrinterName(f.host).catchError((_) => null),
  ]);
  return [
    for (var i = 0; i < found.length; i++)
      FoundPrinter(
        address: found[i].address,
        mac: arp[found[i].host],
        model: models[i],
      ),
  ];
}
