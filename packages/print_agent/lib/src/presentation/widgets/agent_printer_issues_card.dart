import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_reconnect_sheet.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_wifi_switch_sheet.dart';

/// Máy Agent có máy in đang lỗi: liệt kê từng máy (lý do) + "Kết nối lại".
/// Máy in LAN ở mạng khác thì thêm "Đổi mạng" (sang đúng Wi-Fi các máy in đó).
/// Không có máy lỗi thì ẩn.
class AgentPrinterIssuesCard extends StatelessWidget {
  const AgentPrinterIssuesCard({super.key, required this.onChanged});

  /// Đã kết nối lại / đổi mạng — màn hình tải lại.
  final VoidCallback onChanged;

  /// Máy in đã tắt nhận lệnh ([AgentPrinterSwitches]) không tính là lỗi.
  static bool isIssue(AgentPrinterStatus<AgentPrinterRef> s) =>
      (s.state == AgentPrinterState.disconnected ||
          s.state == AgentPrinterState.otherNetwork) &&
      AgentPrinterSwitches.isOn(s.printer);

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final issues = PrintAgentUi.station.watchdog.statuses
          .where(isIssue)
          .toList();
      if (issues.isEmpty) return const SizedBox.shrink();
      final otherNet = [
        for (final s in issues)
          if (s.state == AgentPrinterState.otherNetwork &&
              s.printer.refKind == AgentPrinterKind.lan)
            s.printer,
      ];
      return Container(
        padding: const EdgeInsets.all(AppSpace.md),
        decoration: BoxDecoration(
          color: AppColors.errorRed.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.errorRed.withValues(alpha: 0.3)),
        ),
        child: AppColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.sm,
          children: [
            AppRow(
              spacing: AppSpace.sm,
              children: [
                const Icon(
                  Icons.print_disabled_rounded,
                  color: AppColors.errorRed,
                ),
                Expanded(
                  child: AppText.raw(
                    LocaleKeys.printerSetting_agentPrinterIssuesTr(
                      count: '${issues.length}',
                    ),
                    variant: .title,
                    maxLines: 2,
                  ),
                ),
                if (otherNet.isNotEmpty)
                  BaseTap(
                    onTap: () async {
                      if (await AgentWifiSwitchSheet.show(otherNet)) {
                        onChanged();
                      }
                    },
                    child: const AppText(
                      LocaleKeys.printerSetting_agentSwitchNetwork,
                      variant: .title,
                      textColor: AppColors.primaryBlueBase,
                    ),
                  ),
              ],
            ),
            for (final s in issues)
              _IssueRow(
                status: s,
                onReconnect: () async {
                  if (await AgentReconnectSheet.show(s.printer)) onChanged();
                },
              ),
          ],
        ),
      );
    });
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.status, required this.onReconnect});

  final AgentPrinterStatus<AgentPrinterRef> status;
  final VoidCallback onReconnect;

  static IconData _connectionIcon(AgentPrinterRef p) => switch (p.refKind) {
    AgentPrinterKind.builtIn => Icons.point_of_sale_rounded,
    AgentPrinterKind.usb => Icons.usb_rounded,
    _ => Icons.lan_outlined,
  };

  static String _address(AgentPrinterRef p) => switch (p.refKind) {
    AgentPrinterKind.builtIn => LocaleKeys.printerSetting_agentBuiltIn.tr,
    _ => p.refAddress ?? '',
  };

  @override
  Widget build(BuildContext context) {
    final p = status.printer;
    final reason = status.state == AgentPrinterState.otherNetwork
        ? LocaleKeys.printerSetting_agentStateOtherNetwork.tr
        : LocaleKeys.printerSetting_agentStateDisconnected.tr;
    return AppRow(
      spacing: AppSpace.sm,
      children: [
        Expanded(
          child: AppColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText.raw(p.nameOrNull ?? '', variant: .title, maxLines: 1),
              // Biểu tượng kiểu kết nối (LAN / USB / tích hợp) + địa chỉ · lý do.
              AppRow(
                spacing: 4,
                children: [
                  Icon(_connectionIcon(p), size: 14, color: AppColors.errorRed),
                  Expanded(
                    child: AppText.raw(
                      [
                        _address(p),
                        reason,
                      ].where((e) => e.isNotEmpty).join(' · '),
                      variant: .caption,
                      textColor: AppColors.errorRed,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        BaseTap(
          onTap: onReconnect,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primaryBlueBase),
            ),
            child: const AppRow(
              mainAxisSize: MainAxisSize.min,
              spacing: AppSpace.xs,
              children: [
                Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.primaryBlueBase,
                ),
                AppText(
                  LocaleKeys.printerSetting_agentReconnect,
                  variant: .title,
                  textColor: AppColors.primaryBlueBase,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
