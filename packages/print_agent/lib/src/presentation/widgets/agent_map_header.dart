import 'package:flutter/material.dart';
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
