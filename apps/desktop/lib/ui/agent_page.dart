import 'dart:async';

import 'package:flutter/material.dart';

import '../agent/print_agent.dart';
import 'dashboard/agent_job_log_card.dart';
import 'dashboard/agent_settings_card.dart';
import 'dashboard/agent_stats_card.dart';
import 'dashboard/station_toggle_card.dart';
import 'dashboard/agent_map_card.dart';
import 'ds/ds.dart';

/// Màn Máy Agent — cùng bố cục với app EasyPOS:
/// - màn hẹp: một cột (công tắc → sơ đồ → nhật ký → số liệu…);
/// - màn rộng: 2 cột 5 : 6 — trái sơ đồ + nhật ký, phải công tắc / số liệu /
///   cài đặt / Agent khác.
class AgentPage extends StatelessWidget {
  const AgentPage({super.key, required this.agent});

  final PrintAgent agent;

  static const double _twoPaneMinWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        title: const Text(
          'Máy Agent',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: () => unawaited(agent.logout()),
            icon: const Icon(Icons.logout_rounded, size: 20),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: agent,
        builder: (context, _) => LayoutBuilder(
          builder: (context, c) {
            final top = StationToggleCard(agent: agent);
            final map = AppColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: ShareDimens.itemSpacing,
              children: [
                AgentMapCard(agent: agent),
                AgentJobLogCard(agent: agent),
              ],
            );
            final side = <Widget>[
              AgentStatsCard(agent: agent),
              AgentSettingsCard(agent: agent),
            ];
            const pad = EdgeInsets.all(16);
            if (c.maxWidth < _twoPaneMinWidth) {
              return SingleChildScrollView(
                padding: pad,
                child: AppColumn(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: ShareDimens.itemSpacing,
                  // Điện thoại: công tắc → số liệu → sơ đồ + nhật ký → cài đặt.
                  children: [top, side.first, map, ...side.skip(1)],
                ),
              );
            }
            return AppRow(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: ShareDimens.itemSpacing,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: pad.copyWith(right: 0),
                    child: map,
                  ),
                ),
                Expanded(
                  flex: 6,
                  child: SingleChildScrollView(
                    padding: pad.copyWith(left: 0),
                    child: AppColumn(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: ShareDimens.itemSpacing,
                      children: [top, ...side],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
