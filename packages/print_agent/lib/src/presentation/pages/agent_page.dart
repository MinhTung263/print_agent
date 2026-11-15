import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:print_agent/src/agent_domain.dart';
import 'package:printer_label/printer_label.dart';
import 'package:print_agent/src/presentation/agent_widgets.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';
import 'package:print_agent/src/presentation/widgets/agent_activity_banner.dart';
import 'package:print_agent/src/presentation/widgets/agent_printer_issues_card.dart';
import 'package:print_agent/src/presentation/widgets/sheets/agent_map_arrange_sheet.dart';
import 'package:print_agent/src/presentation/widgets/agent_map_header.dart';
import 'package:print_agent/src/presentation/widgets/agent_printers_map.dart';
import 'package:print_agent/src/presentation/widgets/agent_doctor_card.dart';
import 'package:print_agent/src/presentation/widgets/agent_stats_card.dart';
import 'package:print_agent/src/presentation/widgets/sender_agents_map.dart';

/// Màn "Máy Agent": sơ đồ kết nối + cài đặt.
///
/// - Máy này đang là Agent: đám mây ↔ máy này ↔ các máy in Agent quản lý (trạng
///   thái kết nối từng máy), số lệnh đã in hộ, quyền tự khởi động lại.
/// - Máy bán hàng: đám mây ↔ máy này ↔ các máy Agent của công ty đang trực tuyến
///   (dự phòng khi máy in lỗi).
class AgentPage extends StatefulWidget {
  const AgentPage({super.key, this.agentSide = const [], this.side = const []});

  /// Thẻ thêm ở cột cài đặt khi máy này là Agent (VD Agent máy tính: chọn máy
  /// in, tự chạy khi bật máy, đăng xuất).
  final List<Widget> agentSide;

  /// Thẻ của app chủ LUÔN hiện ở cột phải (cả khi chưa bật trạm in) — VD cài
  /// đặt máy in của trạm in máy tính.
  final List<Widget> side;

  /// Mở màn mới (toàn màn hình).
  static Future<void> show() async {
    await Get.to<void>(() => const AgentPage());
  }

  @override
  State<AgentPage> createState() => _AgentPageState();
}

class _AgentPageState extends State<AgentPage> with WidgetsBindingObserver {
  final _relay = PrintAgentUi.station.relay;
  final _watchdog = PrintAgentUi.station.watchdog;

  static const Duration _refreshEvery = Duration(seconds: 15);

  /// Wi-Fi + IP của máy này.
  String? _ssid;
  List<String> _ips = const [];
  List<Map<Object?, Object?>> _agents = const [];
  bool? _autoRestart;
  Timer? _refresh;
  Timer? _netDebounce;
  StreamSubscription<void>? _netSub;

  /// Đang tải — bỏ qua lượt mới chồng lên (timer + đổi mạng + bấm làm mới).
  bool _loading = false;

