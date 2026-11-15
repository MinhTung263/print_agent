import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_name_sheet.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/utils/agent_peer_cluster.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_printer_detail_sheet.dart';

/// Máy này là Agent: đám mây ↔ máy này ↔ các máy in Agent quản lý.
class AgentPrintersMap extends StatelessWidget {
  const AgentPrintersMap({
    super.key,
    required this.ssid,
    required this.ips,
    required this.cloud,
  });

  final String? ssid;
  final List<String> ips;
  final AgentCloudInfo cloud;

  @override
  Widget build(BuildContext context) {
    final relay = PrintAgentUi.station.relay;
    final watchdog = PrintAgentUi.station.watchdog;
    final subnets = ips.map(agentSubnetOf).toSet();
    // Agent khác bật / tắt → nút của nó trên sơ đồ đổi ngay.
    return ValueListenableBuilder<List<Map<Object?, Object?>>>(
      valueListenable: relay.stations,
      builder: (_, online, _) => Obx(() {
        // Đọc trước (Obx theo dõi): lệnh in hộ đang chạy / vừa xong.
        final activities = AgentPrintActivityStore.items.toList();
        final off = AgentPrinterSwitches.off.toSet();
        final service = PrintAgentUi.station;
        // Các Agent KHÁC (đang bật / đã tắt) + máy in của từng Agent — vùng riêng.
        final peers = agentPeerEntries(online);
        return AgentNetworkMap(
          cloud: AgentMapNode(
            icon: Icons.cloud_outlined,
            title: LocaleKeys.printerSetting_agentCloud.tr,
            lines: cloud.lines,
            state: cloud.state(empty: AgentLinkState.disconnected),
          ),
          // Máy này: tên + mã Agent (máy khác thấy đúng tên này); bấm để đổi tên.
          center: AgentMapNode(
            icon: Icons.hub_rounded,
            title: AgentIdentity.label(service.displayName, service.stationId),
            kind: AgentMapNodeKind.agent,
            lines: agentThisDeviceLines(ssid, ips),
            onTap: () => unawaited(AgentNameSheet.show()),
            tapIcon: Icons.edit_rounded,
          ),
          nodes: [
            // Thứ tự người dùng tự sắp ([AgentMapLayout]).
            for (final s in AgentMapLayout.sorted(
              watchdog.statuses.toList(),
              AgentMapLayout.printers[service.stationId] ?? const <String>[],
              (s) => selfPrinterKey(s.printer),
            ))
              AgentMapNode(
                icon: _printerIcon(s.printer.refKind),
                title: s.printer.nameOrNull ?? '',
                lines: [
                  // Đã tắt nhận lệnh trên Agent này ([AgentPrinterSwitches]).
                  if (off.contains(AgentPrinterSwitches.keyOf(s.printer)))
                    AgentMapLine(
                      LocaleKeys.printerSetting_agentPrinterOffState.tr,
                      icon: Icons.block_rounded,
                    ),
                  _printerAddress(s),
                  if (_printerWifi(s, subnets) case final wifi?)
                    AgentMapLine(wifi, icon: Icons.wifi_rounded),
                ],
                state: off.contains(AgentPrinterSwitches.keyOf(s.printer))
                    ? AgentLinkState.inactive
                    : switch (s.state) {
                        AgentPrinterState.connected => AgentLinkState.connected,
                        AgentPrinterState.disconnected =>
                          AgentLinkState.disconnected,
                        _ => AgentLinkState.inactive,
                      },
                // Máy khác vừa gửi lệnh tới máy in này: vòng sáng + nhãn nổi.
                activity: activities.isEmpty
                    ? null
                    : _activityOf(AgentPrintActivityStore.of(s.printer)),
                // Bấm máy in: xem chi tiết (IP, MAC, mã...) + công tắc nhận
                // lệnh in (có Hoàn tác). Máy in lỗi kết nối lại ở thẻ máy in
                // lỗi ngay dưới sơ đồ.
                onTap: agentShowPrinterDetail(_detail(s, off)),
                tapIcon: Icons.info_outline_rounded,
              ),
          ],
          nodesLabel: LocaleKeys.printerSetting_agentZoneMyPrinters.tr,
          clusters: [for (final e in peers) agentPeerCluster(e)],
          clustersLabel: LocaleKeys.printerSetting_agentOthersTitleTr(
            count: '${peers.length}',
          ),
          emptyText: LocaleKeys.printerSetting_agentNoPrinters.tr,
        );
      }),
    );
  }

  /// Wi-Fi máy in LAN đang nằm: cùng dải với máy này → Wi-Fi hiện tại; còn lại
  /// lấy Wi-Fi đã nhớ lúc in được gần nhất.
  String? _printerWifi(
    AgentPrinterStatus<AgentPrinterRef> s,
    Set<String> subnets,
  ) {
    if (s.printer.refKind != AgentPrinterKind.lan) return null;
    final ip = s.printer.refAddress?.trim() ?? '';
    if (ip.isEmpty) return null;
    if (ssid != null && subnets.contains(agentSubnetOf(ip))) return ssid;
    return PrintAgentUi.station.wifi.ssidOf(s.printer);
  }

