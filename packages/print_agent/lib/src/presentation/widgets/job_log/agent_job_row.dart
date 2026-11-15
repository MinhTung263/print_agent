import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/utils/agent_time_format.dart';

/// Một lệnh in hộ: hoá đơn / tem, máy in nào, máy nào gửi, giờ + kênh + thời
/// gian, lý do lỗi.
class AgentJobRow extends StatelessWidget {
  const AgentJobRow({super.key, required this.log});

  final AgentJobLog log;

  static String _errorText(AgentJobError? e) => switch (e) {
    AgentJobError.noContent => LocaleKeys.printerSetting_agentJobErrNoContent,
    AgentJobError.otherNetwork =>
      LocaleKeys.printerSetting_agentJobErrOtherNetwork,
    AgentJobError.builtInNotReady =>
      LocaleKeys.printerSetting_agentJobErrBuiltIn,
    AgentJobError.sendFailed => LocaleKeys.printerSetting_agentJobErrSend,
    AgentJobError.outOfPaper => LocaleKeys.printerSetting_agentJobErrOutOfPaper,
    AgentJobError.coverOpen => LocaleKeys.printerSetting_agentJobErrCoverOpen,
    AgentJobError.overheated => LocaleKeys.printerSetting_agentJobErrOverheated,
    AgentJobError.busy => LocaleKeys.printerSetting_agentJobErrBusy,
    AgentJobError.unreachable =>
      LocaleKeys.printerSetting_agentJobErrUnreachable,
    AgentJobError.notReady ||
    null => LocaleKeys.printerSetting_agentJobErrNotReady,
  }.tr;

  /// Biểu tượng kiểu kết nối máy in.
  static IconData _connectionIcon(String? connection) => switch (connection) {
    'usb' => Icons.usb_rounded,
    'builtin' => Icons.point_of_sale_rounded,
    _ => Icons.lan_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = log.ok ? AppColors.successGreen : AppColors.errorRed;
    final kind = log.isLabel
        ? LocaleKeys.printerSetting_agentJobLabel.tr
        : LocaleKeys.printerSetting_agentJobReceipt.tr;
    final sender = log.sender?.isNotEmpty ?? false
        ? log.sender!
        : LocaleKeys.printerSetting_agentJobUnknownSender.tr;
    // Chỉ thông tin khách cần: máy in nào, máy nào gửi, lúc nào, lý do lỗi dễ
    // hiểu (IP, đường đi, thời gian in, câu lỗi gốc của máy in vẫn lưu trong
    // nhật ký để hỗ trợ kỹ thuật).
    final printer = log.printerName;
    final meta = formatAgentTime(log.at);
    return AppRow(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.sm,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            log.isLabel ? Icons.sell_outlined : Icons.receipt_long_rounded,
            color: color,
            size: 20,
          ),
        ),
        Expanded(
          child: AppColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              // "Hoá đơn · 2 bản"
              AppText.raw(
                [
                  kind,
                  if (log.copies > 1)
                    LocaleKeys.printerSetting_agentJobCopiesTr(
                      count: '${log.copies}',
                    ),
                ].join(' · '),
                variant: .title,
                maxLines: 1,
              ),
              // Máy in nào: biểu tượng LAN / USB / tích hợp + tên · IP.
              if (printer.isNotEmpty)
                _IconLine(icon: _connectionIcon(log.connection), text: printer),
              // Máy nào gửi lệnh.
              _IconLine(
                icon: Icons.devices_rounded,
                text: LocaleKeys.printerSetting_agentJobFromTr(sender: sender),
              ),
              _IconLine(icon: Icons.schedule_rounded, text: meta),
              if (!log.ok)
                _IconLine(
                  icon: Icons.error_outline_rounded,
                  text: _errorText(log.error),
                  color: AppColors.errorRed,
                ),
            ],
          ),
        ),
        Icon(
          log.ok ? Icons.check_circle_rounded : Icons.error_rounded,
          color: color,
          size: 20,
        ),
      ],
    );
  }
}

/// Một dòng thông tin: biểu tượng nhỏ + chữ.
class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;

  /// Màu chữ + biểu tượng (mặc định màu chữ phụ).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppRow(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color ?? AppColors.dsGray2),
        ),
        Expanded(
          child: AppText.raw(
            text,
            variant: .caption,
            tone: .secondary,
            // Có màu riêng (VD lỗi màu đỏ) thì đè màu chữ phụ.
            textColor: color,
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}
