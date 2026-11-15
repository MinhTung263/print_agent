import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Dải "đang in" ngay dưới tiêu đề sơ đồ: mỗi lệnh in hộ đang chạy / vừa xong
/// một dòng — máy in nào (tên to), từ máy nào gửi, hoá đơn hay tem, kết quả —
/// để khách nhìn là biết máy in nào đang in, không phải dò trên sơ đồ.
class AgentActivityBanner extends StatelessWidget {
  const AgentActivityBanner({super.key});

  /// Hiện tối đa ngần này dòng (mới nhất trước).
  static const int maxRows = 3;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final rows = AgentPrintActivityStore.items.reversed
          .take(maxRows)
          .toList();
      if (rows.isEmpty) return const SizedBox.shrink();
      return AppColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.xs,
        children: [for (final a in rows) _Row(activity: a)],
      );
    });
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.activity});

  final AgentPrintActivity activity;

  /// Tên máy in nhận lệnh (máy in của máy này khớp lệnh).
  static String _printer(AgentPrintActivity a) {
    for (final s in PrintAgentUi.station.watchdog.statuses) {
      if (a.matches(s.printer)) {
        return s.printer.nameOrNull ??
            s.printer.refAddress ??
            LocaleKeys.printerSetting_agentBuiltInPrinter.tr;
      }
    }
    return a.builtIn
        ? LocaleKeys.printerSetting_agentBuiltInPrinter.tr
        : (a.ips.isNotEmpty ? a.ips.first : '');
  }

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final (label, color, icon) = switch (a.phase) {
      AgentPrintPhase.printing => (
        a.isLabel
            ? LocaleKeys.printerSetting_agentActivityPrintingLabel.tr
            : LocaleKeys.printerSetting_agentActivityPrintingReceipt.tr,
        AppColors.primaryBlueBase,
        Icons.print_rounded,
      ),
      AgentPrintPhase.done => (
        LocaleKeys.printerSetting_agentActivityDone.tr,
        AppColors.successGreen,
        Icons.check_circle_rounded,
      ),
      AgentPrintPhase.failed => (
        LocaleKeys.printerSetting_agentActivityFailed.tr,
        AppColors.errorRed,
        Icons.error_rounded,
      ),
    };
    final sender = a.sender?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.md,
        vertical: AppSpace.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: AppRow(
        spacing: AppSpace.md,
        children: [
          a.active
              ? SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: color,
                  ),
                )
              : Icon(icon, color: color, size: 22),
          Expanded(
            child: AppColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                AppText.raw(_printer(a), variant: .title, maxLines: 1),
                AppText.raw(
                  sender.isEmpty
                      ? label
                      : '$label · '
                            '${LocaleKeys.printerSetting_agentActivityBannerFromTr(sender: sender)}',
                  variant: .caption,
                  textColor: color,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
