import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';

/// "Quên Agent này" — chỉ cho Agent đang NGOẠI TUYẾN, chỉ trên máy này: bỏ khỏi
/// danh sách / sơ đồ + bỏ máy in tích hợp của nó. Có Hoàn tác; Agent bật lại thì
/// tự hiện lại.
class AgentForgetButton extends StatelessWidget {
  const AgentForgetButton({super.key, required this.station});

  final Map<Object?, Object?> station;

  void _forget() {
    final id = station['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final agent = KnownAgents.forget(id);
    final builtIn = PeerBuiltInPrinters.forget(id);
    Get.back<void>();
    unawaited(
      AppNotification.show(
        message: LocaleKeys.printerSetting_agentForgotTr(
          agent: AgentIdentity.ofStation(station),
        ),
        type: AppNotificationType.info,
        duration: const Duration(seconds: 6),
        trailing: BaseTap(
          onTap: () {
            AppNotification.dismiss();
            if (agent != null) KnownAgents.restore(agent);
            if (builtIn != null) {
              PeerBuiltInPrinters.restore(builtIn);
            }
          },
          child: const AppPadding.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
            child: AppText(
              LocaleKeys.printerSetting_agentUndo,
              variant: .title,
            ),
          ),
        ),
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
          onPressed: _forget,
          title: LocaleKeys.printerSetting_agentForget,
          backgroundColor: AppColors.errorRed,
        ),
        const AppText(
          LocaleKeys.printerSetting_agentForgetHint,
          variant: .caption,
          tone: .secondary,
          textAlign: TextAlign.center,
          maxLines: 3,
        ),
      ],
    );
  }
}
