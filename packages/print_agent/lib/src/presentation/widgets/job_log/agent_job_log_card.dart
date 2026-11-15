import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';

/// Máy Agent: lệnh in hộ gần đây — đặt ngay dưới sơ đồ. Gọn: số thành công /
/// lỗi + vài lệnh mới nhất; "Xem tất cả" mở bảng đầy đủ có lọc lệnh lỗi
/// ([AgentJobLogSheet]).
class AgentJobLogCard extends StatelessWidget {
  const AgentJobLogCard({super.key});

  /// Số lệnh mới nhất hiện ngay trên màn.
  static const int _preview = 3;

  @override
  Widget build(BuildContext context) {
    return BaseCard.section(
      child: Obx(() {
        final all = AgentJobLogStore.logs.toList();
        final failed = all.where((l) => !l.ok).length;
        final preview = all.take(_preview).toList();
        return AppColumn(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpace.sm,
          children: [
            AppRow(
              spacing: AppSpace.sm,
              children: [
                const Expanded(
                  child: AppText(
                    LocaleKeys.printerSetting_agentJobLog,
                    variant: .title,
                  ),
                ),
                if (all.isNotEmpty)
                  AppText.raw(
                    LocaleKeys.printerSetting_agentJobLogSummaryTr(
                      ok: '${all.length - failed}',
                      failed: '$failed',
                    ),
                    variant: .caption,
                    tone: .secondary,
                    textColor: failed > 0 ? AppColors.errorRed : null,
                  ),
              ],
            ),
            if (all.isEmpty)
              const AppText(
                LocaleKeys.printerSetting_agentJobLogEmpty,
                variant: .caption,
                tone: .secondary,
              )
            else
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0) const AppDivider(),
                AgentJobRow(log: preview[i]),
              ],
            if (all.length > _preview)
              BaseTap(
                onTap: () => unawaited(AgentJobLogSheet.show()),
                child: AppPadding.symmetric(
                  vertical: AppSpace.xs,
                  child: AppText.raw(
                    LocaleKeys.printerSetting_agentJobLogViewAllTr(
                      count: '${all.length}',
                    ),
                    variant: .title,
                    textColor: AppColors.primaryBlueBase,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
