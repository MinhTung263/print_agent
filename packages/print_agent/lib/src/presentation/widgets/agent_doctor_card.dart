import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'agent_printer_issues_card.dart';

/// "Bác sĩ trạm in": tự kiểm tra các điều kiện để trạm in nhận và in được
/// phiếu, nói bằng lời dễ hiểu cái gì đang ổn / cần xem — nhận phiếu qua
/// Internet, trong mạng quán, máy in sẵn sàng, vai trò trạm chính / dự phòng.
/// Không hiện IP / tên kênh kỹ thuật.
class AgentDoctorCard extends StatelessWidget {
  const AgentDoctorCard({super.key, required this.cloud});

  /// Trạng thái các kênh Internet (màn Trạm in theo dõi sẵn).
  final AgentCloudInfo cloud;

  @override
  Widget build(BuildContext context) {
    final station = PrintAgentUi.station;
    return BaseCard.section(
      child: Obx(() {
        final statuses = station.watchdog.statuses.toList();
        final off = AgentPrinterSwitches.off.toSet();
        final primary = station.isPrimary.value;
        final active = [
          for (final s in statuses)
            if (!off.contains(AgentPrinterSwitches.keyOf(s.printer))) s,
        ];
        final ready = active
            .where((s) => s.state == AgentPrinterState.connected)
            .length;
        final printerIssue = active.any(AgentPrinterIssuesCard.isIssue);
        final channels = cloud.channels;
        final internet = channels.isEmpty
            ? null
            : channels.values.any((v) => v);
        final lan = station.relay.lanListening;

        final checks = [
          _Check(
            title: LocaleKeys.printerSetting_agentDoctorInternet,
            detail: switch (internet) {
              null => LocaleKeys.printerSetting_agentDoctorInternetWait.tr,
              true => LocaleKeys.printerSetting_agentDoctorInternetOk.tr,
              false => LocaleKeys.printerSetting_agentDoctorInternetDown.tr,
            },
            state: internet == false ? _State.bad : _State.ok,
          ),
          _Check(
            title: LocaleKeys.printerSetting_agentDoctorLan,
            detail: lan
                ? LocaleKeys.printerSetting_agentDoctorLanOk.tr
                : LocaleKeys.printerSetting_agentDoctorLanOff.tr,
            state: lan ? _State.ok : _State.warn,
          ),
          _Check(
            title: LocaleKeys.printerSetting_agentDoctorPrinters,
            detail: active.isEmpty
                ? LocaleKeys.printerSetting_agentDoctorPrintersNone.tr
                : LocaleKeys.printerSetting_agentDoctorPrintersOkTr(
                    ok: '$ready',
                    total: '${active.length}',
                  ),
            state: active.isEmpty
                ? _State.warn
                : (printerIssue ? _State.bad : _State.ok),
          ),
          _Check(
            title: LocaleKeys.printerSetting_agentDoctorRole,
            detail: primary
                ? LocaleKeys.printerSetting_agentDoctorPrimary.tr
                : LocaleKeys.printerSetting_agentDoctorStandby.tr,
            state: _State.ok,
          ),
        ];
        final issues = checks.where((c) => c.state != _State.ok).length;
        return AppColumn(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpace.sm,
          children: [
            AppRow(
              spacing: AppSpace.sm,
              children: [
                Icon(
                  issues == 0
                      ? Icons.health_and_safety_rounded
                      : Icons.medical_services_outlined,
                  color: issues == 0
                      ? AppColors.successGreen
                      : AppColors.orange,
                ),
                const Expanded(
                  child: AppText(
                    LocaleKeys.printerSetting_agentDoctorTitle,
                    variant: .title,
                  ),
                ),
              ],
            ),
            AppText.raw(
              issues == 0
                  ? LocaleKeys.printerSetting_agentDoctorAllGood.tr
                  : LocaleKeys.printerSetting_agentDoctorIssuesTr(
                      count: '$issues',
                    ),
              variant: .caption,
              tone: .secondary,
            ),
            for (final c in checks) _CheckRow(check: c),
          ],
        );
      }),
    );
  }
}

enum _State { ok, warn, bad }

class _Check {
  const _Check({
    required this.title,
    required this.detail,
    required this.state,
  });

  final String title;
  final String detail;
  final _State state;
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final _Check check;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (check.state) {
      _State.ok => (Icons.check_circle_rounded, AppColors.successGreen),
      _State.warn => (Icons.error_outline_rounded, AppColors.orange),
      _State.bad => (Icons.cancel_rounded, AppColors.errorRed),
    };
    return AppRow(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.sm,
      children: [
        Icon(icon, size: 18, color: color),
        Expanded(
          child: AppColumn(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              AppText(check.title),
              AppText.raw(
                check.detail,
                variant: .caption,
                tone: .secondary,
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
