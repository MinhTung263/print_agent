import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/presentation/utils/agent_peer_cluster.dart';

/// Máy bán hàng: đám mây ↔ máy này ↔ các máy Agent của công ty (dự phòng).
class SenderAgentsMap extends StatelessWidget {
  const SenderAgentsMap({
    super.key,
    required this.ssid,
    required this.ips,
    required this.cloud,
    required this.agents,
  });

  final String? ssid;
  final List<String> ips;
  final AgentCloudInfo cloud;
  final List<Map<Object?, Object?>> agents;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Máy in tích hợp của Agent đang dùng trên máy này (đọc Rx trước — app
      // chủ đọc danh sách Rx của mình trong hàm này).
      final usingIds = PeerBuiltInPrinters.enabledStationIds();
      // Mọi Agent đã từng thấy (đang bật / đã tắt) + máy in của từng Agent.
      final entries = agentPeerEntries(agents);
      return AgentNetworkMap(
        cloud: AgentMapNode(
          icon: Icons.cloud_outlined,
          title: LocaleKeys.printerSetting_agentCloud.tr,
          lines: cloud.lines,
          state: cloud.state(),
        ),
        center: AgentMapNode(
          icon: Icons.devices_rounded,
          title: LocaleKeys.printerSetting_agentThisDevice.tr,
          lines: agentThisDeviceLines(ssid, ips),
        ),
        // Máy này là gốc, nối thẳng tới từng Agent → máy in của Agent đó.
        linkClusters: true,
        clusters: [
          for (final e in entries)
            agentPeerCluster(e, using: usingIds.contains(e.info['id'])),
        ],
        clustersLabel: LocaleKeys.printerSetting_agentZoneCompanyAgentsTr(
          count: '${entries.length}',
        ),

        emptyText: LocaleKeys.printerSetting_agentNoAgentHint.tr,
      );
    });
  }
}
