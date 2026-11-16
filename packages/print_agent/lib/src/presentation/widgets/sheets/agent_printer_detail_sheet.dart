import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/domain/entities/agent_test_print_result.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'agent_printer_remove_button.dart';
import 'agent_test_print_button.dart';

/// Trạng thái máy in trong bảng chi tiết.
enum AgentPrinterDetailState { ready, notReady, paused, stationOff }

/// Thông tin một máy in để xem chi tiết (máy in của máy này hoặc của trạm in
/// khác) — chỉ những gì khách cần: tên, kết nối, IP / MAC, mã, khổ giấy.
class AgentPrinterDetail {
  const AgentPrinterDetail({
    required this.name,
    required this.kind,
    required this.state,
    required this.on,
    this.address,
    this.mac,
    this.id,
    this.paper,
    this.station,
    this.onToggle,
    this.onTestPrint,
    this.onRemove,
    this.settings,
  });

  final String name;

  /// `lan` / `usb` / `builtin`.
  final String kind;
  final AgentPrinterDetailState state;

  /// Đang nhận lệnh in (chưa tạm ngưng).
  final bool on;
  final String? address;
  final String? mac;
  final Object? id;

  /// Tên khổ giấy của app (`size80` / `size58`) hoặc `80mm`.
  final String? paper;

  /// Tên trạm in quản lý máy in này.
  final String? station;

  /// Bật / tắt nhận lệnh; `null` = không đổi được (trạm in đang tắt).
  final VoidCallback? onToggle;

  /// In một phiếu thử ra máy in này; `null` = không in thử được (trạm in
  /// quản lý máy in đang tắt).
  final Future<AgentTestPrintResult> Function()? onTestPrint;

  /// Xoá máy in này khỏi trạm in (`true` = đã xoá); `null` = không xoá được ở đây.
  final Future<bool> Function()? onRemove;

  /// Cài đặt riêng của máy in (app chủ dựng); `null` = không có.
  final Widget? settings;
}

/// "Chi tiết máy in" khi bấm máy in trên sơ đồ: điện thoại mở bảng trượt,
/// máy tính / tablet mở popup. Có công tắc "Nhận lệnh in".
class AgentPrinterDetailSheet extends StatelessWidget {
  const AgentPrinterDetailSheet({super.key, required this.detail});

  final AgentPrinterDetail detail;

  static Future<void> show(AgentPrinterDetail detail) async {
    if (PrintAgentUi.kit.isTablet) {
      await Get.dialog<void>(_Popup(detail: detail));
      return;
    }
    await BaseBottomSheet.show<void>(
      headerTitle: LocaleKeys.printerSetting_agentPrinterDetailTitle,
      body: AgentPrinterDetailSheet(detail: detail),
    );
  }

