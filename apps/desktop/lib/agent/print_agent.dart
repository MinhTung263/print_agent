import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../relay/mqtt_relay.dart';
import '../relay/relay_crypto.dart';
import 'package:printer_label/desktop.dart';
import 'agent_config.dart';
import 'agent_preview.dart';
import 'agent_job.dart';
import 'agent_printer.dart';

export 'agent_job.dart';

/// Máy Agent desktop (Windows / Linux / macOS): báo trực tuyến như một Agent có
/// "máy in tích hợp" (= máy in LAN đã chọn ở cài đặt) — máy bán hàng EasyPOS tự
/// hiện máy in này ở mục "Máy in tích hợp của máy Agent". Nhận lệnh hoá đơn qua
/// MQTT → in ESC/POS thẳng ra máy in (không cần driver) → báo kết quả.
class PrintAgent extends ChangeNotifier {
  PrintAgent(this._config) : id = AgentConfig.agentId(RelayCrypto.randomId);

  /// Mã Agent cố định của máy này.
  final String id;

  AgentConfig _config;
  AgentConfig get config => _config;

  AgentState state = AgentState.off;
  final List<AgentJobEntry> log = [];

  /// Các máy Agent KHÁC của cửa hàng đang trực tuyến (thông tin trạm báo).
  List<Map<Object?, Object?>> peers = const [];

  /// Máy in của Agent kết nối được không (`null` = chưa kiểm tra / chưa chọn).
  bool? printerOk;

  /// Lệnh đang in / vừa xong (sơ đồ làm nổi máy in) — `null` khi không có.
  AgentPrintActivity? activity;
  Timer? _activityTimer;

  DateTime? lastJobAt;
  int get printed => log.where((e) => e.ok).length;
  int get failed => log.length - printed;

  MqttRelay? _relay;

  /// Khoá cửa hàng của [_relay] — đổi cửa hàng thì mở kết nối mới.
  String? _relayKey;
  StreamSubscription<(String, Map<String, Object?>)>? _jobsSub;
  StreamSubscription<bool>? _connSub;
  StreamSubscription<List<Map<Object?, Object?>>>? _peersSub;
  StreamSubscription<Map<Object?, Object?>>? _controlSub;
  final Set<String> _seen = {};

  /// Lệnh cũ hơn mốc này thì bỏ (tránh in dồn khi vừa mở lại) — như app.
  static const Duration _jobTtl = Duration(minutes: 2);

  static const List<String> _templates = [
    'temporaryPrintForm',
    'paymentPrintingForm',
    'processing',
    'cancel',
    'serve',
    'paymentQR',
    'prescription',
  ];

  /// "Quầy thu ngân · #A3F9" — giống cách app hiện tên Agent.
  String get label => '$displayName · $shortCode';

  String get displayName => _config.name.trim().isEmpty
      ? Platform.localHostname
      : _config.name.trim();

  /// Mã ngắn `#A3F9` (4 ký tự cuối mã Agent) — giống app.
  String get shortCode => '#${id.substring(id.length - 4).toUpperCase()}';

  /// "Windows" / "Linux" / "macOS".
  static String get osName =>
      Platform.isWindows ? 'Windows' : (Platform.isMacOS ? 'macOS' : 'Linux');

  /// Xem trước giao diện: dữ liệu mẫu, KHÔNG kết nối.
  void startPreview({int peerCount = 1, int printerCount = 3}) {
    state = AgentState.online;
    printerOk = true;
    log
      ..clear()
      ..addAll(AgentPreview.log());
    lastJobAt = log.first.at;
    activity = const AgentPrintActivity(AgentPrintPhase.printing, 'Quầy 2');
    peers = AgentPreview.peers(peerCount, printerCount);
    notifyListeners();
  }

  Map<String, Object?> get _info => {
    'id': id,
    'name': displayName,
    'model': '$osName · ${Platform.localHostname}',
    'app': 'vn.softdreams.easypos.desktop',
    if (_config.hasPrinter)
      'builtIn': {
        'paper': _config.paper.name,
        'templates': _templates,
        'ready': printerOk ?? true,
      },
    'printers': {
      'ok': _config.hasPrinter && printerOk != false ? 1 : 0,
      'total': _config.hasPrinter ? 1 : 0,
      'names': [
        if (_config.hasPrinter)
          {
            'name': 'Máy in của Agent',
            'ok': printerOk != false,
            'kind': UsbPrinters.isLocal(_config.printer) ? 'usb' : 'lan',
            'addr': UsbPrinters.label(_config.printer),
          },
      ],
    },
  };

