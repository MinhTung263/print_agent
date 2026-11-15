import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';

/// "Ngắt kết nối trạm in" — cho Agent ĐANG TRỰC TUYẾN: gửi lệnh tắt chế độ
/// Agent tới máy đó + quên trên máy này. Hỏi xác nhận trước. Trạm còn máy in mà
/// chạy bản cũ (chỉ nhận lệnh khi không có máy in): báo cần cập nhật.
class AgentRemoveButton extends StatelessWidget {
  const AgentRemoveButton({super.key, required this.station});

  final Map<Object?, Object?> station;

  Future<void> _confirm() async {
    final name = AgentIdentity.ofStation(station);
    if (!AgentIdentity.canStopRemotely(station)) {
      unawaited(
        AppNotification.show(
          message: LocaleKeys.printerSetting_agentStopOldVersionTr(agent: name),
          type: AppNotificationType.warning,
          duration: const Duration(seconds: 6),
        ),
      );
      return;
    }
    await Get.dialog<void>(
      AppConfirmDialog(
        title: LocaleKeys.printerSetting_agentRemove.tr,
        content: LocaleKeys.printerSetting_agentRemoveConfirmTr(agent: name),
        confirmText: LocaleKeys.printerSetting_agentRemove.tr,
        onConfirm: () async {
          Get.back<void>();
          final sent = await PrintAgentUi.station.removeAgent(station);
          if (sent) Get.back<void>();
          unawaited(
            AppNotification.show(
              message: sent
                  ? LocaleKeys.printerSetting_agentRemovedTr(agent: name)
                  : LocaleKeys.printerSetting_agentRemoveFailed.tr,
              type: sent
                  ? AppNotificationType.success
                  : AppNotificationType.error,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.xs,
      children: [
        BaseButton(
          onPressed: () => unawaited(_confirm()),
          title: LocaleKeys.printerSetting_agentRemove,
          backgroundColor: AppColors.errorRed,
        ),
        AppText(
          AgentIdentity.hasNoPrinters(station)
              ? LocaleKeys.printerSetting_agentRemoveHint
              : LocaleKeys.printerSetting_agentRemoveHintPrinters,
          variant: .caption,
          tone: .secondary,
          textAlign: TextAlign.center,
          maxLines: 3,
        ),
      ],
    );
  }
}
