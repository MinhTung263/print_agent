import 'package:flutter/material.dart';

import '../../agent/print_agent.dart';
import '../ds/ds.dart';

/// Số liệu (giống app): "Đã in hộ X lệnh · lỗi Y", lệnh gần nhất, trạng thái.
class AgentStatsCard extends StatelessWidget {
  const AgentStatsCard({super.key, required this.agent});

  final PrintAgent agent;

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final last = agent.lastJobAt;
    final (status, color) = switch (agent.state) {
      AgentState.online => ('Đang nhận lệnh in', AppColors.successGreen),
      AgentState.connecting => ('Đang kết nối…', AppColors.orange),
      AgentState.offline => ('Mất kết nối · đang thử lại', AppColors.errorRed),
      AgentState.off => ('Đã tắt', AppColors.dsGray5),
    };
    return BaseCard.section(
      child: AppColumn(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.xs,
        children: [
          AppText(
            'Đã in hộ ${agent.printed} lệnh · lỗi ${agent.failed}',
            variant: .title,
          ),
          if (last != null)
            AppText(
              'Lệnh gần nhất lúc ${_time(last)}',
              variant: .caption,
              tone: .secondary,
            ),
          AppRow(
            spacing: 6,
            children: [
              Icon(Icons.circle, size: 8, color: color),
              AppText(status, variant: .caption, textColor: color),
            ],
          ),
        ],
      ),
    );
  }
}
