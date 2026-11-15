import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_forget_button.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_remove_button.dart';

/// Bấm vào một máy Agent KHÁC (thẻ "Máy Agent khác" / nút Agent trên sơ đồ):
/// xem các máy in Agent đó đang quản lý — tên, loại (LAN / USB / tích hợp), IP,
/// kết nối được không. Cập nhật ngay khi Agent đó báo lại (máy in đổi, Agent
/// bật / tắt). Agent đang tắt: hiện danh sách lần cuối thấy + thời điểm.
class AgentPeerPrintersSheet extends StatelessWidget {
  const AgentPeerPrintersSheet({
    super.key,
    required this.stationId,
    required this.fallback,
    this.lastSeen,
  });

  final String stationId;

  /// Thông tin đang có lúc mở (dùng khi Agent không còn trong danh sách nào).
  final Map<Object?, Object?> fallback;
  final DateTime? lastSeen;

  static Future<void> show(
    Map<Object?, Object?> station, {
    DateTime? lastSeen,
  }) async {
    final id = station['id'];
    if (id is! String || id.isEmpty) return;
    await BaseBottomSheet.show<void>(
      headerTitle: LocaleKeys.printerSetting_agentPeerPrintersTitle,
      body: AgentPeerPrintersSheet(
        stationId: id,
        fallback: station,
        lastSeen: lastSeen,
      ),
      allowOffline: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final relay = PrintAgentUi.station.relay;
    return ValueListenableBuilder<List<Map<Object?, Object?>>>(
      valueListenable: relay.stations,
      builder: (_, online, _) => Obx(() {
        // Đọc danh sách Rx trước để Obx luôn theo dõi.
        final known = KnownAgents.items.firstWhereOrNull(
          (k) => k.id == stationId,
        );
        final live = online.firstWhereOrNull((s) => s['id'] == stationId);
        final info = live ?? known?.info ?? fallback;
        final seen = known?.lastSeenAt ?? lastSeen ?? DateTime.now();
        return SingleChildScrollView(
          padding: AppEdgeInsets.all(AppSpace.lg),
          child: _Body(info: info, online: live != null, lastSeen: seen),
        );
      }),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.info,
    required this.online,
    required this.lastSeen,
  });

  final Map<Object?, Object?> info;
  final bool online;
  final DateTime lastSeen;

  @override
  Widget build(BuildContext context) {
    final printers = info['printers'];
    final ok = printers is Map && printers['ok'] is int
        ? printers['ok'] as int
        : 0;
    final total = printers is Map && printers['total'] is int
        ? printers['total'] as int
        : 0;
    final names = [
      if (printers is Map && printers['names'] is List)
        for (final p in printers['names'] as List)
          if (p is Map) p,
    ];
    final builtIn = info['builtIn'];
    // Agent có máy in tích hợp nhưng chưa có trong danh sách (Agent chưa dò
    // máy in nào) — vẫn hiện thành một dòng.
    final builtInListed = names.any((p) => p['kind'] == 'builtin');
    final more = total - names.length;
    final timeText = formatAgentTime(lastSeen, pattern: 'HH:mm dd/MM');
    return AppColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.md,
      children: [
        _Header(
          info: info,
          online: online,
          summary: online && total > 0
              ? LocaleKeys.printerSetting_agentPrintersConnectedTr(
                  ok: '$ok',
                  total: '$total',
                )
              : null,
          offlineText: online
              ? null
              : LocaleKeys.printerSetting_agentOfflineSinceTr(time: timeText),
        ),
        if (!online && (names.isNotEmpty || builtIn is Map))
          AppText.raw(
            LocaleKeys.printerSetting_agentPeerOfflineHintTr(time: timeText),
            variant: .caption,
            tone: .secondary,
          ),
        if (names.isEmpty && builtIn is! Map)
          AppText.raw(
            LocaleKeys.printerSetting_agentPeerNoPrinters.tr,
            variant: .body,
            tone: .secondary,
          )
        else
          BaseCard.section(
            child: AppColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpace.sm,
              children: [
                if (builtIn is Map && !builtInListed)
                  AgentPeerPrinterRow(
                    printer: {
                      'name': LocaleKeys.printerSetting_agentBuiltInPrinter.tr,
                      'kind': 'builtin',
                      'ok': builtIn['ready'] != false,
                    },
                    paper: builtIn['paper'],
                    online: online,
                  ),
                for (var i = 0; i < names.length; i++) ...[
                  if (i > 0 || (builtIn is Map && !builtInListed))
                    const AppDivider(),
                  AgentPeerPrinterRow(
                    printer: names[i],
                    paper: names[i]['kind'] == 'builtin' && builtIn is Map
                        ? builtIn['paper']
                        : null,
                    online: online,
                  ),
                ],
              ],
            ),
          ),
        if (more > 0)
          AppText.raw(
            LocaleKeys.printerSetting_agentPeerMoreTr(count: '$more'),
            variant: .caption,
            tone: .secondary,
          ),
        // Agent đã tắt (thôi dùng / mã cũ): quên trên máy này.
        if (!online) AgentForgetButton(station: info),
        // Đang trực tuyến mà không có máy in nào: cho xoá (tắt Agent từ xa).
        if (online && AgentIdentity.hasNoPrinters(info))
          AgentRemoveButton(station: info),
      ],
    );
  }
}

/// Tên + mã Agent, trực tuyến (số máy in kết nối) / ngoại tuyến (lần cuối).
class _Header extends StatelessWidget {
  const _Header({
    required this.info,
    required this.online,
    required this.summary,
    required this.offlineText,
  });

  final Map<Object?, Object?> info;
  final bool online;
  final String? summary;
  final String? offlineText;

  @override
  Widget build(BuildContext context) {
    final color = online ? AppColors.successGreen : AppColors.errorRed;
    return AppRow(
      spacing: AppSpace.sm,
      children: [
        AgentDeviceAvatar(online: online, size: 44),
        Expanded(
          child: AppColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              AppRow(
                spacing: AppSpace.xs,
                children: [
                  Flexible(
                    child: AppText.raw(
                      AgentIdentity.ofStation(info),
                      variant: .title,
                      maxLines: 2,
                    ),
                  ),
                  const AgentTag(),
                ],
              ),
              AppText.raw(
                offlineText ??
                    [
                      LocaleKeys.printerSetting_agentPeerOnline.tr,
                      ?summary,
                    ].join(' · '),
                variant: .caption,
                tone: .secondary,
                textColor: online ? null : AppColors.errorRed,
                maxLines: 2,
              ),
            ],
          ),
        ),
        Icon(
          online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
          color: color,
          size: 20,
        ),
      ],
    );
  }
}