  static String _paper(String? p) => switch (p) {
    null || '' => '',
    'size58' => '58mm',
    'size80' => '80mm',
    _ => p,
  };

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final (stateText, stateColor) = switch (d.state) {
      AgentPrinterDetailState.ready => (
        LocaleKeys.printerSetting_agentPrinterDetailReady.tr,
        AppColors.successGreen,
      ),
      AgentPrinterDetailState.notReady => (
        LocaleKeys.printerSetting_agentPrinterDetailNotReady.tr,
        AppColors.errorRed,
      ),
      AgentPrinterDetailState.paused => (
        LocaleKeys.printerSetting_agentPrinterOffState.tr,
        AppColors.orange,
      ),
      AgentPrinterDetailState.stationOff => (
        LocaleKeys.printerSetting_agentPrinterDetailStationOff.tr,
        AppColors.dsGray2,
      ),
    };
    final rows = <(String, String)>[
      (
        LocaleKeys.printerSetting_agentPrinterDetailConnection.tr,
        switch (d.kind) {
          'usb' => LocaleKeys.printerSetting_agentPrinterKindUsb.tr,
          'builtin' => LocaleKeys.printerSetting_agentPrinterKindBuiltIn.tr,
          _ => LocaleKeys.printerSetting_agentPrinterKindLan.tr,
        },
      ),
      if ((d.address ?? '').isNotEmpty && d.kind == 'lan')
        (LocaleKeys.printerSetting_agentPrinterDetailIp.tr, d.address!),
      if ((d.mac ?? '').isNotEmpty)
        (LocaleKeys.printerSetting_agentPrinterDetailMac.tr, d.mac!),
      if (d.id != null && '${d.id}'.isNotEmpty)
        (LocaleKeys.printerSetting_agentPrinterDetailId.tr, '${d.id}'),
      if (_paper(d.paper).isNotEmpty)
        (LocaleKeys.printerSetting_agentPrinterDetailPaper.tr, _paper(d.paper)),
      if ((d.station ?? '').isNotEmpty)
        (LocaleKeys.printerSetting_agentPrinterDetailStation.tr, d.station!),
    ];
    return AppPadding.all(
      AppSpace.lg,
      child: AppColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.md,
        children: [
          AppRow(
            spacing: AppSpace.md,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(switch (d.kind) {
                  'usb' => Icons.usb_rounded,
                  'builtin' => Icons.point_of_sale_rounded,
                  _ => Icons.print_rounded,
                }, color: stateColor),
              ),
              Expanded(
                child: AppColumn(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 2,
                  children: [
                    AppText.raw(d.name, variant: .bodyLarge, maxLines: 2),
                    AppRow(
                      spacing: 4,
                      children: [
                        Icon(Icons.circle, size: 8, color: stateColor),
                        AppText.raw(
                          stateText,
                          variant: .caption,
                          textColor: stateColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          BaseCard.section(
            child: AppColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpace.sm,
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const AppDivider(),
                  AppRow(
                    spacing: AppSpace.md,
                    children: [
                      Expanded(
                        child: AppText.raw(
                          rows[i].$1,
                          variant: .body,
                          tone: .secondary,
                        ),
                      ),
                      Flexible(
                        child: SelectableText(
                          rows[i].$2,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (d.settings != null) BaseCard.section(child: d.settings!),
          if (d.onTestPrint != null)
            AgentTestPrintButton(name: d.name, onTestPrint: d.onTestPrint!),
          if (d.onToggle != null)
            BaseCard.section(
              child: AppRow(
                spacing: AppSpace.md,
                children: [
                  const Expanded(
                    child: AppColumn(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 2,
                      children: [
                        AppText(
                          LocaleKeys.printerSetting_agentPrinterDetailReceive,
                          variant: .title,
                        ),
                        AppText(
                          LocaleKeys
                              .printerSetting_agentPrinterDetailReceiveHint,
                          variant: .caption,
                          tone: .secondary,
                        ),
                      ],
                    ),
                  ),
                  BaseCupertinoSwitch(
                    value: d.on,
                    onChanged: (_) {
                      Get.back<void>();
                      d.onToggle!();
                    },
                  ),
                ],
              ),
            ),
          if (d.onRemove != null) AgentPrinterRemoveButton(detail: d),
        ],
      ),
    );
  }
}

/// Popup chi tiết (máy tính / tablet): tiêu đề + nút đóng.
class _Popup extends StatelessWidget {
  const _Popup({required this.detail});

  final AgentPrinterDetail detail;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: AppColors.backgroundPrimary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
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
                    LocaleKeys.printerSetting_agentPrinterDetailTitle,
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
          Flexible(
            child: SingleChildScrollView(
              child: AgentPrinterDetailSheet(detail: detail),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Mở chi tiết rồi thôi (dùng làm `onTap` của nút máy in trên sơ đồ).
VoidCallback agentShowPrinterDetail(AgentPrinterDetail detail) =>
    () => unawaited(AgentPrinterDetailSheet.show(detail));
