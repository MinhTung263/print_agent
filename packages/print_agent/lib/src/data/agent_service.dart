import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:print_agent_core/print_agent_core.dart';
import 'package:printer_label/printer_label.dart';

import '../domain/agent_identity.dart';
import '../domain/agent_primary.dart';
import '../domain/entities/agent_printer_ref.dart';
import '../domain/entities/agent_printer_status.dart';
import '../domain/entities/peer_built_in_printer.dart';
import '../domain/ports/agent_host.dart';
import '../domain/ports/agent_job_printer.dart';
import '../domain/ports/agent_printer_gateway.dart';
import '../l10n/agent_locale_keys.dart';
import '../print_agent_module.dart';
import 'agent_device_identity.dart';
import 'agent_device_name.dart';
import 'agent_job_handler.dart';
import 'agent_job_log_store.dart';
import 'agent_map_layout.dart';
import 'agent_printer_reconnect.dart';
import 'agent_printer_remote.dart';
import 'agent_printer_switches.dart';
import 'agent_printer_watchdog.dart';
import 'agent_sender.dart';
import 'agent_test_print.dart';
import 'agent_station_info.dart';
import 'known_agents.dart';
import 'peer_built_in_printers.dart';
import 'timed_printer_gateway.dart';

/// Máy Agent của app chủ — gói trọn phần chung: mã / tên Agent, bật / tắt làm
/// Agent (một bản app mỗi máy), thông tin trạm báo cho máy khác, lệnh điều
/// khiển, nhận + in lệnh ([AgentJobHandler]), máy gửi in qua Agent
/// ([AgentSender]). App chủ chỉ cài [AgentPrinterGateway] + [AgentJobPrinter]
/// (+ kênh riêng qua [extraQueues], VD Firebase).
class AgentService<P extends AgentPrinterRef> {
  AgentService({
    required AgentPrinterGateway<P> gateway,
    required AgentJobPrinter<P> printer,
    this.extraQueues,
    this.mqttConfig = const MqttRelayConfig(),
    this.notification,
    this.canHandleOther,
  }) : _gateway = TimedPrinterGateway<P>(gateway),
       _printer = printer {
    PeerBuiltInPrinters.defaultTemplates = printer.defaultTemplates;
    watchdog = AgentPrinterWatchdog<P>(_gateway);
    reconnect = AgentPrinterReconnect<P>(_gateway, watchdog);
    remote = AgentPrinterRemote<P>(
      watchdog: watchdog,
      sendControl: (id, cmd) => relay.sendControl(id, cmd),
      senderName: () => AgentDeviceName.label ?? displayName,
    );
    jobs = AgentJobHandler<P>(watchdog: watchdog, printer: printer);
    sender = AgentSender<P>(relay: () => relay, printer: printer);
    testPrint = AgentTestPrint<P>(
      jobs: jobs,
      printer: printer,
      relay: () => relay,
      stationId: () => stationId,
      stationName: () => displayName,
    );
  }

  /// Công ty GỐC mà máy này làm Agent (ghim lúc bật). Đổi sang công ty khác:
  /// tạm dừng, không tự làm Agent cho công ty đó; quay lại thì tự bật lại.
  static const String _boundStorageKey = 'print_station_bound_company';

  /// Khoá cũ: cờ bật Agent chung cho cả máy (gây làm Agent nhầm chi nhánh).
  static const String _legacyEnabledKey = 'print_station_enabled';
  static const String _stationIdStorageKey = 'print_station_id';

  /// Tên Agent theo công ty (`print_station_name_{công ty}`); khoá chung cũ
  /// không hậu tố dùng làm mặc định.
  static const String _nameStorageKey = 'print_station_name';

  final AgentPrinterGateway<P> _gateway;
  final AgentJobPrinter<P> _printer;

  /// Kênh riêng của app (VD Firebase) cho công ty [shopKey], đứng TRƯỚC kênh
  /// MQTT (thứ tự mặc định; plugin tự ưu tiên kênh nhanh hơn sau vài lệnh).
  final Future<List<PrintRelayTransport>> Function(String shopKey)? extraQueues;
  final MqttRelayConfig mqttConfig;