  /// Kết nối THẬT tới từng kênh đám mây (tên kênh → đang thông).
  final Map<String, bool> _cloud = {};
  List<PrintRelayTransport> _watched = const [];
  final List<StreamSubscription<bool>> _cloudSubs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Đang xem sơ đồ: dò máy in dày hơn — bật / tắt máy in hiện ngay.
    _watchdog.watchClosely(true);
    // Agent khác bật / tắt: cập nhật sơ đồ NGAY (plugin theo dõi liên tục),
    // không chờ lượt tải lại định kỳ.
    _relay.stations.addListener(_onStationsChanged);
    unawaited(_reload(check: true, permissions: true));
    _startTimer();
    // Đổi Wi-Fi / mất mạng: cập nhật ngay, máy in về "đang kiểm tra". Gộp các
    // sự kiện dồn dập (Wi-Fi rớt → nối lại) thành một lượt.
    _netSub = PrintAgentUi.station.networkChanges.listen((_) {
      if (_relay.isStation.value) _watchdog.markAllChecking();
      _netDebounce?.cancel();
      _netDebounce = Timer(
        const Duration(seconds: 1),
        () => unawaited(_reload(check: true)),
      );
    });
  }

  /// Sơ đồ "sống": cập nhật mỗi [_refreshEvery] khi đang mở màn (nghỉ khi app
  /// chạy nền).
  void _startTimer() {
    _refresh?.cancel();
    _refresh = Timer.periodic(_refreshEvery, (_) => unawaited(_reload()));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Quay lại từ Cài đặt (VD vừa cấp quyền tự khởi động lại / đổi Wi-Fi).
      _startTimer();
      unawaited(_reload(check: true, permissions: true));
    } else if (state == AppLifecycleState.paused) {
      _refresh?.cancel();
      _refresh = null;
    }
  }

  void _onStationsChanged() {
    if (!mounted || _relay.isStation.value) return;
    setState(() => _agents = _relay.stations.value);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchdog.watchClosely(false);
    _relay.stations.removeListener(_onStationsChanged);
    _refresh?.cancel();
    _netDebounce?.cancel();
    unawaited(_netSub?.cancel());
    for (final sub in _cloudSubs) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  /// Tải lại trạng thái (các lệnh chạy song song). [permissions]: đọc lại quyền
  /// tự khởi động lại — chỉ lúc mở màn / quay lại app, không mỗi 15s.
  Future<void> _reload({bool check = false, bool permissions = false}) async {
    if (_loading) return;
    _loading = true;
    try {
      final isAgent = _relay.isStation.value;
      if (check && isAgent) unawaited(_watchdog.checkNow());
      final wifiF = PrintAgentUi.station.wifi.currentSsid();
      final ipsF = PrintRelayLanServer.localIpv4s();
      final agentsF = isAgent
          ? Future.value(const <Map<Object?, Object?>>[])
          : _relay.onlineStations();
      final autoF = permissions && Platform.isAndroid
          ? PrinterLabel.canAutoRestart()
          : Future.value(_autoRestart);
      final transportsF = isAgent
          ? Future.value(_relay.stationTransports)
          : _relay.queues();
      final wifi = await wifiF;
      final ips = await ipsF;
      final agents = await agentsF;
      // Ghi nhớ Agent đang trực tuyến (Agent tắt sau đó vẫn hiện "Ngoại tuyến").
      // Sau các `await` — không đổi danh sách (Rx) giữa lúc dựng giao diện.
      if (!_relay.isStation.value) KnownAgents.sync(agents);
      final auto = await autoF;
      final transports = await transportsF;
      if (!mounted) return;
      _watchCloud(transports);
      // Không đổi gì thì không dựng lại màn.
      if (wifi == _ssid &&
          listEquals(ips, _ips) &&
          _sameAgents(agents, _agents) &&
          auto == _autoRestart) {
        return;
      }
      setState(() {
        _ssid = wifi;
        _ips = ips;
        _agents = agents;
        _autoRestart = auto;
      });
    } catch (e) {
      PrintAgentModule.host.log('[AGENT] Tải màn máy Agent lỗi: $e');
    } finally {
      _loading = false;
    }
  }

  static bool _sameAgents(
    List<Map<Object?, Object?>> a,
    List<Map<Object?, Object?>> b,
  ) =>
      a.length == b.length &&
      [
        for (var i = 0; i < a.length; i++) mapEquals(a[i], b[i]),
      ].every((e) => e);

  /// Theo dõi kết nối thật của các kênh — chỉ đăng ký lại khi danh sách đổi.
  void _watchCloud(List<PrintRelayTransport> transports) {
    if (transports.length == _watched.length &&
        transports.every(_watched.contains)) {
      return;
    }
    for (final sub in _cloudSubs) {
      unawaited(sub.cancel());
    }
    _cloudSubs.clear();
    _cloud.clear();
    _watched = List.of(transports);
    for (final t in transports) {
      final name = agentChannelName(t);
      _cloudSubs.add(
        t.watchConnection().listen(
          (ok) => _setCloud(name, ok),
          onError: (_) => _setCloud(name, false),
        ),
      );
    }
  }

  /// Chỉ dựng lại khi trạng thái kênh thật sự đổi (Firebase phát lặp giá trị).
  void _setCloud(String name, bool ok) {
    if (!mounted || _cloud[name] == ok) return;
    setState(() => _cloud[name] = ok);
  }

  @override
  Widget build(BuildContext context) {
    final cloud = AgentCloudInfo(_cloud);
    return BaseScaffoldHelper(
      appBar: const BaseAppBar(title: LocaleKeys.printerSetting_agentDashboard),
      body: ValueListenableBuilder<bool>(
        valueListenable: _relay.isStation,
        builder: (_, isAgent, _) => AgentLayout(
          // Công tắc chính — luôn ở đầu, không bị các thẻ khác đẩy xuống.
          top: const PrintStationToggle(),
          map: AppColumn(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: ShareDimens.itemSpacing,
            children: [
              BaseCard.section(
                child: AppColumn(
                  mainAxisSize: MainAxisSize.min,
                  spacing: AppSpace.sm,
                  children: [
                    AgentMapHeader(
                      isAgent: isAgent,
                      onRefresh: () => unawaited(_reload(check: true)),
                      onArrange: () => unawaited(
                        AgentMapArrangeSheet.show(isAgent: isAgent),
                      ),
                    ),
                    if (isAgent) const AgentActivityBanner(),
                    isAgent
                        ? AgentPrintersMap(ssid: _ssid, ips: _ips, cloud: cloud)
                        : SenderAgentsMap(
                            ssid: _ssid,
                            ips: _ips,
                            cloud: cloud,
                            agents: _agents,
                          ),
                    if (isAgent)
                      AgentPrinterIssuesCard(
                        onChanged: () => unawaited(_reload(check: true)),
                      ),
                  ],
                ),
              ),
              // Lệnh in gần đây ngay dưới sơ đồ (tablet: cùng cột trái) — dễ
              // thấy hơn khi nằm cuối cột cài đặt.
              if (isAgent) const AgentJobLogCard(),
            ],
          ),
          side: [
            // Máy Agent: tên + mã để các máy khác phân biệt (đặt tên được).
            if (isAgent) AgentStatsCard(autoRestart: _autoRestart),
            // "Bác sĩ trạm in": cái gì đang ổn / cần xem.
            if (isAgent) AgentDoctorCard(cloud: cloud),
            if (isAgent) ...widget.agentSide,
            ...widget.side,
            // Máy in có sẵn của các trạm in: bật / tắt trong bảng mở từ sơ đồ
            // (bấm vào trạm in) — không lặp lại mục riêng ở đây.
          ],
        ),
      ),
    );
  }
}
