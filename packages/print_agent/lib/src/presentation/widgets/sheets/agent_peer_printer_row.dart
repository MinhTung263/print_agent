import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Một máy in: biểu tượng loại + tên + IP / khổ giấy + trạng thái. Agent đang
/// tắt: trạng thái là lần cuối, hiện màu xám (không còn chắc đúng).
class AgentPeerPrinterRow extends StatelessWidget {
  const AgentPeerPrinterRow({
    super.key,
    required this.printer,
    required this.paper,
    required this.online,
  });

  final Map<Object?, Object?> printer;
  final Object? paper;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final ok = printer['ok'] == true;
    final kind = printer['kind'];
    final addr = printer['addr']?.toString() ?? '';
    final sub = [
      switch (kind) {
        'usb' => 'USB',
        'builtin' => LocaleKeys.printerSetting_agentBuiltInPrinter.tr,
        _ => 'LAN',
      },
      if (addr.isNotEmpty) addr,
      if (paper != null) paper == 'size80' ? '80mm' : '58mm',
    ].join(' · ');
    final name = printer['name']?.toString() ?? '';
    // Agent đã tắt nhận lệnh cho máy in này.
    final off = printer['on'] == false;
    final color = !online || off
        ? AppColors.dsGray2
        : (ok ? AppColors.successGreen : AppColors.errorRed);
    final state = off
        ? LocaleKeys.printerSetting_agentPeerPrinterOff.tr
        : (ok
              ? LocaleKeys.printerSetting_agentPeerPrinterOk.tr
              : LocaleKeys.printerSetting_agentPeerPrinterFail.tr);
    return AppRow(
      spacing: AppSpace.sm,
      children: [
        // Máy in: vòng tròn xám (máy Agent là khối vuông tím).
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.backgroundPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            switch (kind) {
              'usb' => Icons.usb_rounded,
              'builtin' => Icons.point_of_sale_rounded,
              _ => Icons.print_rounded,
            },
            size: 20,
            color: AppColors.dsGray2,
          ),
        ),
        Expanded(
          child: AppColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              AppText.raw(
                name.isEmpty
                    ? LocaleKeys.printerSetting_agentPeerPrinterUnknown.tr
                    : name,
                variant: .title,
                maxLines: 1,
              ),
              AppText.raw(
                sub,
                variant: .caption,
                tone: .secondary,
                maxLines: 1,
              ),
            ],
          ),
        ),
        AppRow(
          mainAxisSize: MainAxisSize.min,
          spacing: 4,
          children: [
            Icon(Icons.circle, size: 8, color: color),
            AppText.raw(
              state,
              variant: .caption,
              textColor: color,
              maxLines: 1,
            ),
          ],
        ),
      ],
    );
  }
}