  /// Có nhận lệnh tới máy in LAN / USB (không phải máy in tích hợp) không;
  /// mặc định [PrintRelayStation.defaultCanHandle] (cùng mạng / USB đang cắm).
  final Future<bool> Function(PrintRelayJob job)? canHandleOther;

  /// Chữ trên thông báo chạy nền (Android); mặc định chữ của module.
  final PrintRelayNotification Function()? notification;

  late final AgentPrinterWatchdog<P> watchdog;
  late final AgentPrinterReconnect<P> reconnect;
  late final AgentPrinterRemote<P> remote;
  late final AgentJobHandler<P> jobs;

  /// "In thử" từng máy in (máy in của máy này và của Agent khác).
  late final AgentTestPrint<P> testPrint;
  late final AgentSender<P> sender;

  AgentStorage get _storage => PrintAgentModule.host.storage;

  String get _companyKey => PrintAgentModule.host.companyKey;

  String get _nameKey => '${_nameStorageKey}_$_companyKey';

  /// Tên người dùng đặt cho máy Agent này ở công ty hiện tại — trống thì dùng
  /// tên thiết bị.
  late final RxString name = RxString(_loadName());

  String _loadName() =>
      (_storage.get(_nameKey) ?? _storage.get(_nameStorageKey))?.toString() ??
      '';

  /// Đặt tên máy Agent; đang là Agent thì báo ngay cho các máy khác.
  Future<void> setName(String value) async {
    name.value = value.trim();
    await _storage.put(_nameKey, name.value);
    if (relay.isStation.value) await relay.refreshStationInfo();
  }

  /// Công ty gốc đang ghim (`null` = máy này không làm Agent).
  String? get boundCompany {
    final v = _storage.get(_boundStorageKey)?.toString();
    return v == null || v.isEmpty ? null : v;
  }

  /// Máy này đang là Agent của công ty KHÁC công ty đang đăng nhập (bật ở đây
  /// sẽ chuyển trạm in sang công ty này).
  bool get boundElsewhere {
    final bound = boundCompany;
    return bound != null && bound != _companyKey;
  }

  /// Bật / tắt do người dùng (công tắc, nút Dừng trên thông báo, lệnh tắt từ
  /// xa): bật thì ghim công ty hiện tại, tắt thì bỏ ghim.
  Future<void> _onStationChanged(bool on) =>
      _storage.put(_boundStorageKey, on ? _companyKey : null);

  /// Tên hiển thị (tên đã đặt, không thì tên thiết bị).
  String get displayName =>
      name.value.isNotEmpty ? name.value : (AgentDeviceName.label ?? '');

  /// Mã cố định của máy này khi làm Agent.
  String get stationId {
    final saved = _storage.get(_stationIdStorageKey)?.toString();
    if (saved != null && saved.isNotEmpty) return saved;
    final id = MqttPrintRelayTransport.randomId();
    unawaited(_storage.put(_stationIdStorageKey, id));
    return id;
  }

  late final PrintRelay relay = _buildRelay();
  bool _relayBuilt = false;

  PrintRelay _buildRelay() {
    _relayBuilt = true;
    return PrintRelay(
      queues: _queues,
      onJob: jobs.handle,
      canHandle: _canHandle,
      stationId: stationId,
      onControl: _onControl,
      stationInfo: _info,
      notification: notification ?? _notification,
      onStationChanged: _onStationChanged,
      log: PrintAgentModule.host.log,
    );
  }

  /// Chữ mặc định trên thông báo chạy nền (Android).
  static PrintRelayNotification _notification() => PrintRelayNotification(
    title: LocaleKeys.printerSetting_printStationRunning.tr,
    waiting: LocaleKeys.printerSetting_printStationWaiting.tr,
    printed: (count) =>
        LocaleKeys.printerSetting_printStationPrintedTr(count: count),
    channelName: LocaleKeys.printerSetting_printStationChannel.tr,
    stopLabel: LocaleKeys.printerSetting_printStationStop.tr,
  );

  Map<String, Object?> _info() => AgentStationInfo.build(
    name: displayName,
    model: AgentDeviceName.model,
    builtIn: _gateway.hasBuiltIn ? _printer.builtInSpec() : null,
    builtInConnected: _gateway.builtInConnected,
    statuses: watchdog.statuses,
    rank: rank,
    nets: _nets,
  );

