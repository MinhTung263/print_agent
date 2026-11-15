import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Một máy in tích hợp của máy Agent trong danh sách máy in: tên, Agent trực
/// tuyến hay không, khổ giấy, công tắc bật / tắt (chỉ có bật / tắt — chức năng in
/// theo cài đặt trên máy Agent).
class PeerBuiltInPrinterTile extends StatelessWidget {
  const PeerBuiltInPrinterTile({super.key, required this.printer});

  final PeerBuiltInPrinter printer;

  @override
  Widget build(BuildContext context) {
    final online = PrintAgentUi.station.relay.knownStations.any(
      (s) => s['id'] == printer.stationId,
    );
    return AdaptiveSelectableCard(
      isSelected: false,
      // Chỉ có bật / tắt: bấm thẻ cũng là bật / tắt.
      onTap: () =>
          PeerBuiltInPrinters.setEnabled(printer.stationId, !printer.enabled),
      padding: AppEdgeInsets.symmetric(
        vertical: AppSpace.sm,
        horizontal: AppSpace.lg,
      ),
      child: AppRow(
        spacing: AppSpace.md,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpace.sm),
            decoration: BoxDecoration(
              color: AppColors.dsPrimaryBlue4,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: AppColors.dsPrimaryBlue1,
            ),
          ),
          Expanded(
            child: AppColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                AppText.raw(
                  PeerBuiltInPrinters.displayName(printer),
                  variant: .title,
                  maxLines: 1,
                ),
                AppRow(
                  spacing: 4,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: online
                          ? AppColors.successGreen
                          : AppColors.dsGray2,
                    ),
                    Expanded(
                      child: AppText.raw(
                        [
                          online
                              ? LocaleKeys
                                    .printerSetting_stationBuiltInOnline
                                    .tr
                              : LocaleKeys
                                    .printerSetting_stationBuiltInOfflineState
                                    .tr,
                          printer.is80mm ? '80mm' : '58mm',
                        ].join(' · '),
                        variant: .caption,
                        tone: .secondary,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          BaseCupertinoSwitch(
            value: printer.enabled,
            onChanged: (on) =>
                PeerBuiltInPrinters.setEnabled(printer.stationId, on),
          ),
        ],
      ),
    );
  }
}
