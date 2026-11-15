import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Một Wi-Fi cần chuyển sang + các máy in chưa kết nối nằm ở Wi-Fi đó.
/// [ssid] `null` = chưa biết máy in ở Wi-Fi nào.
typedef _PrinterNetwork = ({
  String? ssid,
  bool current,
  bool nearby,
  List<AgentPrinterRef> printers,
});

/// "Đổi mạng" ở màn Máy Agent — chỉ mở khi có máy in LAN chưa kết nối, và chỉ
/// liệt kê Wi-Fi của chính các máy in đó (Wi-Fi đã nhớ lúc in được).
///
/// Cách nối: Android 10+ mở bảng Wi-Fi của hệ thống (đổi Wi-Fi THẬT của cả máy —
/// máy Agent cần internet + máy in cùng một mạng, nối riêng cho app thì có thể mất
/// đám mây); Android 6–9 / iOS nối thẳng bằng mật khẩu đã lưu, chưa lưu thì nhập.
class AgentWifiSwitchSheet extends StatefulWidget {
  const AgentWifiSwitchSheet({super.key, required this.printers});

  /// Máy in LAN chưa kết nối được.
  final List<AgentPrinterRef> printers;

  /// Trả `true` khi đã chuyển sang Wi-Fi khác.
  static Future<bool> show(List<AgentPrinterRef> printers) async =>
      await BaseBottomSheet.show<bool>(
        body: AgentWifiSwitchSheet(printers: printers),
        headerTitle: LocaleKeys.printerSetting_agentSwitchNetwork,
        allowOffline: true,
      ) ??
      false;

  @override
  State<AgentWifiSwitchSheet> createState() => _AgentWifiSwitchSheetState();
}