  /// Ưu tiên làm trạm in chính của máy này ([AgentPrimary]).
  static int get rank {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return AgentPrimary.rankDesktop;
    }
    return Platform.isAndroid
        ? AgentPrimary.rankAndroid
        : AgentPrimary.rankOther;
  }

  /// Dải mạng hiện tại của máy này.
  Set<String> _nets = const {};

  /// Máy này là trạm in chính trong mạng (không có trạm nào cùng mạng ưu tiên
  /// hơn). Trạm dự phòng canh máy in thưa hơn; đơn tự động chỉ trạm chính in.
  final RxBool isPrimary = true.obs;

  Future<void> _refreshNets() async {
    final nets = AgentPrimary.netsOf(await PrintRelayLanServer.localIpv4s());
    if (nets.length == _nets.length && nets.containsAll(_nets)) return;
    _nets = nets;
    _updatePrimary();
    if (relay.isStation.value) unawaited(relay.refreshStationInfo());
  }

  void _updatePrimary() {
    final primary = AgentPrimary.isPrimary(
      selfId: stationId,
      selfRank: rank,
      selfNets: _nets,
      stations: relay.stations.value,
    );
    if (primary == isPrimary.value) return;
    isPrimary.value = primary;
    watchdog.standby = !primary;
    PrintAgentModule.host.log(
      primary
          ? '[AGENT] Máy này là trạm in chính trong mạng'
          : '[AGENT] Có trạm in ưu tiên hơn cùng mạng — máy này làm dự phòng',
    );
  }

  /// Lệnh tới máy in tích hợp: chỉ nhận khi máy này có máy in tích hợp. Máy in
  /// đã tắt nhận lệnh trên Agent này: bỏ qua — Agent khác vẫn nhận được.
  Future<bool> _canHandle(PrintRelayJob job) async {
    if (!AgentPrinterSwitches.accepts(job.printer)) return false;
    if (_macMismatch(job.printer)) return false;
    return job.printer.isBuiltIn
        ? _gateway.hasBuiltIn
        : (canHandleOther ?? PrintRelayStation.defaultCanHandle)(job);
  }

  /// Lệnh kèm MAC máy in mà máy in đã lưu ở cùng IP trên máy này có MAC KHÁC:
  /// IP đó là một máy in khác (VD chi nhánh khác trùng dải `192.168.1.x`).
  bool _macMismatch(PrintRelayPrinter target) {
    final want = normalizeMac(target.mac);
    if (want == null || target.isBuiltIn || target.isUsb) return false;
    final ip = target.address.trim();
    for (final p in _gateway.printers) {
      if (p.refAddress?.trim() != ip) continue;
      final have = normalizeMac(p.refMac);
      if (have != null && have != want) {
        PrintAgentModule.host.log(
          '[AGENT] Bỏ lệnh tới $ip: MAC ${target.mac} khác máy in ở IP này '
          '(${p.refMac})',
        );
        return true;
      }
    }
    return false;
  }

  /// `AA:BB:CC:DD:EE:FF` / `aa-bb-…` → `AABBCCDDEEFF`; `null` khi rỗng.
  static String? normalizeMac(String? mac) {
    final v = mac?.replaceAll(RegExp('[^0-9A-Fa-f]'), '').toUpperCase() ?? '';
    return v.isEmpty ? null : v;
  }

  /// Máy này không có máy in nào — Agent "rỗng", máy khác được phép tắt từ xa.
  bool get _hasNoPrinters =>
      _gateway.printers.isEmpty &&
      watchdog.statuses.isEmpty &&
      !_gateway.hasBuiltIn;

  /// Làm theo lệnh `stop` không: người dùng đã xác nhận ngắt cả khi còn máy in
  /// (`force`), hoặc máy này thật sự không có máy in.
  static bool shouldStop(
    Map<Object?, Object?> command, {
    required bool hasNoPrinters,
  }) => command['force'] == true || hasNoPrinters;

  /// Lệnh điều khiển từ máy khác. `stop`: ngắt kết nối trạm in (như tự tắt
  /// trên máy này). Không kèm `force` (máy gửi thấy trạm "rỗng") thì CHỈ làm
  /// theo khi máy này thật sự không có máy in — máy gửi có thể dùng thông tin
  /// cũ; `force` là người dùng đã xác nhận ngắt cả khi còn máy in.
  Future<void> _onControl(Map<Object?, Object?> command) async {
    if (command['cmd'] == AgentPrinterRemote.command) {
      return remote.apply(command);
    }
    if (command['cmd'] != 'stop') return;
    final by = command['by']?.toString() ?? '';
    final host = PrintAgentModule.host;
    if (!shouldStop(command, hasNoPrinters: _hasNoPrinters)) {
      host.log('[AGENT] Bỏ qua lệnh tắt từ xa ($by): máy này có máy in');
      return;
    }
    host.log('[AGENT] Ngắt kết nối trạm in theo lệnh từ xa ($by)');
    await setEnabled(false);
    host.notify(
      LocaleKeys.printerSetting_agentStoppedRemotelyTr(by: by),
      level: AgentNoticeLevel.warning,
      duration: const Duration(seconds: 8),
    );
  }

  /// Ngắt kết nối một máy Agent KHÁC: gửi lệnh tắt + quên trên máy này. Trạm
  /// còn máy in thì kèm `force` (người dùng đã xác nhận) — trạm bản cũ không
  /// biết cờ này ([AgentIdentity.canStopRemotely]).
  Future<bool> removeAgent(Map<Object?, Object?> station) async {
    final id = station['id']?.toString() ?? '';
    if (id.isEmpty) return false;
    final sent = await relay.sendControl(id, {
      'cmd': 'stop',
      'by': AgentDeviceName.label ?? displayName,
      if (!AgentIdentity.hasNoPrinters(station)) 'force': true,
    });
    if (sent) {
      KnownAgents.forget(id);
      PeerBuiltInPrinters.forget(id);
    }
    return sent;
  }

  /// XOÁ một máy Agent KHÁC khỏi danh sách (kể cả trạm chạy bản app cũ không
  /// ngắt từ xa được): gỡ bản ghi trực tuyến của trạm khỏi hàng đợi + quên trên
  /// máy này. Trạm còn bật Trạm in có thể tự báo lại. Trả `true` khi đã xoá
  /// khỏi danh sách trên máy này.
  Future<bool> deleteAgent(Map<Object?, Object?> station) async {
    final id = station['id']?.toString() ?? '';
    if (id.isEmpty) return false;
    final removed = await relay.removeStation(station);
    KnownAgents.forget(id);
    PeerBuiltInPrinters.forget(id);
    PrintAgentModule.host.log(
      '[AGENT] Xoá trạm $id khỏi danh sách (gỡ trên hàng đợi: $removed)',
    );
    return true;
  }

  /// Bật / tắt máy này làm Agent. Bản app khác trên cùng máy đang làm Agent →
  /// không bật, trả tên gói bản đó qua [onOtherApp].
  Future<bool> setEnabled(
    bool on, {
    void Function(String otherApp)? onOtherApp,
  }) async {
    if (!on) {
      final ok = await relay.setStation(false);
      await AgentDeviceLock.release();
      return ok;
    }
    final other = await AgentDeviceLock.acquire();
    if (other != null) {
      onOtherApp?.call(other);
      return false;
    }
    final ok = await relay.setStation(true);
    if (!ok) await AgentDeviceLock.release();
    return ok;
  }

  /// Gọi lúc vào app / đổi công ty: bật lại Agent nếu máy này đang làm Agent.
  Future<void> init() async {
    // Mã Agent theo máy (các bản build cùng máy chung một Agent) — phải có
    // TRƯỚC khi tạo trạm.
    if (!_relayBuilt) await AgentDeviceIdentity.adopt(_stationIdStorageKey);
    await AgentDeviceName.load();
    AgentPrinterSwitches.ensureLoaded();
    AgentMapLayout.ensureLoaded();
    AgentJobLogStore.ensureLoaded();
    _watchAgentMode();
    _watchInfo();
    _watchStations();
    _onCompany();
    var enabled = boundCompany == _companyKey;
    if (enabled) {
      final other = await AgentDeviceLock.acquire();
      if (other != null) {
        PrintAgentModule.host.log(
          '[AGENT] $other đang làm Agent trên máy này — không bật lại',
        );
        enabled = false;
      }
    }
    await relay.restore(enabled: enabled);
    if (!relay.isStation.value) await AgentDeviceLock.release();
    // Máy gửi: theo dõi Agent ở nền để khi máy in lỗi chuyển sang Agent không
    // phải chờ. Hoãn 20s — không tranh CPU / mạng lúc app đang khởi động.
    Timer(const Duration(seconds: 20), () => unawaited(relay.warmUp()));
  }

  String? _companyLoaded;

  /// Vào app / đổi công ty: chuyển cờ cũ sang ghim công ty, nạp tên + đếm lại
  /// số lệnh theo công ty mới.
  void _onCompany() {
    final key = _companyKey;
    if (_storage.get(_legacyEnabledKey) != null) {
      // Bản cũ: cờ chung cả máy — coi công ty đang mở là công ty gốc.
      if (_storage.get(_legacyEnabledKey) == true && boundCompany == null) {
        unawaited(_storage.put(_boundStorageKey, key));
      }
      unawaited(_storage.put(_legacyEnabledKey, null));
    }
    if (_companyLoaded == key) return;
    _companyLoaded = key;
    name.value = _loadName();
    jobs.reset();
  }

  /// Tạm dừng làm Agent khi rời công ty (đổi công ty / đăng xuất) — GIỮ ghim:
  /// quay lại công ty gốc thì [init] tự bật lại. Rút khỏi danh sách trực tuyến
  /// trên mọi kênh, dừng canh máy in, nhả khoá máy.
  Future<void> suspend() async {
    if (relay.isStation.value) {
      PrintAgentModule.host.log('[AGENT] Tạm dừng Agent (rời công ty)');
    }
    await relay.restore(enabled: false);
    await AgentDeviceLock.release();
  }

  bool _watching = false;
  bool _watchingStations = false;
  bool _watchingAgent = false;

  void _watchStations() {
    if (_watchingStations) return;
    _watchingStations = true;
    unawaited(_refreshNets());
    _gateway.networkChanges.listen((_) => unawaited(_refreshNets()));
    relay.stations.addListener(() {
      _updatePrimary();
      PeerBuiltInPrinters.ensureLoaded();
      PeerBuiltInPrinters.sync(relay.stations.value);
      // Agent vừa tắt vẫn được nhớ (ngoại tuyến + lần thấy cuối).
      KnownAgents.sync(relay.stations.value);
    });
  }

  Timer? _infoDebounce;
  String? _lastInfo;

  /// Thông tin máy in đổi (máy in tích hợp nhận ra sau khi bật, bật / tắt nhận
  /// lệnh, trạng thái kết nối...): gom trong 2s, chỉ báo lại khi THỰC SỰ đổi.
  void _watchInfo() {
    if (_watching) return;
    _watching = true;
    void refresh(Object? _) {
      _infoDebounce?.cancel();
      _infoDebounce = Timer(const Duration(seconds: 2), () {
        if (!relay.isStation.value) return;
        final signature = jsonEncode(_info());
        if (signature == _lastInfo) return;
        _lastInfo = signature;
        unawaited(relay.refreshStationInfo());
      });
    }

    _gateway.printersChanged.listen(refresh);
    _gateway.builtInChanges.listen(refresh);
    ever<String?>(AgentDeviceName.settingsName, refresh);
    ever<Set<String>>(AgentPrinterSwitches.off, refresh);
    ever<List<AgentPrinterStatus<P>>>(watchdog.statuses, refresh);
  }

  /// Máy Agent: bật bộ canh máy in (máy in tắt nguồn / mất mạng tự nối lại).
  void _watchAgentMode() {
    if (_watchingAgent) return;
    _watchingAgent = true;
    void sync() {
      if (relay.isStation.value) {
        watchdog.start();
        // Lệnh đang giữ (hết giấy) lần chạy trước: in tiếp.
        unawaited(jobs.restoreHeld());
      } else {
        watchdog.stop();
        // Thôi làm Agent (kể cả bấm "Dừng" trên thông báo): nhả khoá máy.
        unawaited(AgentDeviceLock.release());
      }
    }

    relay.isStation.addListener(sync);
    sync();
  }

  MqttPrintRelayTransport? _mqtt;
  String? _mqttKey;

  Future<List<PrintRelayTransport>> _queues() async {
    final key = PrintAgentModule.host.shopKey;
    if (key == null) return const [];
    return [...await _extraQueues(key), _mqttQueue(key)];
  }

  List<PrintRelayTransport> _extra = const [];
  String? _extraKey;
  Future<List<PrintRelayTransport>>? _extraOpening;

  /// Kênh riêng của app theo công ty — mở MỘT lần rồi dùng lại (relay hỏi
  /// [_queues] rất thường xuyên). Đổi công ty: rút kênh cũ khỏi danh sách trực
  /// tuyến rồi mới mở kênh mới. Mở lỗi (rỗng) thì lần sau thử lại.
  Future<List<PrintRelayTransport>> _extraQueues(String key) {
    final open = extraQueues;
    if (open == null) return Future.value(const []);
    if (_extraKey == key && _extra.isNotEmpty) return Future.value(_extra);
    return _extraOpening ??= () async {
      try {
        if (_extraKey != key) {
          for (final old in _extra) {
            await old.goOffline().catchError((Object _) {});
          }
          _extra = const [];
        }
        _extra = await open(key);
        _extraKey = key;
        return _extra;
      } finally {
        _extraOpening = null;
      }
    }();
  }

  /// Kênh MQTT của công ty: topic + khoá mã hoá suy ra từ mã công ty (máy cùng
  /// công ty tự ra cùng khoá, không phải trao đổi).
  MqttPrintRelayTransport _mqttQueue(String key) {
    final cached = _mqtt;
    if (cached != null && _mqttKey == key) return cached;
    unawaited(cached?.dispose());
    _mqttKey = key;
    return _mqtt = MqttPrintRelayTransport(
      secret: 'easypos-print-relay-v1|$key',
      config: mqttConfig,
      log: PrintAgentModule.host.log,
    );
  }

  // --- Máy in tích hợp của Agent khác ---------------------------------------

  /// Máy in ảo đại diện máy in tích hợp của một máy Agent.
  static bool isPeerBuiltIn(AgentPrinterRef printer) =>
      printer.refKind == AgentPrinterKind.builtIn &&
      PeerBuiltInPrinter.stationIdOf(printer.refAddress) != null;

  /// Hỏi các Agent đang trực tuyến và cập nhật danh sách máy in tích hợp.
  Future<List<Map<Object?, Object?>>> refreshPeerBuiltIns() async {
    PeerBuiltInPrinters.ensureLoaded();
    final stations = await relay.onlineStations();
    PeerBuiltInPrinters.sync(stations);
    KnownAgents.sync(stations);
    return stations;
  }

  /// Máy in tích hợp của các Agent đã BẬT và đang trực tuyến, dạng máy in của
  /// app (Agent tắt thì tạm bỏ qua, báo nhẹ một lần).
  Future<List<P>> peerBuiltInPrinters() => sender.peerBuiltIns();

  // --- Máy gửi -----------------------------------------------------------------

  Future<bool> willRelay(P printer) => sender.willRelay(printer);

  /// Thử in ảnh hoá đơn qua Agent. `null`: không áp dụng, nơi gọi in trực tiếp;
  /// `true` / `false`: Agent đã in / in lỗi (đã báo người dùng).
  Future<bool?> tryRelay({
    required Uint8List image,
    required String paper,
    required P printer,
    int quantity = 1,
    bool openDrawer = false,
    bool force = false,
    bool beep = false,
  }) => sender.tryReceipt(
    image: image,
    paper: paper,
    printer: printer,
    quantity: quantity,
    openDrawer: openDrawer,
    force: force,
    beep: beep,
  );

  /// Thử in các hàng tem qua Agent. Kết quả như [tryRelay].
  Future<bool?> tryRelayLabel({
    required List<Uint8List> images,
    required P printer,
    required LabelPerRow size,
    int copies = 1,
    bool force = false,
  }) => sender.tryLabel(
    images: images,
    printer: printer,
    size: size,
    copies: copies,
    force: force,
  );
}
