import 'dart:io';
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:printer_label/printer_label.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';

/// Công tắc "Dùng máy này làm trạm in": thiết bị khác mạng / dùng 4G gửi lệnh
/// in qua trạm, máy này (cùng mạng / cắm USB với máy in) in hộ.
class PrintStationToggle extends StatelessWidget {
  const PrintStationToggle({super.key});

  Future<void> _onChanged(bool value) async {
    String? otherApp;
    final ok = await PrintAgentUi.station.setEnabled(
      value,
      onOtherApp: (app) => otherApp = app,
    );
    if (otherApp case final app?) {
      // Bản app khác trên máy này đang làm Agent (chung mã Agent theo máy).
      await AppNotification.show(
        message: LocaleKeys.printerSetting_agentOtherAppIsAgentTr(
          app: AgentIdentity.appLabel(app),
        ),
        type: AppNotificationType.warning,
        duration: const Duration(seconds: 8),
      );
      return;
    }
    if (!ok) {
      await AppNotification.show(
        message: LocaleKeys.printerSetting_printStationUnavailable,
        type: AppNotificationType.error,
      );
      return;
    }
    // Máy Agent cần tự mở lại app khi bật máy / bị hệ thống tắt — Android 10+
    // phải có quyền "Hiển thị trên ứng dụng khác".
    if (value && Platform.isAndroid && !await PrinterLabel.canAutoRestart()) {
      unawaited(
        AppNotification.show(
          message: LocaleKeys.printerSetting_agentAutoRestartPermission,
          type: AppNotificationType.warning,
          duration: const Duration(seconds: 10),
          trailing: BaseTap(
            onTap: () {
              AppNotification.dismiss();
              unawaited(PrinterLabel.requestAutoRestart());
            },
            child: const AppPadding.symmetric(
              horizontal: AppSpace.md,
              vertical: AppSpace.sm,
              child: AppText(
                LocaleKeys.printerSetting_agentGrantPermission,
                variant: .title,
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseCard.section(
      child: AppColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: AppDimens.paddingSmallest,
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: PrintAgentUi.station.relay.isStation,
            builder: (_, isStation, _) => BaseCupertinoSwitch(
              leftLabel: LocaleKeys.printerSetting_printStationToggle,
              fontWeight: FontWeight.bold,
              mainAxisSize: MainAxisSize.max,
              value: isStation,
              onChanged: _onChanged,
            ),
          ),
          const AppText(
            LocaleKeys.printerSetting_printStationHint,
            textColor: AppColors.dsGray2,
            maxLines: 3,
            variant: .caption,
          ),
          // Máy đang làm Agent cho công ty khác (đổi công ty xem báo cáo...):
          // không tự bật ở đây — bật là chuyển trạm in sang công ty này.
          ValueListenableBuilder<bool>(
            valueListenable: PrintAgentUi.station.relay.isStation,
            builder: (_, isStation, _) =>
                !isStation && PrintAgentUi.station.boundElsewhere
                ? const AppText(
                    LocaleKeys.printerSetting_agentBoundElsewhere,
                    textColor: AppColors.orange,
                    maxLines: 3,
                    variant: .caption,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
