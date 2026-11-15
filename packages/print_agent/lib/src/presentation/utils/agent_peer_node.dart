import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_peer_printers_sheet.dart';

/// Nút một máy Agent (khác máy này) trên sơ đồ — dùng chung cho sơ đồ máy bán
/// hàng và sơ đồ máy Agent (thấy các Agent khác trong công ty):
/// - trực tuyến: xanh, "2/3 máy in đang kết nối" + có máy in tích hợp / sẵn sàng;
/// - [offlineSince] khác `null` (Agent đã tắt): đỏ, "Ngoại tuyến · lần cuối …".
/// Bấm nút → xem các máy in Agent đó đang kết nối ([AgentPeerPrintersSheet]).
AgentMapNode agentPeerNode(
  Map<Object?, Object?> station, {
  DateTime? offlineSince,
}) {
  final offline = offlineSince != null;
  return AgentMapNode(
    icon: Icons.hub_rounded,
    // Khối vuông tím + nhãn "Agent", hàng riêng — không nhầm với máy in.
    kind: AgentMapNodeKind.agent,
    // "Quầy bar · #A3F9": tên + mã ngắn — 2 Agent cùng loại vẫn phân biệt được.
    title: AgentIdentity.ofStation(station),
    state: offline ? AgentLinkState.disconnected : AgentLinkState.connected,
    onTap: () => AgentPeerPrintersSheet.show(station, lastSeen: offlineSince),
    tapIcon: Icons.list_rounded,
    // Agent tắt: chỉ "Ngoại tuyến · lần cuối …" (số máy in cũ không còn đúng).
    lines: offline
        ? [
            AgentMapLine(
              LocaleKeys.printerSetting_agentOfflineSinceTr(
                time: formatAgentTime(offlineSince, pattern: 'HH:mm dd/MM'),
              ),
              icon: Icons.cloud_off_rounded,
              color: AppColors.errorRed,
            ),
          ]
        : [
            // "2/3 máy in đang kết nối" — Agent bản cũ chưa báo thì bỏ qua.
            ?agentPrintersLine(station),
            station['builtIn'] is Map
                ? AgentMapLine(
                    LocaleKeys.printerSetting_agentHasBuiltIn.tr,
                    icon: Icons.point_of_sale_rounded,
                  )
                : AgentMapLine(
                    LocaleKeys.printerSetting_agentStandby.tr,
                    icon: Icons.check_circle_outline_rounded,
                  ),
          ],
  );
}

/// Số máy in Agent đang kết nối được: xanh khi đủ, cam khi thiếu, đỏ khi không
/// máy nào kết nối. `null` khi Agent chưa báo (bản cũ) / chưa có máy in.
AgentMapLine? agentPrintersLine(Map<Object?, Object?> station) {
  final info = station['printers'];
  if (info is! Map) return null;
  final ok = info['ok'] is int ? info['ok'] as int : 0;
  final total = info['total'] is int ? info['total'] as int : 0;
  if (total == 0) return null;
  return AgentMapLine(
    LocaleKeys.printerSetting_agentPrintersConnectedTr(
      ok: '$ok',
      total: '$total',
    ),
    icon: Icons.print_rounded,
    color: ok == total
        ? AppColors.successGreen
        : (ok == 0 ? AppColors.errorRed : AppColors.orange),
  );
}
