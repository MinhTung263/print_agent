import 'dart:async';

import 'package:get/get.dart';

import '../../agent/desktop_agent.dart';
import 'printer_picker_dialog.dart';

/// "Thêm máy in" trên sơ đồ / bảng trạm in này (máy tính): mở hộp chọn máy in
/// (dò LAN + USB), chọn xong thì dò luôn để tự thêm máy in LAN vào danh sách
/// máy in của cửa hàng (máy bán hàng chọn được ngay).
Future<void> desktopAddPrinter(DesktopAgent agent) async {
  final context = Get.context;
  if (context == null) return;
  final picked = await showPrintersPickerDialog(
    context,
    current: agent.config.printer,
  );
  if (picked != null && picked.isNotEmpty) await agent.addPrinters(picked);
  unawaited(agent.autoAdd.runOnce());
}
