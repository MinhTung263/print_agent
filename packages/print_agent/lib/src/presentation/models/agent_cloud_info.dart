import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Tên kênh hiển thị: "Firebase" / "MQTT".
String agentChannelName(PrintRelayTransport t) {
  final type = t.runtimeType.toString();
  return type.contains('Mqtt')
      ? 'MQTT'
      : (type.contains('Firebase') ? 'Firebase' : type);
}

/// Trạng thái các kênh đám mây cho nút đám mây trên sơ đồ.
class AgentCloudInfo {
  const AgentCloudInfo(this.channels);

  final Map<String, bool> channels;

  /// Mỗi kênh một dòng: ☁✓ "Firebase" (xanh) / ☁✗ "MQTT" (đỏ).
  List<AgentMapLine> get lines => [
    for (final e in channels.entries)
      AgentMapLine(
        e.key,
        icon: e.value ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
        color: e.value ? AppColors.successGreen : AppColors.errorRed,
      ),
  ];

  /// Có kênh thông → xanh; có kênh nhưng rớt hết → đỏ; chưa có kênh → [empty].
  AgentLinkState state({AgentLinkState empty = AgentLinkState.inactive}) =>
      channels.isEmpty
      ? empty
      : (channels.values.any((ok) => ok)
            ? AgentLinkState.connected
            : AgentLinkState.disconnected);
}
