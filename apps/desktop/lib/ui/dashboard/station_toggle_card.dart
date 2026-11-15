import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../../agent/print_agent.dart';
import '../ds/ds.dart';

/// Công tắc "Dùng máy này làm máy Agent" (giống app) + mô tả.
class StationToggleCard extends StatelessWidget {
  const StationToggleCard({super.key, required this.agent});

  final PrintAgent agent;

  @override
  Widget build(BuildContext context) {
    final on = agent.state != AgentState.off;
    return BaseCard.section(
      child: AppColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.xs,
        children: [
          AppRow(
            children: [
              const Expanded(
                child: Text(
                  'Dùng máy này làm máy Agent',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              CupertinoSwitch(
                value: on,
                activeTrackColor: AppColors.primaryBlueBase,
                onChanged: (v) => unawaited(v ? agent.start() : agent.stop()),
              ),
            ],
          ),
          const AppText(
            'Thiết bị khác wifi hoặc dùng 4G sẽ in qua máy này. Máy tính gửi lệnh '
            'thẳng tới máy in LAN — không cần cài driver máy in.',
            variant: .caption,
            textColor: AppColors.dsGray2,
            maxLines: 3,
          ),
        ],
      ),
    );
  }
}
