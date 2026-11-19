import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/domain/entities/agent_test_print_result.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';
import 'package:print_agent/src/presentation/widgets/routing/agent_printer_functions.dart';

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
    this.footerAction,
    this.onReconnect,
    this.onSwitchNetwork,
    this.functionsEditable = false,
    this.usbUnsupported = false,
    this.routingName,
    this.isLabelPrinter,
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

  /// Nút của app chủ đặt cùng hàng với "Xoá máy in" ở chân chi tiết (VD "In thử"); `null` = không có.
  final Widget? footerAction;

  /// "Kết nối lại" máy in đang lỗi (mở bảng kết nối lại, `true` = đã kết nối được); `null` =
  /// máy in không lỗi / không kết nối lại được ở đây.
  final Future<bool> Function()? onReconnect;

  /// "Đổi mạng": máy in LAN ở mạng khác — chuyển sang đúng Wi-Fi của máy in; `null` = không có.
  final Future<bool> Function()? onSwitchNetwork;

  /// Máy in của máy này: cho chọn chức năng in (Tạm tính, Thanh toán...) ngay trong chi tiết
  /// khi app chủ nối kho cấu hình ([PrintAgentUi.printRouting]).
  final bool functionsEditable;

  /// Máy in USB nhưng thiết bị này (iOS) không in USB được: hiện cảnh báo.
  final bool usbUnsupported;

  /// Tên máy in này trong danh sách máy in của cửa hàng; `null` = chưa có trong cửa hàng.
  final String? routingName;

  /// Máy in tem (`true`): chỉ chọn được chức năng "Tem nhãn"; `null` = chưa rõ.
  final bool? isLabelPrinter;
}

/// "Chi tiết máy in" khi bấm máy in trên sơ đồ: điện thoại mở bảng trượt,
/// máy tính / tablet mở popup. Có công tắc "Nhận lệnh in".
class AgentPrinterDetailSheet extends StatelessWidget {
  const AgentPrinterDetailSheet({
    super.key,
    required this.detail,
    this.footerInline = true,
  });

  final AgentPrinterDetail detail;

  /// `true`: hàng nút ở chân nằm cuối nội dung (bảng trượt trên điện thoại). `false`: nơi dựng
  /// tự đặt [AgentPrinterDetailFooter] cố định bên dưới vùng cuộn (popup máy tính / tablet).
  final bool footerInline;

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
          // Máy in đang lỗi: kết nối lại ngay tại đây (đóng chi tiết rồi mở bảng kết nối lại).
          if (d.state == AgentPrinterDetailState.notReady &&
              (d.onReconnect != null || d.onSwitchNetwork != null))
            AppRow(
              spacing: AppSpace.sm,
              children: [
                if (d.onReconnect != null)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.refresh_rounded,
                      label: LocaleKeys.printerSetting_agentReconnect,
                      filled: true,
                      onTap: () {
                        Get.back<void>();
                        unawaited(d.onReconnect!());
                      },
                    ),
                  ),
                if (d.onSwitchNetwork != null)
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.wifi_rounded,
                      label: LocaleKeys.printerSetting_agentSwitchNetwork,
                      onTap: () {
                        Get.back<void>();
                        unawaited(d.onSwitchNetwork!());
                      },
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
          if (d.usbUnsupported)
            const BaseCard.section(
              child: AppText(
                LocaleKeys.printerSetting_printerUsbUnsupported,
                variant: .body,
                tone: .secondary,
                maxLines: 5,
              ),
            ),
          if (d.functionsEditable &&
              PrintAgentUi.printRouting != null &&
              d.routingName == null)
            const BaseCard.section(
              child: AppText(
                LocaleKeys.printerSetting_printerFunctionsNotInStore,
                variant: .caption,
                tone: .secondary,
                maxLines: 4,
              ),
            ),
          if (d.functionsEditable &&
              PrintAgentUi.printRouting != null &&
              d.routingName != null)
            BaseCard.section(
              child: AgentPrinterFunctions(
                store: PrintAgentUi.printRouting!,
                printerName: d.routingName!,
                isLabelPrinter: d.isLabelPrinter == true,
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
          if (footerInline && AgentPrinterDetailFooter.has(d))
            AgentPrinterDetailFooter(detail: d),
        ],
      ),
    );
  }
}

/// Nút hành động ở đầu chi tiết máy in (Kết nối lại / Đổi mạng).
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;

  /// Khoá chuỗi đa ngôn ngữ.
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => BaseTap(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: filled ? AppColors.primaryBlueBase : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryBlueBase),
      ),
      child: AppRow(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: AppSpace.xs,
        children: [
          Icon(
            icon,
            size: 18,
            color: filled ? Colors.white : AppColors.primaryBlueBase,
          ),
          AppText(
            label,
            variant: .title,
            textColor: filled ? Colors.white : AppColors.primaryBlueBase,
          ),
        ],
      ),
    ),
  );
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
              child: AgentPrinterDetailSheet(
                detail: detail,
                footerInline: false,
              ),
            ),
          ),
          // Hàng nút (In thử · Xoá máy in) luôn nằm dưới cùng, không trôi theo vùng cuộn.
          if (AgentPrinterDetailFooter.has(detail))
            AppPadding.all(
              AppSpace.lg,
              child: AgentPrinterDetailFooter(detail: detail),
            ),
        ],
      ),
    ),
  );
}

/// Mở chi tiết rồi thôi (dùng làm `onTap` của nút máy in trên sơ đồ).
VoidCallback agentShowPrinterDetail(AgentPrinterDetail detail) =>
    () => unawaited(AgentPrinterDetailSheet.show(detail));

/// Hàng nút ở chân chi tiết máy in: nút của app chủ (VD "In thử") và "Xoá máy in", chia đều một hàng.
class AgentPrinterDetailFooter extends StatelessWidget {
  const AgentPrinterDetailFooter({super.key, required this.detail});

  final AgentPrinterDetail detail;

  static bool has(AgentPrinterDetail d) =>
      d.onRemove != null || d.footerAction != null;

  @override
  Widget build(BuildContext context) {
    final action = detail.footerAction;
    return AppRow(
      spacing: AppSpace.md,
      children: [
        if (action != null) Expanded(child: action),
        if (detail.onRemove != null)
          Expanded(child: AgentPrinterRemoveButton(detail: detail)),
      ],
    );
  }
}
