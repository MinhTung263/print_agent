import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:printer_label/printer_label.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/presentation/utils/agent_printer_issue.dart';

/// "Bác sĩ trạm in": tự kiểm tra các điều kiện để trạm in nhận và in được
/// phiếu, nói bằng lời dễ hiểu cái gì đang ổn / cần xem — nhận phiếu qua
/// Internet, trong mạng quán, máy in sẵn sàng, vai trò trạm chính / dự phòng.
/// Không hiện IP / tên kênh kỹ thuật.
class AgentDoctorCard extends StatefulWidget {
  const AgentDoctorCard({super.key, required this.cloud});

  /// Trạng thái các kênh Internet (màn Trạm in theo dõi sẵn).
  final AgentCloudInfo cloud;

  @override
  State<AgentDoctorCard> createState() => _AgentDoctorCardState();
}

class _AgentDoctorCardState extends State<AgentDoctorCard>
    with WidgetsBindingObserver {
  /// Android: ứng dụng đã được miễn "tối ưu hoá pin" chưa (chưa thì hệ điều hành có thể dừng
  /// trạm in khi tắt màn hình). Nơi khác luôn `true`.
  bool _batteryOk = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_refreshBattery());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Người dùng đổi cài đặt pin rồi quay lại app: kiểm tra lại.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshBattery());
  }

  Future<void> _refreshBattery() async {
    final ok = await PrinterLabel.isIgnoringBatteryOptimizations();
    if (mounted && ok != _batteryOk) setState(() => _batteryOk = ok);
  }

  @override
  Widget build(BuildContext context) {
    final cloud = widget.cloud;
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
        final printerIssue = active.any(AgentPrinterIssue.isIssue);
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
          if (Platform.isAndroid && !_batteryOk)
            _Check(
              title: LocaleKeys.printerSetting_agentDoctorBackground,
              detail: LocaleKeys.printerSetting_agentDoctorBackgroundFix.tr,
              state: _State.warn,
              onTap: () =>
                  unawaited(PrinterLabel.openBatteryOptimizationSettings()),
            ),
          if (Platform.isIOS)
            _Check(
              title: LocaleKeys.printerSetting_agentDoctorKeepOpen,
              detail: LocaleKeys.printerSetting_agentDoctorKeepOpenHint.tr,
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
    this.onTap,
  });

  final String title;
  final String detail;
  final _State state;

  /// Bấm vào dòng để xử lý ngay (VD mở cài đặt pin).
  final VoidCallback? onTap;
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
    final row = AppRow(
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
    return check.onTap == null ? row : InkWell(onTap: check.onTap, child: row);
  }
}
