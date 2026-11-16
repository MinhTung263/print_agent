import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/utils/agent_job_error_text.dart';
import 'package:print_agent/src/presentation/utils/agent_time_format.dart';

/// Một lệnh in hộ: hoá đơn / tem, máy in nào, máy nào gửi, giờ + kênh + thời
/// gian, lý do lỗi.
class AgentJobRow extends StatelessWidget {
  const AgentJobRow({super.key, required this.log});

  final AgentJobLog log;

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
    // Lệnh thành công: chỉ máy in nào, máy nào gửi, lúc nào. Lệnh lỗi: thêm lý do, cách
    // xử lý, địa chỉ máy in và câu lỗi gốc để khách / hỗ trợ biết do đâu.
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
              if (!log.ok) ...[
                // Vì sao in không được + cách xử lý + câu lỗi gốc + địa chỉ máy in (LAN).
                _IconLine(
                  icon: Icons.error_outline_rounded,
                  text: AgentJobErrorText.reason(log.error),
                  color: AppColors.errorRed,
                ),
                _IconLine(
                  icon: Icons.build_circle_outlined,
                  text: AgentJobErrorText.hint(log.error),
                ),
                if ((log.connection ?? 'lan') == 'lan' &&
                    (log.printerAddress ?? '').isNotEmpty)
                  _IconLine(
                    icon: Icons.lan_outlined,
                    text:
                        '${LocaleKeys.printerSetting_agentPrinterDetailIp.tr}: '
                        '${log.printerAddress}',
                  ),
                if (AgentJobErrorText.detail(log.error, log.detail).isNotEmpty)
                  _IconLine(
                    icon: Icons.info_outline_rounded,
                    text: LocaleKeys.printerSetting_agentJobDetailTr(
                      detail: AgentJobErrorText.detail(log.error, log.detail),
                    ),
                  ),
              ],
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