  static AgentPrinterDetail _detail(
    AgentPrinterStatus<AgentPrinterRef> s,
    Set<String> off,
  ) {
    final paused = off.contains(AgentPrinterSwitches.keyOf(s.printer));
    final p = s.printer;
    return AgentPrinterDetail(
      name: p.nameOrNull ?? p.refAddress ?? '',
      kind: switch (p.refKind) {
        AgentPrinterKind.builtIn => 'builtin',
        AgentPrinterKind.usb => 'usb',
        _ => 'lan',
      },
      state: paused
          ? AgentPrinterDetailState.paused
          : (s.state == AgentPrinterState.connected
                ? AgentPrinterDetailState.ready
                : AgentPrinterDetailState.notReady),
      on: !paused,
      address: p.refAddress,
      mac: p.refMac,
      id: p.refId,
      station: PrintAgentUi.station.displayName,
      onToggle: () => unawaited(_toggle(p)),
      onTestPrint: () => PrintAgentUi.station.testPrint(p),
    );
  }

  /// Bật / tắt nhận lệnh cho máy in [p] + thông báo kèm nút Hoàn tác.
  static Future<void> _toggle(AgentPrinterRef p) async {
    final on = !AgentPrinterSwitches.isOn(p);
    await AgentPrinterSwitches.setOn(p, on);
    final name = p.nameOrNull ?? p.refAddress ?? '';
    unawaited(
      AppNotification.show(
        message: on
            ? LocaleKeys.printerSetting_agentPrinterTurnedOnTr(printer: name)
            : LocaleKeys.printerSetting_agentPrinterTurnedOffTr(printer: name),
        type: on ? AppNotificationType.success : AppNotificationType.warning,
        trailing: BaseTap(
          onTap: () {
            AppNotification.dismiss();
            unawaited(AgentPrinterSwitches.setOn(p, !on));
          },
          child: const AppPadding.symmetric(
            horizontal: AppSpace.md,
            vertical: AppSpace.sm,
            child: AppText(
              LocaleKeys.printerSetting_agentUndo,
              variant: .title,
            ),
          ),
        ),
      ),
    );
  }

  /// Nhãn nổi theo giai đoạn: đang in (xanh dương, nhấp nháy) / đã in (xanh
  /// lá) / in lỗi (đỏ) + máy gửi.
  static AgentMapActivity? _activityOf(AgentPrintActivity? a) {
    if (a == null) return null;
    final sender = a.sender?.trim() ?? '';
    return AgentMapActivity(
      label: switch (a.phase) {
        AgentPrintPhase.printing =>
          a.isLabel
              ? LocaleKeys.printerSetting_agentActivityPrintingLabel.tr
              : LocaleKeys.printerSetting_agentActivityPrintingReceipt.tr,
        AgentPrintPhase.done => LocaleKeys.printerSetting_agentActivityDone.tr,
        AgentPrintPhase.failed =>
          LocaleKeys.printerSetting_agentActivityFailed.tr,
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
      pulsing: a.active,
      sender: sender.isEmpty
          ? null
          : LocaleKeys.printerSetting_agentJobFromTr(sender: sender),
    );
  }

  /// Khoá máy in của máy này (cùng dạng khoá Agent báo cho máy khác).
  static String selfPrinterKey(AgentPrinterRef p) => AgentMapLayout.printerKey(
    kind: switch (p.refKind) {
      AgentPrinterKind.builtIn => 'builtin',
      AgentPrinterKind.usb => 'usb',
      _ => 'lan',
    },
    address: p.refKind == AgentPrinterKind.lan ? p.refAddress ?? '' : null,
    name: p.nameOrNull ?? '',
  );

  static IconData _printerIcon(AgentPrinterKind? type) => switch (type) {
    AgentPrinterKind.usb => Icons.usb_rounded,
    AgentPrinterKind.builtIn => Icons.point_of_sale_rounded,
    AgentPrinterKind.bluetooth => Icons.bluetooth_rounded,
    _ => Icons.print_rounded,
  };

  /// Địa chỉ máy in kèm biểu tượng kiểu kết nối (LAN / USB / tích hợp).
  static AgentMapLine _printerAddress(AgentPrinterStatus<AgentPrinterRef> s) =>
      switch (s.printer.refKind) {
        AgentPrinterKind.builtIn => AgentMapLine(
          LocaleKeys.printerSetting_agentBuiltIn.tr,
          icon: Icons.point_of_sale_rounded,
        ),
        AgentPrinterKind.usb => const AgentMapLine(
          'USB',
          icon: Icons.usb_rounded,
        ),
        // Khách chỉ cần biết là máy in LAN — IP xem ở thẻ máy in chưa kết nối.
        _ => const AgentMapLine('LAN', icon: Icons.lan_outlined),
      };
}
