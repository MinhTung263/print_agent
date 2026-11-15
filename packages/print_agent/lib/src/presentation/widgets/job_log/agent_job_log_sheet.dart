import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/widgets/job_log/agent_job_row.dart';

/// Toàn bộ nhật ký lệnh in hộ của máy Agent (mới nhất trước), lọc Tất cả / Lỗi.
/// Cập nhật ngay khi có lệnh mới.
class AgentJobLogSheet extends StatefulWidget {
  const AgentJobLogSheet({super.key});

  /// Danh sách dài không đè lên màn Trạm in: điện thoại mở MÀN MỚI; máy tính /
  /// tablet mở cửa sổ nổi (popup) giữa màn.
  static Future<void> show() async {
    if (PrintAgentUi.kit.isTablet) {
      await Get.dialog<void>(const _JobLogDialog());
      return;
    }
    await Get.to<void>(
      () => const BaseScaffoldHelper(
        appBar: BaseAppBar(title: LocaleKeys.printerSetting_agentJobLog),
        body: AgentJobLogSheet(),
      ),
    );
  }

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

/// Popup nhật ký lệnh in (máy tính / tablet): tiêu đề + nút đóng, danh sách
/// cuộn bên trong, cao tối đa 80% màn.
class _JobLogDialog extends StatelessWidget {
  const _JobLogDialog();

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.8;
    return Dialog(
      backgroundColor: AppColors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: height),
        child: AppColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppPadding(
              padding: const EdgeInsets.only(
                left: AppSpace.lg,
                right: AppSpace.xs,
                top: AppSpace.sm,
              ),
              child: AppRow(
                children: [
                  const Expanded(
                    child: AppText(
                      LocaleKeys.printerSetting_agentJobLog,
                      variant: .title,
                    ),
                  ),
                  IconButton(
                    onPressed: Get.back<void>,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Flexible(child: AgentJobLogSheet()),
          ],
        ),
      ),
    );
  }
}