  void _setState(AgentState s) {
    if (state == s) return;
    state = s;
    notifyListeners();
  }

  Future<void> start() async {
    if (!_config.ready) return;
    await _stop();
    _setState(AgentState.connecting);
    unawaited(checkPrinter());
    final key = RelayCrypto.shopKey(
      env: _config.env,
      companyId: _config.companyId!,
      ownerId: _config.ownerId!,
    );
    // Giữ kết nối MQTT giữa các lần bật / tắt (bật lại báo trực tuyến ngay);
    // đổi cửa hàng thì kết nối lại.
    if (_relayKey != key) await _disconnect();
    final relay = _relay ??= MqttRelay(
      crypto: RelayCrypto(key),
      log: debugPrint,
    );
    _relayKey = key;
    _connSub = relay.connection.listen(
      (ok) => _setState(ok ? AgentState.online : AgentState.offline),
    );
    try {
      await relay.goOnline(_info);
      _peersSub = relay.watchStations().listen((all) {
        peers = [
          for (final st in all)
            if (st['id'] != id) st,
        ];
        notifyListeners();
      }, onError: (Object _) {});
      // Lệnh tắt từ xa chỉ áp cho Agent KHÔNG có máy in.
      _controlSub = relay.watchControl(id).listen((cmd) {
        if (!_config.hasPrinter && cmd['cmd'] == 'stop') unawaited(stop());
      }, onError: (Object _) {});
      _jobsSub = relay.watchJobs().listen(
        (e) => unawaited(_handle(e.$1, e.$2)),
        onError: (Object e) => debugPrint('Nghe lệnh lỗi: $e'),
      );
      _setState(AgentState.online);
    } catch (e) {
      debugPrint('Bật Agent lỗi: $e');
      _setState(AgentState.offline);
    }
  }

  Future<void> stop() => _stop();

  /// Tắt hẳn (thoát ứng dụng): rút khỏi danh sách Agent + ngắt MQTT.
  Future<void> shutdown() async {
    await _stop();
    await _disconnect();
  }

  /// Tắt Agent: công tắc / trạng thái đổi NGAY, rồi mới rút khỏi danh sách
  /// Agent (giữ kết nối để bật lại nhanh).
  Future<void> _stop() async {
    final wasOn = state != AgentState.off;
    peers = const [];
    _setState(AgentState.off);
    await _jobsSub?.cancel();
    _jobsSub = null;
    await _connSub?.cancel();
    _connSub = null;
    await _peersSub?.cancel();
    _peersSub = null;
    await _controlSub?.cancel();
    _controlSub = null;
    if (wasOn) await _relay?.goOffline();
  }

  /// Ngắt hẳn kết nối MQTT (đăng xuất / đổi cửa hàng / thoát).
  Future<void> _disconnect() async {
    final relay = _relay;
    _relay = null;
    _relayKey = null;
    await relay?.dispose();
  }

