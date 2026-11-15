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

  /// Một dòng trạng thái cho khách: đã kết nối / mất kết nối / đang kết nối
  /// (không hiện tên kênh kỹ thuật — Firebase, MQTT).
  List<AgentMapLine> get lines {
    if (channels.isEmpty) {
      return [
        AgentMapLine(
          LocaleKeys.printerSetting_agentCloudConnecting.tr,
          icon: Icons.cloud_sync_outlined,
        ),
      ];
    }
    final ok = channels.values.any((v) => v);
    return [
      AgentMapLine(
        ok
            ? LocaleKeys.printerSetting_agentCloudOk.tr
            : LocaleKeys.printerSetting_agentCloudDown.tr,
        icon: ok ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
        color: ok ? AppColors.successGreen : AppColors.errorRed,
      ),
    ];
  }

  /// Có kênh thông → xanh; có kênh nhưng rớt hết → đỏ; chưa có kênh → [empty].
  AgentLinkState state({AgentLinkState empty = AgentLinkState.inactive}) =>
      channels.isEmpty
      ? empty
      : (channels.values.any((ok) => ok)
            ? AgentLinkState.connected
            : AgentLinkState.disconnected);
}
