import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_name_sheet.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/utils/agent_peer_cluster.dart';
import 'package:print_agent/src/presentation/utils/agent_printer_issue.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_printer_detail_sheet.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_reconnect_sheet.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_wifi_switch_sheet.dart';

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
        AgentPeersVisibility.ensureLoaded();
        final showPeers = AgentPeersVisibility.show.value;
        final peers = showPeers
            ? agentPeerEntries(online)
            : const <AgentPeerEntry>[];
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
            for (final (s, label) in _labeled(
              AgentMapLayout.sorted(
                watchdog.statuses.toList(),
                AgentMapLayout.printers[service.stationId] ?? const <String>[],
                (s) => selfPrinterKey(s.printer),
              ),
            ))
              AgentMapNode(
                icon: _printerIcon(s.printer.refKind),
                // Tên ngắn nhận ra máy (model); loại máy (hoá đơn / tem) ở dòng dưới.
                title: label.title,
                lines: [
                  // "Hoá đơn | USB": loại máy và kiểu kết nối CÙNG MỘT HÀNG.
                  ?joinLines(label.typeLine, addressLineOf(s)),
                  // Đã tắt nhận lệnh trên Agent này ([AgentPrinterSwitches]).
                  if (off.contains(AgentPrinterSwitches.keyOf(s.printer)))
                    AgentMapLine(
                      LocaleKeys.printerSetting_agentPrinterOffState.tr,
                      icon: Icons.block_rounded,
                    ),
                  if (_usbBlocked(s.printer))
                    AgentMapLine(
                      LocaleKeys.printerSetting_printerUsbUnsupportedShort.tr,
                      icon: Icons.warning_amber_rounded,
                    ),
                  // Máy do đồng bộ từ cửa hàng EasyPOS thêm vào.
                  if (PrintAgentUi.printerBadge?.call(s.printer)
                      case final badge?)
                    AgentMapLine(badge, icon: Icons.storefront_rounded),
                  if (_printerWifi(s, subnets) case final wifi?)
                    AgentMapLine(wifi, icon: Icons.wifi_rounded),
                ],
                state:
                    off.contains(AgentPrinterSwitches.keyOf(s.printer)) ||
                        _usbBlocked(s.printer)
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
                onTap: agentShowPrinterDetail(detailOf(s, off)),
                tapIcon: Icons.info_outline_rounded,
              ),
          ],
          nodesLabel: LocaleKeys.printerSetting_agentZoneMyPrinters.tr,
          clusters: [for (final e in peers) agentPeerCluster(e)],
          clustersLabel: !showPeers
              ? null
              : LocaleKeys.printerSetting_agentOthersTitleTr(
                  count: '${peers.length}',
                ),
          emptyText: LocaleKeys.printerSetting_agentNoPrinters.tr,
        );
      }),
    );
  }

  /// Tên hiện trên nút: "Máy in hoá đơn · XP-80C" bị cắt đúng phần model nên khách không phân
  /// biệt được máy nào. Tách: DÒNG TÊN = phần phân biệt (model), DÒNG PHỤ = loại máy
  /// ("Hoá đơn" / "Tem"). Hai máy trùng tên: máy LAN thêm số cuối IP, máy khác đánh số thứ tự.
  static List<
    (
      AgentPrinterStatus<AgentPrinterRef>,
      ({String title, AgentMapLine? typeLine}),
    )
  >
  _labeled(List<AgentPrinterStatus<AgentPrinterRef>> sorted) {
    final base = [
      for (final s in sorted) splitName(s.printer.nameOrNull ?? ''),
    ];
    final count = <String, int>{};
    for (final b in base) {
      count[b.title] = (count[b.title] ?? 0) + 1;
    }
    final seen = <String, int>{};
    return [
      for (var i = 0; i < sorted.length; i++)
        (() {
          var title = base[i].title;
          if ((count[title] ?? 0) > 1) {
            final n = seen[title] = (seen[title] ?? 0) + 1;
            final addr = (sorted[i].printer.refAddress ?? '').trim();
            title = _isIpv4(addr)
                ? '$title · .${addr.split(':').first.split('.').last}'
                : '$title #$n';
          }
          return (sorted[i], (title: title, typeLine: base[i].typeLine));
        })(),
    ];
  }

  /// "Máy in hoá đơn · XP-80C" → tên "XP-80C" + dòng phụ "Hoá đơn". Không có dấu " · " thì
  /// giữ nguyên tên, không dòng phụ.
  @visibleForTesting
  static ({String title, AgentMapLine? typeLine}) splitName(String name) {
    final i = name.indexOf(' · ');
    if (i <= 0) return (title: name, typeLine: null);
    final model = name.substring(i + 3).trim();
    if (model.isEmpty) return (title: name, typeLine: null);
    var type = name.substring(0, i).trim();
    if (type.toLowerCase().startsWith('máy in ')) {
      type = type.substring(7).trim();
    }
    if (type.isNotEmpty) {
      type = type[0].toUpperCase() + type.substring(1);
    }
    return (
      title: model,
      typeLine: type.isEmpty
          ? null
          : AgentMapLine(type, icon: Icons.label_outline_rounded),
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

  /// Máy in USB nhưng thiết bị này không in USB được (iOS).
  static bool _usbBlocked(AgentPrinterRef p) =>
      !PrintAgentUi.usbSupported && p.refKind == AgentPrinterKind.usb;

  /// Chi tiết một máy in của máy này (bảng hiện khi bấm máy in trên sơ đồ).
  @visibleForTesting
  static AgentPrinterDetail detailOf(
    AgentPrinterStatus<AgentPrinterRef> s,
    Set<String> off,
  ) {
    final paused = off.contains(AgentPrinterSwitches.keyOf(s.printer));
    final p = s.printer;
    return AgentPrinterDetail(
      name: p.nameOrNull ?? p.refAddress ?? '',
      kind: switch (p.refKind) {
        // Máy in của Agent máy tính (IP thật): chi tiết ghi "LAN" + địa chỉ IP.
        AgentPrinterKind.builtIn when _isIpv4(p.refAddress) => 'lan',
        AgentPrinterKind.builtIn when _isLocalUsb(p.refAddress) => 'usb',
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
      onReconnect: _isIssue(s, paused: paused)
          ? () => AgentReconnectSheet.show(p)
          : null,
      onSwitchNetwork:
          _isIssue(s, paused: paused) &&
              s.state == AgentPrinterState.otherNetwork &&
              p.refKind == AgentPrinterKind.lan
          ? () => AgentWifiSwitchSheet.show([p])
          : null,
      address: p.refAddress,
      mac: p.refMac,
      // Mã -1 của máy in chính Agent chỉ là mã nội bộ — không hiện cho khách.
      id: p.refKind == AgentPrinterKind.builtIn ? null : p.refId,
      station: PrintAgentUi.station.displayName,
      functionsEditable: true,
      usbUnsupported: _usbBlocked(p),
      routingName: PrintAgentUi.printerRoutingName == null
          ? (p.nameOrNull ?? p.refAddress ?? '')
          : PrintAgentUi.printerRoutingName!(p),
      isLabelPrinter: PrintAgentUi.printerIsLabel?.call(p),
      onToggle: () => unawaited(_toggle(p)),
      onTestPrint: (PrintAgentUi.hasOwnTestPrint?.call(p) ?? false)
          ? null
          : () => PrintAgentUi.station.testPrint(p),
      // Máy in tích hợp của máy POS (Sunmi...) không có cài đặt riêng; máy in chính của
      // Agent máy tính (IP thật hoặc USB) thì có.
      settings: _isDesktopOwn(p) ? PrintAgentUi.printerSettings?.call(p) : null,
      footerAction: _isDesktopOwn(p)
          ? PrintAgentUi.printerFooterAction?.call(p)
          : null,
      // Máy in tích hợp của máy POS không xoá được; máy in LAN / USB đã lưu và máy in
      // đã chọn của Agent máy tính (IP thật) thì xoá nhanh được ngay ở đây.
      onRemove:
          PrintAgentUi.onRemovePrinter == null ||
              (p.refKind == AgentPrinterKind.builtIn && !_isDesktopOwn(p))
          ? null
          : () => PrintAgentUi.onRemovePrinter!(p),
    );
  }

  /// Máy in đang lỗi kết nối và còn nhận lệnh (máy đã tắt nhận lệnh không tính là lỗi).
  static bool _isIssue(
    AgentPrinterStatus<AgentPrinterRef> s, {
    required bool paused,
  }) => !paused && AgentPrinterIssue.isConnectionLost(s.state);

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

  /// Ghép loại máy ([type]) và kiểu kết nối ([address]) thành MỘT hàng "Hoá đơn | USB";
  /// thiếu một phần thì hiện phần còn lại.
  @visibleForTesting
  static AgentMapLine? joinLines(AgentMapLine? type, AgentMapLine? address) {
    if (type == null) return address;
    if (address == null) return type;
    return AgentMapLine(
      type.text,
      icon: type.icon,
      color: type.color,
      next: address,
    );
  }

  /// Dòng phụ dưới tên máy in trên sơ đồ: kiểu kết nối (LAN / USB / tích hợp);
  /// `null` = chỉ hiện tên.
  @visibleForTesting
  static AgentMapLine? addressLineOf(
    AgentPrinterStatus<AgentPrinterRef> s,
  ) => switch (s.printer.refKind) {
    // Máy in của Agent máy tính là máy in LAN đã chọn (địa chỉ IP thật): trên sơ đồ
    // chỉ hiện TÊN máy in, IP xem ở chi tiết. Máy in tích hợp của máy POS thì "Có sẵn
    // trên máy".
    AgentPrinterKind.builtIn when _isIpv4(s.printer.refAddress) => null,
    AgentPrinterKind.builtIn when _isLocalUsb(s.printer.refAddress) =>
      const AgentMapLine('USB', icon: Icons.usb_rounded),
    AgentPrinterKind.builtIn => AgentMapLine(
      LocaleKeys.printerSetting_agentBuiltIn.tr,
      icon: Icons.point_of_sale_rounded,
    ),
    AgentPrinterKind.usb => const AgentMapLine('USB', icon: Icons.usb_rounded),
    // Khách chỉ cần biết là máy in LAN — IP xem ở thẻ máy in chưa kết nối.
    _ => const AgentMapLine('LAN', icon: Icons.lan_outlined),
  };

  static final RegExp _ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}(:\d{1,5})?$');

  /// Máy in USB của máy tính: địa chỉ `usb:` (Linux) / `queue:` (Windows) / `cups:` (macOS)

  static bool _isLocalUsb(String? address) {
    final a = (address ?? '').trim();
    return a.startsWith('usb:') ||
        a.startsWith('usbp:') ||
        a.startsWith('queue:') ||
        a.startsWith('lpq:') ||
        a.startsWith('cups:');
  }

  /// Máy in chính của Agent máy tính (LAN IP thật hoặc USB), khác máy in tích hợp POS.
  static bool _isDesktopOwn(AgentPrinterRef p) =>
      p.refKind != AgentPrinterKind.builtIn ||
      _isIpv4(p.refAddress) ||
      _isLocalUsb(p.refAddress);

  static bool _isIpv4(String? address) =>
      address != null && _ipv4.hasMatch(address.trim());
}
