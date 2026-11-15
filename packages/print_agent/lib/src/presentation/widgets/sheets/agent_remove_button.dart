import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';

/// "Xoá Agent này" — chỉ cho Agent ĐANG TRỰC TUYẾN mà KHÔNG có máy in: gửi lệnh
/// tắt chế độ Agent tới máy đó (máy đó tự kiểm tra lại, có máy in thì bỏ qua) +
/// quên trên máy này. Hỏi xác nhận trước.
class AgentRemoveButton extends StatelessWidget {
  const AgentRemoveButton({super.key, required this.station});

  final Map<Object?, Object?> station;

  Future<void> _confirm() async {
    final name = AgentIdentity.ofStation(station);
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
        const AppText(
          LocaleKeys.printerSetting_agentRemoveHint,
          variant: .caption,
          tone: .secondary,
          textAlign: TextAlign.center,
          maxLines: 3,
        ),
      ],
    );
  }
}
