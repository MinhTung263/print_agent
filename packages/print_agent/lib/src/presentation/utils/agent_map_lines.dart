import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/widgets/network_map/agent_map_node.dart';

/// Dòng phụ của máy này: Wi-Fi (biểu tượng Wi-Fi) + IP (biểu tượng mạng LAN).
List<AgentMapLine> agentThisDeviceLines(String? ssid, List<String> ips) => [
  if (ssid != null) AgentMapLine(ssid, icon: Icons.wifi_rounded),
  if (ips.isNotEmpty) AgentMapLine(ips.first, icon: Icons.lan_outlined),
];

String agentSubnetOf(String ip) => ip.split('.').take(3).join('.');
