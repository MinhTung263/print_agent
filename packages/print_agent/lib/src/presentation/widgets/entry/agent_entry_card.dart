import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/presentation/pages/agent_page.dart';

/// Thẻ "Máy Agent" ở màn Cài đặt in — bấm mở sơ đồ kết nối + cài đặt Agent.
class AgentEntryCard extends StatelessWidget {
  const AgentEntryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PrintAgentUi.station.relay.isStation,
      builder: (_, isAgent, _) => BaseTap(
        onTap: () => unawaited(AgentPage.show()),
        child: BaseCard.section(
          child: AppRow(
            spacing: AppSpace.md,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryBlueBase.withValues(alpha: 0.1),
                ),
                child: const Icon(
                  Icons.hub_rounded,
                  color: AppColors.primaryBlueBase,
                ),
              ),
              Expanded(
                child: AppColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpace.xs,
                  children: [
                    AppRow(
                      spacing: AppSpace.sm,
                      children: [
                        const AppText(
                          LocaleKeys.printerSetting_agentEntryTitle,
                          variant: .title,
                        ),
                        if (isAgent)
                          const Icon(
                            Icons.circle,
                            size: 9,
                            color: AppColors.successGreen,
                          ),
                      ],
                    ),
                    AppText(
                      isAgent
                          ? LocaleKeys.printerSetting_agentEntryOn
                          : LocaleKeys.printerSetting_agentEntryOff,
                      variant: .caption,
                      tone: .secondary,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.dsGray5),
            ],
          ),
        ),
      ),
    );
  }
}
