import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/utils/agent_peer_node.dart';
import 'package:print_agent/src/presentation/utils/agent_peer_printer_toggle.dart';

/// Một máy Agent (khác máy này) trên sơ đồ: thông tin trạm + lúc thấy cuối
/// (`null` = đang trực tuyến).
typedef AgentPeerEntry = ({Map<Object?, Object?> info, DateTime? offlineSince});

/// Mọi Agent đã biết + đang trực tuyến: trực tuyến dùng thông tin mới nhất, đã tắt
/// vẫn hiện (ngoại tuyến + lần thấy cuối). Gọi trong Obx (đọc [KnownAgents]).
List<AgentPeerEntry> agentPeerEntries(List<Map<Object?, Object?>> online) {
  final known = KnownAgents.items.toList();
  // Thứ tự người dùng tự sắp ([AgentMapLayout]) — đọc Rx để Obx theo dõi.
  final order = AgentMapLayout.agents.toList();
  final onlineById = {
    for (final a in online)
      if (a['id'] case final String id) id: a,
  };
  final entries = <AgentPeerEntry>[
    for (final k in known)
      onlineById[k.id] != null
          ? (info: onlineById[k.id]!, offlineSince: null)
          : (info: k.info, offlineSince: k.lastSeenAt),
    for (final a in online)
      if (!known.any((k) => k.id == a['id'])) (info: a, offlineSince: null),
  ];
  return AgentMapLayout.sorted(entries, order, (e) => '${e.info['id']}');
}

/// Agent + các máy in nó đang kết nối (vùng "Máy Agent" trên sơ đồ). [using]
/// (máy bán hàng): máy in tích hợp của Agent đang dùng trên máy này không.
AgentMapCluster agentPeerCluster(AgentPeerEntry e, {bool? using}) =>
    AgentMapCluster(
      agent: agentPeerNode(e.info, offlineSince: e.offlineSince),
      printers: agentPeerPrinterNodes(
        e.info,
        offline: e.offlineSince != null,
        using: using,
      ),
    );

/// Máy in Agent báo: LAN / USB / tích hợp + địa chỉ. Agent tắt: xám (trạng
/// thái lần cuối không còn chắc đúng). Báo có máy in tích hợp mà danh sách
/// chưa có (Agent chưa dò) thì thêm một nút.
List<AgentMapNode> agentPeerPrinterNodes(
  Map<Object?, Object?> info, {
  required bool offline,
  required bool? using,
}) => [
  for (final p in agentPeerPrinterMaps(info))
    _peerPrinterNode(
      p,
      offline: offline,
      using: using,
      // Bấm máy in (Agent đang trực tuyến): bật / tắt nhận lệnh từ xa.
      onTap: offline ? null : agentPeerPrinterToggle(info, p),
    ),
];

/// Máy in Agent [info] báo (kèm máy in tích hợp nếu danh sách chưa có), theo thứ
/// tự người dùng tự sắp ([AgentMapLayout]).
List<Map<Object?, Object?>> agentPeerPrinterMaps(Map<Object?, Object?> info) {
  final printers = info['printers'];
  final names = [
    if (printers is Map && printers['names'] is List)
      for (final p in printers['names'] as List)
        if (p is Map) p,
  ];
  final builtIn = info['builtIn'];
  final all = <Map<Object?, Object?>>[
    if (builtIn is Map && !names.any((p) => p['kind'] == 'builtin'))
      {
        'name': LocaleKeys.printerSetting_agentBuiltInPrinter.tr,
        'kind': 'builtin',
        'ok': builtIn['ready'] != false,
      },
    ...names,
  ];
  final order = AgentMapLayout.printers['${info['id']}'] ?? const <String>[];
  return AgentMapLayout.sorted(all, order, agentPeerPrinterKey);
}

/// Khoá máy in Agent báo (để sắp thứ tự trên sơ đồ).
String agentPeerPrinterKey(Map<Object?, Object?> p) =>
    AgentMapLayout.printerKey(
      kind: p['kind'],
      address: p['addr'],
      name: p['name'],
    );

AgentMapNode _peerPrinterNode(
  Map<Object?, Object?> p, {
  required bool offline,
  required bool? using,
  VoidCallback? onTap,
}) {
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
        AgentMapLine(
          LocaleKeys.printerSetting_agentPrinterOffState.tr,
          icon: Icons.block_rounded,
        ),
      switch (kind) {
        'usb' => const AgentMapLine('USB', icon: Icons.usb_rounded),
        'builtin' => AgentMapLine(
          using == null
              ? LocaleKeys.printerSetting_agentBuiltIn.tr
              : (using
                    ? LocaleKeys.printerSetting_agentBuiltInInUse.tr
                    : LocaleKeys.printerSetting_agentBuiltInNotUsed.tr),
          icon: Icons.point_of_sale_rounded,
        ),
        _ => AgentMapLine(addr, icon: Icons.lan_outlined),
      },
    ],
    state: offline || off
        ? AgentLinkState.inactive
        : (p['ok'] == true
              ? AgentLinkState.connected
              : AgentLinkState.disconnected),
    onTap: onTap,
    // Agent bản cũ: biểu tượng "cần cập nhật" thay cho nút bật / tắt.
    tapIcon: agentPeerIsOldVersion(p)
        ? Icons.system_update_alt_rounded
        : Icons.power_settings_new_rounded,
  );
}