class _AgentWifiSwitchSheetState extends State<AgentWifiSwitchSheet>
    with WidgetsBindingObserver {
  List<_PrinterNetwork>? _networks;

  /// Android 10+: chọn Wi-Fi trong bảng của hệ thống.
  bool _usePanel = false;

  /// Wi-Fi đang chờ người dùng chọn trong bảng hệ thống / đang nối.
  String? _pending;
  bool _joining = false;

  /// Wi-Fi đang mở ô nhập mật khẩu (+ số lần mở, để ô nhập làm mới).
  String? _asking;
  int _askSeq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Quay lại từ bảng Wi-Fi: đã ở đúng Wi-Fi thì đóng và báo thành công.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pending != null) {
      unawaited(_confirmSwitched(_pending!));
    }
  }

  Future<void> _load() async {
    await PrintAgentUi.station.wifi.ensureNamePermission(force: true);
    final usePanel = await PrintAgentUi.station.wifi.usesSystemPanel();
    final current = (await PrintAgentUi.station.wifi.currentSsid());
    final nearby = (await PrintAgentUi.station.wifi.nearby()).toSet();
    final groups = <String?, List<AgentPrinterRef>>{};
    for (final p in widget.printers) {
      (groups[PrintAgentUi.station.wifi.ssidOf(p)] ??= []).add(p);
    }
    // Wi-Fi có sóng lên trước, chưa rõ Wi-Fi xuống cuối.
    final networks = [
      for (final e in groups.entries)
        (
          ssid: e.key,
          current: e.key != null && e.key == current,
          nearby: nearby.contains(e.key),
          printers: e.value,
        ),
    ]..sort((a, b) => _rank(a).compareTo(_rank(b)));
    if (!mounted) return;
    setState(() {
      _usePanel = usePanel;
      _networks = networks;
    });
  }

  static int _rank(_PrinterNetwork n) =>
      n.ssid == null ? 3 : (n.current ? 2 : (n.nearby ? 0 : 1));

  Future<void> _connect(String ssid) async {
    if (_joining) return;
    if (_usePanel) {
      // Đổi Wi-Fi thật của cả máy qua bảng hệ thống; quay lại app thì kiểm tra.
      setState(() => _pending = ssid);
      await PrintAgentUi.station.wifi.openSettings();
      return;
    }
    final saved = await PrintAgentUi.station.wifi.passwordFor(ssid);
    if (saved == null) {
      setState(() {
        _asking = ssid;
        _askSeq++;
      });
      return;
    }
    await _join(ssid, saved);
  }

  Future<void> _join(String ssid, String password) async {
    setState(() {
      _joining = true;
      _pending = ssid;
    });
    final ok = await PrintAgentUi.station.wifi.switchTo(
      ssid,
      password: password,
    );
    if (!mounted) return;
    setState(() {
      _joining = false;
      _pending = null;
    });
    if (ok) {
      _done();
      return;
    }
    // Sai / đổi mật khẩu, mất sóng: cho nhập lại mật khẩu.
    setState(() {
      _asking = ssid;
      _askSeq++;
    });
    await AppNotification.error(
      message: LocaleKeys.printerSetting_wifiSwitchFailedTr(wifi: ssid),
    );
  }

  Future<void> _confirmSwitched(String ssid) async {
    // Wi-Fi mới cần vài giây để nhận IP / báo tên.
    for (var i = 0; i < 4; i++) {
      if ((await PrintAgentUi.station.wifi.currentSsid()) == ssid) {
        if (mounted) _done();
        return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  /// Đã ở đúng Wi-Fi: đóng — sơ đồ tự cập nhật, không cần thông báo.
  void _done() {
    _pending = null;
    Get.back<bool>(result: true);
  }

  @override
  Widget build(BuildContext context) {
    final networks = _networks;
    return AppPadding.all(
      AppSpace.lg,
      child: AppColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.md,
        children: [
          const AppText(
            LocaleKeys.printerSetting_agentSwitchNetworkHint,
            variant: .caption,
            tone: .secondary,
            maxLines: 3,
          ),
          if (networks == null)
            const Center(
              child: AppPadding.all(
                AppSpace.lg,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            for (final n in networks)
              _NetworkCard(
                network: n,
                busy: _joining && _pending == n.ssid,
                waitingPanel: _usePanel && _pending == n.ssid,
                passwordKey: _asking != null && _asking == n.ssid
                    ? ValueKey('${n.ssid}#$_askSeq')
                    : null,
                onConnect: n.ssid == null
                    ? () => unawaited(PrintAgentUi.station.wifi.openSettings())
                    : () => unawaited(_connect(n.ssid!)),
                onPassword: (pw) => unawaited(_join(n.ssid!, pw)),
              ),
        ],
      ),
    );
  }
}

/// Thẻ một Wi-Fi: tên + có sóng không, các máy in nằm ở đó, nút Kết nối.
class _NetworkCard extends StatelessWidget {
  const _NetworkCard({
    required this.network,
    required this.busy,
    required this.waitingPanel,
    required this.passwordKey,
    required this.onConnect,
    required this.onPassword,
  });

  final _PrinterNetwork network;
  final bool busy;
  final bool waitingPanel;

  /// Khác `null`: hiện ô nhập mật khẩu (key đổi = ô trống mới).
  final Key? passwordKey;
  final VoidCallback onConnect;
  final ValueChanged<String> onPassword;

  @override
  Widget build(BuildContext context) {
    final ssid = network.ssid;
    final (status, statusColor) = ssid == null
        ? (LocaleKeys.printerSetting_agentWifiUnknownHint.tr, AppColors.dsGray5)
        : network.current
        ? (LocaleKeys.printerSetting_agentWifiPrinterOff.tr, AppColors.orange)
        : network.nearby
        ? (LocaleKeys.printerSetting_agentWifiNearby.tr, AppColors.successGreen)
        : (LocaleKeys.printerSetting_agentWifiFar.tr, AppColors.dsGray5);
    return Container(
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: network.nearby && !network.current
              ? AppColors.primaryBlueBase.withValues(alpha: 0.5)
              : AppColors.dsGray5.withValues(alpha: 0.5),
        ),
      ),
      child: AppColumn(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpace.sm,
        children: [
          AppRow(
            spacing: AppSpace.sm,
            children: [
              Icon(
                ssid == null ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                color: statusColor,
              ),
              Expanded(
                child: AppColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText.raw(
                      ssid ?? LocaleKeys.printerSetting_agentWifiUnknown.tr,
                      variant: .title,
                      maxLines: 1,
                    ),
                    AppText.raw(
                      status,
                      variant: .caption,
                      textColor: statusColor,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
          for (final p in network.printers)
            AppRow(
              spacing: AppSpace.sm,
              children: [
                const SizedBox(width: AppSpace.xs),
                const Icon(
                  Icons.print_rounded,
                  size: 16,
                  color: AppColors.errorRed,
                ),
                Expanded(
                  child: AppText.raw(
                    [?p.nameOrNull, ?p.refAddress].join(' · '),
                    variant: .caption,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          if (waitingPanel)
            AppText.raw(
              LocaleKeys.printerSetting_agentWifiPickInPanelTr(
                wifi: ssid ?? '',
              ),
              variant: .caption,
              textColor: AppColors.primaryBlueBase,
              maxLines: 2,
            ),
          if (passwordKey != null)
            _PasswordRow(
              key: passwordKey,
              enabled: !busy,
              onConnect: onPassword,
            )
          else if (!network.current)
            BaseButton(
              onPressed: busy ? null : onConnect,
              title: busy
                  ? LocaleKeys.printerSetting_wifiChecking
                  : (ssid == null
                        ? LocaleKeys.printerSetting_agentWifiOpenSettings
                        : LocaleKeys.printerSetting_agentWifiConnect),
              backgroundColor: AppColors.primaryBlueBase,
            ),
        ],
      ),
    );
  }
}

/// Ô nhập mật khẩu + nút "Kết nối" cho Wi-Fi chưa lưu mật khẩu.
class _PasswordRow extends StatefulWidget {
  const _PasswordRow({
    super.key,
    required this.enabled,
    required this.onConnect,
  });

  final bool enabled;
  final ValueChanged<String> onConnect;

  @override
  State<_PasswordRow> createState() => _PasswordRowState();
}

class _PasswordRowState extends State<_PasswordRow> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppColumn(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpace.sm,
      children: [
        BaseInput(
          model: BaseInputModel(
            controller: _password,
            label: LocaleKeys.printerSetting_wifiPassword,
            obscureText: true,
          ),
        ),
        BaseButton(
          onPressed: widget.enabled
              ? () => widget.onConnect(_password.text)
              : null,
          title: LocaleKeys.printerSetting_agentWifiConnect,
          backgroundColor: AppColors.primaryBlueBase,
        ),
      ],
    );
  }
}
