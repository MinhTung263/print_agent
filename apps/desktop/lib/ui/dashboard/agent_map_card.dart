import 'dart:async';

import 'package:flutter/material.dart';

import '../../agent/print_agent.dart';
import '../agent_map/agent_map_node.dart';
import '../agent_map/agent_network_map.dart';
import 'package:printer_label/desktop.dart';
import '../ds/ds.dart';
import 'agent_rename_dialog.dart';
import 'peer_printers_dialog.dart';

/// Thẻ sơ đồ (giống app): đám mây ↔ máy này (Agent máy tính) ↔ máy in của
/// Agent + các máy Agent khác của cửa hàng. Máy in đang nhận lệnh: vòng sáng + nhãn.
class AgentMapCard extends StatelessWidget {
  const AgentMapCard({super.key, required this.agent});

  final PrintAgent agent;

  @override
  Widget build(BuildContext context) {
    final online = agent.state == AgentState.online;
    final on = agent.state != AgentState.off;
    final config = agent.config;
    return BaseCard.section(
      child: AppColumn(
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.sm,
        children: [
          AppRow(
            spacing: AppSpace.sm,
            children: [
              const Expanded(
                child: AppText(
                  'Máy này đang là Agent — các máy in đang quản lý',
                  variant: .title,
                  maxLines: 2,
                ),
              ),
              if (agent.state == AgentState.connecting)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          AgentNetworkMap(
            cloud: AgentMapNode(
              icon: Icons.cloud_outlined,
              title: 'Đám mây',
              lines: [
                AgentMapLine(
                  'MQTT',
                  icon: online
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color: online ? AppColors.successGreen : AppColors.errorRed,
                ),
              ],
              state: !on
                  ? AgentLinkState.inactive
                  : (online
                        ? AgentLinkState.connected
                        : AgentLinkState.disconnected),
            ),
            center: AgentMapNode(
              icon: Icons.hub_rounded,
              title: agent.label,
              kind: AgentMapNodeKind.agent,
              lines: [
                AgentMapLine(PrintAgent.osName, icon: Icons.computer_rounded),
                if (config.companyName.isNotEmpty)
                  AgentMapLine(
                    config.companyName,
                    icon: Icons.storefront_outlined,
                  ),
              ],
              onTap: () => unawaited(showAgentRenameDialog(context, agent)),
              tapIcon: Icons.edit_rounded,
            ),
            nodes: [
              if (config.hasPrinter)
                AgentMapNode(
                  icon: Icons.print_rounded,
                  title: 'Máy in của Agent',
                  lines: [
                    UsbPrinters.isLocal(config.printer)
                        ? AgentMapLine(
                            UsbPrinters.label(config.printer),
                            icon: Icons.usb_rounded,
                          )
                        : AgentMapLine(
                            config.printer,
                            icon: Icons.lan_outlined,
                          ),
                    AgentMapLine(
                      'Khổ ${config.paper.pageMm}mm',
                      icon: Icons.receipt_long_rounded,
                    ),
                  ],
                  state: !on
                      ? AgentLinkState.inactive
                      : (agent.printerOk == false
                            ? AgentLinkState.disconnected
                            : AgentLinkState.connected),
                  activity: _activity(agent.activity),
                  // Bấm máy in: in thử.
                  onTap: () => unawaited(_printTest(context)),
                  tapIcon: Icons.print_rounded,
                ),
            ],
            nodesLabel: 'Máy in của máy này',
            // Vùng máy Agent khác: mỗi Agent + các máy in nó đang kết nối.
            clusters: [for (final p in agent.peers) _peerCluster(context, p)],
            clustersLabel:
                'Máy Agent khác trong công ty (${agent.peers.length})',
          ),
        ],
      ),
    );
  }

  Future<void> _printTest(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await agent.printTest();
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Đã gửi phiếu in thử')),
    );
  }

  AgentMapCluster _peerCluster(BuildContext context, Map<Object?, Object?> s) {
    final printers = s['printers'];
    final names = [
      if (printers is Map && printers['names'] is List)
        for (final p in printers['names'] as List)
          if (p is Map) p,
    ];
    final ok = printers is Map && printers['ok'] is int
        ? printers['ok'] as int
        : 0;
    final total = printers is Map && printers['total'] is int
        ? printers['total'] as int
        : 0;
    return AgentMapCluster(
      agent: AgentMapNode(
        icon: Icons.hub_rounded,
        kind: AgentMapNodeKind.agent,
        title: peerLabel(s),
        lines: [
          if (total > 0)
            AgentMapLine(
              '$ok/$total máy in đang kết nối',
              icon: Icons.print_rounded,
              color: ok == total
                  ? AppColors.successGreen
                  : (ok == 0 ? AppColors.errorRed : AppColors.orange),
            ),
          if (s['model'] != null)
            AgentMapLine('${s['model']}', icon: Icons.devices_rounded),
        ],
        onTap: () =>
            unawaited(showPeerPrintersDialog(context, s, agent: agent)),
        tapIcon: Icons.list_rounded,
      ),
      printers: [for (final p in names) _peerPrinterNode(p)],
    );
  }

  static AgentMapActivity? _activity(AgentPrintActivity? a) {
    if (a == null) return null;
    final sender = a.sender?.trim() ?? '';
    return AgentMapActivity(
      label: switch (a.phase) {
        AgentPrintPhase.printing => 'Đang in hoá đơn',
        AgentPrintPhase.done => 'Đã in',
        AgentPrintPhase.failed => 'In lỗi',
      },
      color: switch (a.phase) {
        AgentPrintPhase.printing => AppColors.primaryBlueBase,
        AgentPrintPhase.done => AppColors.successGreen,
        AgentPrintPhase.failed => AppColors.errorRed,
      },
      icon: switch (a.phase) {
        AgentPrintPhase.printing => Icons.print_rounded,
        AgentPrintPhase.done => Icons.check_rounded,
        AgentPrintPhase.failed => Icons.close_rounded,
      },
      pulsing: a.phase == AgentPrintPhase.printing,
      sender: sender.isEmpty ? null : 'Từ $sender',
    );
  }
}

/// "Quầy bar · #A3F9" — tên + 4 ký tự cuối mã Agent (giống app).
String peerLabel(Map<Object?, Object?> s) {
  final name = s['name']?.toString().trim() ?? '';
  final id = s['id']?.toString() ?? '';
  final shown = name.isEmpty ? 'Máy Agent' : name;
  if (id.isEmpty) return shown;
  final tail = id.length <= 4 ? id : id.substring(id.length - 4);
  return '$shown · #${tail.toUpperCase()}';
}

/// Máy in của Agent đó: LAN / USB / tích hợp + địa chỉ, xanh kết nối được,
/// đỏ mất kết nối, xám đã tắt nhận lệnh.
AgentMapNode _peerPrinterNode(Map<Object?, Object?> p) {
  final kind = p['kind'];
  final addr = p['addr']?.toString() ?? '';
  final off = p['on'] == false;
  return AgentMapNode(
    icon: switch (kind) {
      'usb' => Icons.usb_rounded,
      'builtin' => Icons.point_of_sale_rounded,
      _ => Icons.print_rounded,
    },
    title: p['name']?.toString() ?? '',
    lines: [
      if (off)
        const AgentMapLine('Đã tắt nhận lệnh', icon: Icons.block_rounded),
      switch (kind) {
        'usb' => const AgentMapLine('USB', icon: Icons.usb_rounded),
        'builtin' => const AgentMapLine(
          'Máy in tích hợp',
          icon: Icons.point_of_sale_rounded,
        ),
        _ => AgentMapLine(addr, icon: Icons.lan_outlined),
      },
    ],
    state: off
        ? AgentLinkState.inactive
        : (p['ok'] == true
              ? AgentLinkState.connected
              : AgentLinkState.disconnected),
  );
}
