import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Tiêu đề sơ đồ + nút làm mới.
class AgentMapHeader extends StatelessWidget {
  const AgentMapHeader({
    super.key,
    required this.isAgent,
    required this.onRefresh,
    this.onArrange,
  });

  final bool isAgent;
  final VoidCallback onRefresh;

  /// Mở "Sắp xếp sơ đồ" (đổi thứ tự Agent / máy in).
  final VoidCallback? onArrange;

  @override
  Widget build(BuildContext context) {
    return AppRow(
      spacing: AppSpace.sm,
      children: [
        Expanded(
          child: AppText(
            isAgent
                ? LocaleKeys.printerSetting_agentMapAgent
                : LocaleKeys.printerSetting_agentMapSender,
            variant: .title,
            maxLines: 2,
          ),
        ),
        // Máy này là trạm in: thêm máy in (hộp chọn / thêm nhanh của app chủ).
        if (isAgent && PrintAgentUi.onAddPrinter != null)
          BaseTap(
            onTap: () => unawaited(PrintAgentUi.onAddPrinter!()),
            child: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primaryBlueBase,
            ),
          ),
        if (onArrange != null)
          BaseTap(
            onTap: onArrange,
            child: const Icon(
              Icons.swap_vert_rounded,
              color: AppColors.primaryBlueBase,
            ),
          ),
        Obx(
          () => PrintAgentUi.station.watchdog.isChecking.value
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : BaseTap(
                  onTap: onRefresh,
                  child: const Icon(
                    Icons.refresh_rounded,
                    color: AppColors.primaryBlueBase,
                  ),
                ),
        ),
      ],
    );
  }
}
