import 'dart:async';
import 'package:flutter/material.dart';
import 'package:printer_label/printer_label.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Số liệu máy Agent: lệnh đã in hộ / lỗi, lệnh gần nhất, quyền tự khởi động lại.
class AgentStatsCard extends StatelessWidget {
  const AgentStatsCard({super.key, required this.autoRestart});

  final bool? autoRestart;

  @override
  Widget build(BuildContext context) {
    final service = PrintAgentUi.station;
    return BaseCard.section(
      child: Obx(() {
        final last = service.lastJobAt.value;
        return AppColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpace.xs,
          children: [
            AppText(
              LocaleKeys.printerSetting_agentStatsTr(
                printed: '${service.printed.value}',
                failed: '${service.failed.value}',
              ),
              variant: .title,
            ),
            if (last != null)
              AppText(
                LocaleKeys.printerSetting_agentLastJobTr(
                  time: formatAgentTime(last),
                ),
                variant: .caption,
                tone: .secondary,
              ),
            if (autoRestart != null)
              BaseTap(
                onTap: autoRestart!
                    ? null
                    : () => unawaited(PrinterLabel.requestAutoRestart()),
                child: AppText(
                  autoRestart!
                      ? LocaleKeys.printerSetting_agentAutoRestartOn
                      : LocaleKeys.printerSetting_agentAutoRestartOff,
                  variant: .caption,
                  textColor: autoRestart!
                      ? AppColors.successGreen
                      : AppColors.primaryBlueBase,
                ),
              ),
          ],
        );
      }),
    );
  }
}
