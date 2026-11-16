import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_printer_detail_sheet.dart';

/// "Xoá máy in" ngay trong chi tiết máy in trên sơ đồ: hỏi xác nhận, xoá, đóng bảng
/// và báo kết quả.
class AgentPrinterRemoveButton extends StatelessWidget {
  const AgentPrinterRemoveButton({super.key, required this.detail});

  final AgentPrinterDetail detail;

  Future<void> _confirm() async {
    final name = detail.name;
    await Get.dialog<void>(
      AppConfirmDialog(
        title: LocaleKeys.printerSetting_agentPrinterRemove.tr,
        content: LocaleKeys.printerSetting_agentPrinterRemoveConfirmTr(
          printer: name,
        ),
        confirmText: LocaleKeys.printerSetting_agentPrinterRemove.tr,
        onConfirm: () async {
          Get.back<void>();
          final ok = await detail.onRemove!();
          if (!ok) return;
          Get.back<void>(); // đóng bảng chi tiết
          unawaited(
            AppNotification.show(
              message: LocaleKeys.printerSetting_agentPrinterRemovedTr(
                printer: name,
              ),
              type: AppNotificationType.success,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PrintAgentUi.kit.button(
    title: LocaleKeys.printerSetting_agentPrinterRemove,
    onPressed: () => unawaited(_confirm()),
    backgroundColor: AppColors.errorRed,
  );
}
