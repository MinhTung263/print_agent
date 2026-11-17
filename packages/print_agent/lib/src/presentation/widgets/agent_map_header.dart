import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'agent_map_header_action.dart';

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
        if (onArrange != null)
          AgentMapHeaderAction(icon: Icons.swap_vert_rounded, onTap: onArrange),
        // Máy Agent: "Thêm máy in" ngay trên sơ đồ (trước đây chỉ có trong hộp đổi tên trạm in).
        if (isAgent && PrintAgentUi.onAddPrinter != null)
          AgentMapHeaderAction(
            icon: Icons.add_rounded,
            onTap: () => unawaited(PrintAgentUi.onAddPrinter!()),
          ),
        // Máy Agent: hiện / ẩn các trạm in khác cùng công ty (mặc định ẩn).
        if (isAgent)
          Obx(
            () => AgentMapHeaderAction(
              icon: AgentPeersVisibility.show.value
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              onTap: () => unawaited(
                AgentPeersVisibility.set(!AgentPeersVisibility.show.value),
              ),
            ),
          ),
        Obx(
          () => AgentMapHeaderAction(
            icon: Icons.refresh_rounded,
            onTap: onRefresh,
            busy: PrintAgentUi.station.watchdog.isChecking.value,
          ),
        ),
      ],
    );
  }
}