  /// Xoá một máy Agent KHÁC không có máy in: gửi lệnh tắt (máy đó tự kiểm tra
  /// lại). `false` khi chưa kết nối / gửi lỗi.
  Future<bool> removePeer(Map<Object?, Object?> station) async {
    final relay = _relay;
    final peerId = station['id']?.toString() ?? '';
    if (relay == null || peerId.isEmpty) return false;
    try {
      await relay.sendControl(peerId, {'cmd': 'stop', 'by': displayName});
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Agent không có máy in nào (không báo máy in, không máy in tích hợp).
  static bool hasNoPrinters(Map<Object?, Object?> station) {
    if (station['builtIn'] is Map) return false;
    final printers = station['printers'];
    if (printers is! Map) return true;
    final total = printers['total'];
    return total is! int || total == 0;
  }

  /// Đăng xuất: tắt Agent, bỏ công ty đã lưu.
  Future<void> logout() async {
    await shutdown();
    AgentConfig.clearSession();
    _config = _config.withoutCompany();
    log.clear();
    notifyListeners();
  }

  /// Đổi cấu hình (lưu lại); đang bật thì báo lại / kết nối lại.
  Future<void> update(AgentConfig next) async {
    final reconnect =
        next.env != _config.env ||
        next.companyId != _config.companyId ||
        next.ownerId != _config.ownerId;
    final printerChanged = next.printer != _config.printer;
    _config = next..save();
    if (printerChanged) printerOk = null;
    notifyListeners();
    if (state == AgentState.off) return;
    if (reconnect) {
      await start();
    } else {
      if (printerChanged) await checkPrinter(announce: false);
      await _relay?.goOnline(_info);
    }
  }

  /// Kiểm tra máy in của Agent còn kết nối được; đổi trạng thái thì báo lại.
  Future<void> checkPrinter({bool announce = true}) async {
    if (!_config.hasPrinter) return;
    final ok = await AgentPrinter.reachable(_config.printer);
    if (ok == printerOk) return;
    printerOk = ok;
    notifyListeners();
    if (announce && state != AgentState.off) {
      await _relay?.goOnline(_info).catchError((Object _) {});
    }
  }

  Future<void> _handle(String jobId, Map<String, Object?> job) async {
    final relay = _relay;
    if (relay == null || !_seen.add(jobId)) return;
    final createdAt = job['createdAt'];
    if (createdAt is! int ||
        DateTime.now().millisecondsSinceEpoch - createdAt >
            _jobTtl.inMilliseconds) {
      return;
    }
    if (job['status'] != RelayStatus.pending) return;
    final target = job['targetStation']?.toString();
    if (target != null && target != id) return;
    final targeted = target == id;
    final address = AgentPrinter.targetOf(job, _config);
    if (address == null) {
      // Lệnh nhắm thẳng máy này mà không in được (tem / USB / chưa chọn máy
      // in): báo lỗi ngay để máy gửi khỏi chờ.
      if (targeted) {
        await relay.ackJob(jobId).catchError((Object _) {});
        await relay.completeJob(jobId, success: false);
        _record(
          job,
          error: job['kind'] == 'label'
              ? 'Agent máy tính chưa in được tem'
              : 'Chưa chọn máy in cho Agent',
        );
      }
      return;
    }
    if (targeted) {
      unawaited(relay.ackJob(jobId).catchError((Object _) {}));
    } else {
      // Không nhắm máy nào: chỉ giành khi bật "in hộ máy in LAN" và máy in kết
      // nối được từ đây — Agent ở mạng khác không giành mất lệnh của trạm khác.
      if (!_config.acceptAll || !await AgentPrinter.reachable(address)) return;
      if (!await relay.claimJob(jobId)) return;
    }
    final sender = job['sender']?.toString();
    _setActivity(AgentPrintActivity(AgentPrintPhase.printing, sender));
    final error = await AgentPrinter.printJob(job, address);
    final ok = error == null;
    _setActivity(
      AgentPrintActivity(
        ok ? AgentPrintPhase.done : AgentPrintPhase.failed,
        sender,
      ),
      clearAfter: const Duration(seconds: 5),
    );
    await relay.completeJob(jobId, success: ok).catchError((Object _) {});
    _record(job, error: error);
  }

  /// In thử ra máy in của Agent; `null` = in được, ngược lại là lý do lỗi.
  Future<String?> printTest() async {
    final error = await AgentPrinter.printTest(_config, label);
    if (_config.hasPrinter) {
      printerOk = error == null || !error.startsWith('Không kết nối');
      notifyListeners();
    }
    return error;
  }

  void _setActivity(AgentPrintActivity a, {Duration? clearAfter}) {
    _activityTimer?.cancel();
    activity = a;
    notifyListeners();
    if (clearAfter != null) {
      _activityTimer = Timer(clearAfter, () {
        activity = null;
        notifyListeners();
      });
    }
  }

  void _record(Map<String, Object?> job, {String? error}) {
    lastJobAt = DateTime.now();
    log.insert(
      0,
      AgentJobEntry(
        at: DateTime.now(),
        ok: error == null,
        sender: job['sender']?.toString(),
        printerName: job['printerName']?.toString(),
        copies: job['quantity'] is int ? job['quantity']! as int : 1,
        error: error,
      ),
    );
    if (log.length > 50) log.removeRange(50, log.length);
    notifyListeners();
  }

  @override
  void dispose() {
    _activityTimer?.cancel();
    unawaited(shutdown());
    super.dispose();
  }
}
