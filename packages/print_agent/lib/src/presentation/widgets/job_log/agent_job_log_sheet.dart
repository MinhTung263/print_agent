import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/widgets/job_log/agent_job_row.dart';

/// Toàn bộ nhật ký lệnh in hộ của máy Agent (mới nhất trước), lọc Tất cả / Lỗi.
/// Cập nhật ngay khi có lệnh mới.
class AgentJobLogSheet extends StatefulWidget {
  const AgentJobLogSheet({super.key});

  static Future<void> show() => BaseBottomSheet.show<void>(
    headerTitle: LocaleKeys.printerSetting_agentJobLog,
    body: const AgentJobLogSheet(),
    allowOffline: true,
  );

  @override
  State<AgentJobLogSheet> createState() => _AgentJobLogSheetState();
}

class _AgentJobLogSheetState extends State<AgentJobLogSheet> {
  bool _failedOnly = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: AppEdgeInsets.all(AppSpace.lg),
      child: Obx(() {
        final all = AgentJobLogStore.logs.toList();
        final failed = all.where((l) => !l.ok).toList();
        final shown = _failedOnly ? failed : all;
        return AppColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.md,
          children: [
            AppRow(
              spacing: AppSpace.sm,
              children: [
                _FilterChip(
                  text: LocaleKeys.printerSetting_agentJobLogFilterAllTr(
                    count: '${all.length}',
                  ),
                  selected: !_failedOnly,
                  onTap: () => setState(() => _failedOnly = false),
                ),
                _FilterChip(
                  text: LocaleKeys.printerSetting_agentJobLogFilterFailedTr(
                    count: '${failed.length}',
                  ),
                  selected: _failedOnly,
                  color: AppColors.errorRed,
                  onTap: () => setState(() => _failedOnly = true),
                ),
              ],
            ),
            if (shown.isEmpty)
              AppText(
                _failedOnly
                    ? LocaleKeys.printerSetting_agentJobLogNoFailed
                    : LocaleKeys.printerSetting_agentJobLogEmpty,
                variant: .body,
                tone: .secondary,
              )
            else
              BaseCard.section(
                child: AppColumn(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpace.sm,
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0) const AppDivider(),
                      AgentJobRow(log: shown[i]),
                    ],
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Nút lọc dạng viên thuốc: chọn → nền màu, chữ trắng.
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.text,
    required this.selected,
    required this.onTap,
    this.color = AppColors.primaryBlueBase,
  });

  final String text;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return BaseTap(
      onTap: onTap,
      child: Container(
        padding: AppEdgeInsets.symmetric(
          horizontal: AppSpace.md,
          vertical: AppSpace.xs,
        ),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AppText.raw(
          text,
          variant: .title,
          textColor: selected ? Colors.white : color,
        ),
      ),
    );
  }
}
