import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/presentation/pages/agent_page.dart';

/// Nút "Máy Agent" trên thanh tiêu đề màn Cài đặt in — chấm xanh khi máy này
/// đang là Agent.
class AgentAppBarButton extends StatelessWidget {
  const AgentAppBarButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: PrintAgentUi.station.relay.isStation,
      builder: (_, isAgent, _) => BaseTap(
        onTap: () => unawaited(AgentPage.show()),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.hub_rounded, color: AppColors.primaryBlueBase),
              if (isAgent)
                const Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(
                    Icons.circle,
                    size: 9,
                    color: AppColors.successGreen,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
