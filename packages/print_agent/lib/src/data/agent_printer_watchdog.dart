import '../print_agent_module.dart';
import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:print_agent_core/print_agent_core.dart';

import '../domain/entities/agent_printer_ref.dart';
import '../domain/entities/agent_printer_status.dart';
import '../domain/ports/agent_printer_gateway.dart';

/// Máy Agent: giữ kết nối tới máy in luôn sẵn sàng khi máy in tắt nguồn / mất
/// mạng rồi bật lại.
///
/// Dùng dịch vụ máy in của app chủ qua [AgentPrinterGateway].
///
/// - [waitUntilReady]: lệnh in tới mà máy in chưa kết nối được thì thử lại vài
///   giây (máy in đang khởi động lại), tìm lại IP theo MAC nếu máy in nhận IP mới.
/// - Canh định kỳ ([start]): mỗi [_interval] kiểm tra nhẹ máy in LAN cùng mạng
///   (bỏ qua khi đang in), máy in tích hợp mất kết nối thì nối lại — để lệnh tới
///   là in được ngay.
class AgentPrinterWatchdog<P extends AgentPrinterRef> {
  AgentPrinterWatchdog(this._gateway);

  final AgentPrinterGateway<P> _gateway;

  static void _log(String message) => PrintAgentModule.host.log(message);

  static const Duration _interval = Duration(seconds: 60);

  Timer? _timer;
  bool _checking = false;

  /// Dò nhanh ([_quickProbe]): máy in bật / tắt là sơ đồ đổi gần như ngay.
  /// Đang mở màn Máy Agent thì dày ([_probeVisible]), chạy nền thì thưa hơn.
  static const Duration _probeVisible = Duration(seconds: 3);
  static const Duration _probeBackground = Duration(seconds: 15);

  /// Trạm dự phòng (có trạm in chính cùng mạng): dò nền thưa hơn — máy in LAN
  /// chỉ nhận một kết nối 9100 một lúc, không tranh với trạm chính.
  static const Duration _probeStandby = Duration(seconds: 60);
  bool _standby = false;

  /// Đổi giữa trạm chính / dự phòng ([AgentPrimary]).
  set standby(bool on) {
    if (_standby == on) return;
    _standby = on;
    _restartProbe();
  }

  bool get standby => _standby;
  Timer? _probeTimer;
  bool _probing = false;

  /// Máy in NÀO được dò rất nhanh ([fastEvery]) — máy USB: rút / cắm lại hiện ngay (kiểm tra máy in
  /// USB chỉ hỏi hệ điều hành, không mở kết nối nên dò dày được; máy LAN dò dày sẽ chen cổng 9100).
  /// App chủ đặt (mặc định không máy nào).
  static bool Function(AgentPrinterRef printer)? fastProbe;

  /// Chu kỳ dò nhanh.
  static Duration fastEvery = const Duration(milliseconds: 1500);
  Timer? _fastTimer;
  bool _fastBusy = false;

  /// Dò nhanh các máy in được [fastProbe] chọn; đổi trạng thái thì cập nhật sơ đồ ngay.
  Future<void> _probeFast() async {
    final pick = fastProbe;
    if (pick == null || _fastBusy || _probing || _checking || _printing > 0) {
      return;
    }
    _fastBusy = true;
    try {
      final targets = <P>[
        if (_gateway.hasBuiltIn && pick(_gateway.builtInPrinter()))
          _gateway.builtInPrinter(),
        for (final p in List.of(_gateway.printers))
          if (pick(p) && p.refKind != AgentPrinterKind.builtIn) p,
      ];
      for (final p in targets) {
        if (_printing > 0) {
          return;
        }
        final ok = p.refKind == AgentPrinterKind.builtIn
            ? await _gateway.isReady(p)
            : await _gateway.isUsbAttached(p);
        final was = statuses
            .where((s) => _keyOf(s.printer) == _keyOf(p))
            .firstOrNull
            ?.state;
        _setStatus(
          p,
          ok ? AgentPrinterState.connected : AgentPrinterState.disconnected,
        );
        if (was != null && was != AgentPrinterState.connected && ok) {
          _log('[AGENT] ${p.refName} đã cắm lại');
        } else if (was == AgentPrinterState.connected && !ok) {
          _log('[AGENT] ${p.refName} bị rút / mất kết nối');
        }
      }
    } catch (_) {
    } finally {
      _fastBusy = false;
    }
  }

  int _watchers = 0;
  StreamSubscription<bool>? _builtInSub;
  StreamSubscription<void>? _netSub;
  Timer? _netDebounce;

  /// Số lệnh đang in — canh định kỳ bỏ qua lúc đang in để không chen kết nối.
  int _printing = 0;

  /// Máy in (khoá) đang mất kết nối — để chỉ ghi log khi đổi trạng thái.
  final Set<String> _down = {};

  /// Trạng thái từng máy in — màn quản lý máy Agent hiển thị.
  final RxList<AgentPrinterStatus<P>> statuses = <AgentPrinterStatus<P>>[].obs;

  /// Lúc kiểm tra gần nhất (cả lượt).
  final Rxn<DateTime> lastCheckAt = Rxn<DateTime>();

  /// Đang kiểm tra (hiện vòng xoay trên màn quản lý).
  final RxBool isChecking = false.obs;

  /// Kiểm tra ngay (nút "Kiểm tra lại" trên màn quản lý).
  Future<void> checkNow() => _checkAll(force: true);

  /// Lần cuối mỗi máy in được xác nhận kết nối (mọi lượt dò, kể cả không đổi trạng thái).
  final Map<String, DateTime> _okAt = {};

  /// Máy in vừa được xác nhận kết nối trong chừng này thì lệnh in tới KHÔNG hỏi lại — in ngay
  /// (vòng dò nền chạy mỗi 3–15 giây). Nếu thực tế máy đã mất, lệnh in lỗi và chạy lại đường chờ
  /// đầy đủ ([waitUntilReady] với `allowFresh: false`).
  static const Duration freshFor = Duration(seconds: 10);

  /// Máy in [printer] vừa được xác nhận kết nối gần đây.
  bool isFresh(P printer) {
    final at = _okAt[_keyOf(printer)];
    return at != null && DateTime.now().difference(at) < freshFor;
  }

  /// Bỏ xác nhận gần đây của [printer] (lệnh in vừa lỗi: không tin kết quả dò cũ).
  void forgetFresh(P printer) => _okAt.remove(_keyOf(printer));

  void _setStatus(P printer, AgentPrinterState state, {String? note}) {
    final key = _keyOf(printer);
    if (state == AgentPrinterState.connected) {
      _okAt[key] = DateTime.now();
    } else {
      _okAt.remove(key);
    }
    final list = List<AgentPrinterStatus<P>>.of(statuses);
    final i = list.indexWhere((e) => _keyOf(e.printer) == key);
    // Không đổi gì: không phát lại (màn sơ đồ khỏi dựng lại mỗi lượt canh).
    if (i >= 0 &&
        list[i].state == state &&
        (note == null || note == list[i].note) &&
        list[i].printer.refName == printer.refName) {
      return;
    }
    final status = AgentPrinterStatus<P>(
      printer: printer,
      state: state,
      checkedAt: DateTime.now(),
      note: note ?? (i >= 0 ? list[i].note : null),
    );
    if (i >= 0) {
      list[i] = status;
    } else {
      list.add(status);
    }
    statuses.assignAll(list);
  }

  /// Cập nhật trạng thái [printer] từ bên ngoài (VD sau khi "Kết nối lại").
  /// [replaced]: máy in cũ khi máy in vừa đổi IP — bỏ dòng cũ.
  void report(P printer, AgentPrinterState state, {String? note, P? replaced}) {
    if (replaced != null) {
      statuses.removeWhere((e) => _keyOf(e.printer) == _keyOf(replaced));
      _down.remove('${replaced.refId ?? replaced.refAddress}');
    }
    if (state == AgentPrinterState.connected) {
      _down.remove('${printer.refId ?? printer.refAddress}');
    }
    _setStatus(printer, state, note: note);
  }

  /// Đặt mọi máy in về "đang kiểm tra" (VD vừa đổi Wi-Fi — trạng thái cũ sai).
  void markAllChecking() {
    statuses.assignAll([
      for (final s in statuses)
        AgentPrinterStatus<P>(
          printer: s.printer,
          state: AgentPrinterState.checking,
          checkedAt: s.checkedAt,
          note: s.note,
        ),
    ]);
  }

  /// Bỏ trạng thái của máy in KHÔNG còn trong cài đặt (vừa xoá / đổi IP) và
  /// máy in tích hợp khi máy này không còn máy in tích hợp — nếu không sơ đồ
  /// và thông tin Agent báo cho máy khác vẫn hiện máy in đã xoá.
  void prune() {
    final keep = {for (final p in _gateway.printers) _keyOf(p)};
    final hasBuiltIn = _gateway.hasBuiltIn;
    bool stale(AgentPrinterStatus<P> s) =>
        s.printer.refKind == AgentPrinterKind.builtIn
        ? !hasBuiltIn
        : !keep.contains(_keyOf(s.printer));
    final removed = [
      for (final s in statuses)
        if (stale(s)) s,
    ];
    if (removed.isEmpty) return;
    for (final s in removed) {
      _down.remove('${s.printer.refId ?? s.printer.refAddress}');
    }
    statuses.removeWhere(stale);
  }

  static String _keyOf(AgentPrinterRef p) =>
      '${p.refId ?? ''}|${p.refKind?.name}|${p.refAddress ?? ''}';

  void start() {
    if (_timer != null) return;
    _log('[AGENT] Bật canh máy in (mỗi ${_interval.inSeconds}s)');
    _timer = Timer.periodic(_interval, (_) => unawaited(_checkAll()));
    unawaited(_checkAll());
    _restartProbe();
    _fastTimer?.cancel();
    _fastTimer = Timer.periodic(fastEvery, (_) => unawaited(_probeFast()));
    // Máy in tích hợp đổi trạng thái (native báo): cập nhật sơ đồ ngay.
    _builtInSub = _gateway.builtInChanges.listen((ok) {
      if (!_gateway.hasBuiltIn) return;
      _setStatus(
        _gateway.builtInPrinter(),
        ok ? AgentPrinterState.connected : AgentPrinterState.disconnected,
      );
    });
    // Đổi Wi-Fi / mạng: kiểm tra lại ngay (chờ ~2s cho mạng mới nhận IP).
    _netSub = _gateway.networkChanges.listen((_) {
      _netDebounce?.cancel();
      _netDebounce = Timer(const Duration(seconds: 1), () {
        if (_timer == null) return;
        _log('[AGENT] Đổi mạng — kiểm tra lại máy in');
        markAllChecking();
        unawaited(checkNow());
      });
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _probeTimer?.cancel();
    _probeTimer = null;
    _fastTimer?.cancel();
    _fastTimer = null;
    unawaited(_builtInSub?.cancel());
    _builtInSub = null;
    _netDebounce?.cancel();
    _netDebounce = null;
    unawaited(_netSub?.cancel());
    _netSub = null;
    _down.clear();
    _okAt.clear();
    statuses.clear();
  }

  /// Màn Máy Agent đang mở: dò dày hơn để bật / tắt máy in hiện ngay. Gọi
  /// `watchClosely(true)` khi mở, `watchClosely(false)` khi đóng.
  void watchClosely(bool on) {
    _watchers = (_watchers + (on ? 1 : -1)).clamp(0, 99);
    _restartProbe();
    if (on) unawaited(_quickProbe());
  }

  void _restartProbe() {
    _probeTimer?.cancel();
    if (_timer == null) return;
    _probeTimer = Timer.periodic(
      _watchers > 0
          ? _probeVisible
          : (_standby ? _probeStandby : _probeBackground),
      (_) => unawaited(_quickProbe()),
    );
  }

  /// Dò nhẹ, song song: mở rồi đóng ngay cổng in (9100) của các máy in LAN cùng
  /// mạng, xem máy in USB còn cắm. Không quét mạng, không chen lúc đang in.
  /// Máy in vừa tắt → "mất kết nối" ngay (kèm tìm theo MAC một lần, phòng đổi
  /// IP); vừa bật lại → "đã kết nối" ngay khi cổng in mở.
  Future<void> _quickProbe() async {
    if (_probing || _checking || _printing > 0 || _timer == null) return;
    _probing = true;
    try {
      prune();
      final prefixes = (await PrintRelayLanServer.localIpv4s())
          .map((ip) => ip.split('.').take(3).join('.'))
          .toSet();
      final lan = [
        for (final p in List.of(_gateway.printers))
          if (p.refKind == AgentPrinterKind.lan &&
              prefixes.contains(
                (p.refAddress ?? '').trim().split('.').take(3).join('.'),
              ))
            p,
      ];
      final alive = await Future.wait([
        for (final p in lan) _alive(p, p.refAddress!.trim()),
      ]);
      if (_printing > 0) return;
      for (var i = 0; i < lan.length; i++) {
        final p = lan[i];
        final key = '${p.refId ?? p.refAddress}';
        if (alive[i]) {
          if (_down.remove(key)) {
            _log('[AGENT] ${p.refName} (${p.refAddress}) đã bật lại');
          }
          _setStatus(p, AgentPrinterState.connected);
        } else {
          _setStatus(p, AgentPrinterState.disconnected);
          // Mới tắt: tìm theo MAC một lần (máy in bật lại có thể nhận IP mới) —
          // các lượt dò sau không quét mạng nữa.
          if (_down.add(key)) {
            _log('[AGENT] ${p.refName} (${p.refAddress}) không trả lời');
            unawaited(_relocate(p, p.refAddress!.trim()));
          }
        }
      }
      await _probeBuiltIn();
      for (final p in List.of(_gateway.printers)) {
        if (p.refKind != AgentPrinterKind.usb) continue;
        _setStatus(
          p,
          await _gateway.isUsbAttached(p)
              ? AgentPrinterState.connected
              : AgentPrinterState.disconnected,
        );
      }
    } catch (_) {
    } finally {
      _probing = false;
    }
  }

  /// Máy in chính của Agent (LAN / USB) còn kết nối không: rút / cắm lại USB, tắt / bật
  /// máy in LAN phải đổi trạng thái ngay — không chờ lượt canh 60s (lượt đó chỉ nối lại
  /// khi ĐÃ báo mất kết nối, nên rút USB mà vẫn hiện "đã kết nối" mãi). Mất kết nối thì
  /// nối lại / tìm theo MAC MỘT lần ([_down]), các lượt sau không quét mạng nữa.
  Future<void> _probeBuiltIn() async {
    if (!_gateway.hasBuiltIn) return;
    final printer = _gateway.builtInPrinter();
    final ok = await _gateway.isReady(printer);
    if (_printing > 0) return;
    _setStatus(
      printer,
      ok ? AgentPrinterState.connected : AgentPrinterState.disconnected,
    );
    const key = 'builtin';
    if (ok) {
      if (_down.remove(key)) _log('[AGENT] Máy in của trạm in đã kết nối lại');
    } else if (_down.add(key)) {
      _log('[AGENT] Máy in của trạm in không trả lời');
      await _gateway.reconnectBuiltIn();
    }
  }

  /// Máy ở [ip] còn bật: cổng in mở, hoặc từ chối kết nối (máy in đang bận phục
  /// vụ máy khác — vẫn là đang bật, không báo mất kết nối nhầm).
  /// App chủ thay cách kiểm tra máy in LAN còn bật (mặc định [isAlive]) — VD không coi
  /// "từ chối kết nối" của máy khác nhận IP cũ là máy in còn bật.
  static Future<bool> Function(AgentPrinterRef printer)? aliveCheck;

  static Future<bool> _alive(AgentPrinterRef printer, String ip) =>
      (aliveCheck ?? (_) => isAlive(ip))(printer);

  static Future<bool> isAlive(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        9100,
        timeout: const Duration(milliseconds: 1500),
      );
      socket.destroy();
      return true;
    } on SocketException catch (e) {
      final code = e.osError?.errorCode;
      return code == 111 || code == 61; // ECONNREFUSED (Android / iOS)
    } catch (_) {
      return false;
    }
  }

  /// Bọc một lệnh in của máy Agent: đánh dấu đang in (canh định kỳ tạm nghỉ).
  Future<T> printing<T>(Future<T> Function() action) async {
    _printing++;
    try {
      return await action();
    } finally {
      _printing--;
    }
  }

  /// Chờ [printer] kết nối được, tối đa [timeout] (thử lại mỗi 2s). Máy LAN không
  /// tới được thì tìm lại theo MAC (máy in bật lại nhận IP mới). Trả máy in dùng
  /// được (có thể IP mới) hoặc `null` khi hết giờ.
  Future<P?> waitUntilReady(
    P printer, {
    Duration timeout = const Duration(seconds: 14),
    bool allowFresh = true,
  }) async {
    // Vừa dò xong và máy in khoẻ: không hỏi lại (tiết kiệm 0,2–1,5s mỗi lệnh).
    if (allowFresh && isFresh(printer)) return printer;
    final deadline = DateTime.now().add(timeout);
    var target = printer;
    var relocated = false;
    var attempt = 0;
    while (true) {
      attempt++;
      if (await _gateway.isReady(target)) {
        if (attempt > 1) {
          _log('[AGENT] ${target.refName} sẵn sàng sau $attempt lần thử');
        }
        _setStatus(target, AgentPrinterState.connected);
        return target;
      }
      // Máy in LAN — hoặc máy in có MAC (VD máy in LAN đóng vai "máy in tích
      // hợp" của Agent máy tính): thử tìm lại theo MAC một lần.
      if (!relocated && _relocatable(target)) {
        relocated = true;
        final moved = await _gateway.relocate(target);
        if (moved != null) {
          target = moved;
          continue;
        }
      }
      if (DateTime.now().isAfter(deadline)) {
        _log('[AGENT] ${target.refName} chưa sẵn sàng sau $attempt lần');
        _setStatus(target, AgentPrinterState.disconnected);
        return null;
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _checkAll({bool force = false}) async {
    if (_checking || (_printing > 0 && !force)) return;
    _checking = true;
    isChecking.value = true;
    try {
      // Máy in tích hợp (Sunmi / T1-G...) mất kết nối: nối lại.
      if (_gateway.hasBuiltIn && !_gateway.builtInConnected) {
        _log('[AGENT] Máy in tích hợp mất kết nối — nối lại');
        await _gateway.reconnectBuiltIn();
      }
      final mine = await PrintRelayLanServer.localIpv4s();
      final prefixes = mine
          .map((ip) => ip.split('.').take(3).join('.'))
          .toSet();
      // Máy in tích hợp của chính máy Agent.
      if (_gateway.hasBuiltIn) {
        _setStatus(
          _gateway.builtInPrinter(),
          _gateway.builtInConnected
              ? AgentPrinterState.connected
              : AgentPrinterState.disconnected,
        );
      }
      final lan = <(P, String)>[];
      for (final printer in List.of(_gateway.printers)) {
        final ip = printer.refAddress?.trim() ?? '';
        switch (printer.refKind) {
          case AgentPrinterKind.lan:
            if (prefixes.contains(ip.split('.').take(3).join('.'))) {
              lan.add((printer, ip));
            } else {
              _setStatus(printer, AgentPrinterState.otherNetwork);
            }
          case AgentPrinterKind.usb:
            _setStatus(
              printer,
              await _gateway.isUsbAttached(printer)
                  ? AgentPrinterState.connected
                  : AgentPrinterState.disconnected,
            );
          default:
            continue;
        }
      }
      if ((_printing > 0 || _timer == null) && !force) return;
      await _checkLans(lan, force: force);
      lastCheckAt.value = DateTime.now();
    } catch (e) {
      _log('[AGENT] Canh máy in lỗi: $e');
    } finally {
      _checking = false;
      isChecking.value = false;
    }
  }

  /// Dò cổng 9100 mọi máy in LAN cùng mạng CÙNG LÚC (mỗi máy tắt tốn tới
  /// 1,5s — dò lần lượt thì càng nhiều máy càng chậm); máy không trả lời mới
  /// tìm lại theo MAC, lần lượt (quét mạng nặng, không chạy chồng).
  Future<void> _checkLans(List<(P, String)> lan, {required bool force}) async {
    final open = await Future.wait([for (final (p, ip) in lan) _alive(p, ip)]);
    final down = <(P, String)>[];
    for (var i = 0; i < lan.length; i++) {
      final (printer, ip) = lan[i];
      if (open[i]) {
        if (_down.remove('${printer.refId ?? ip}')) {
          _log('[AGENT] ${printer.refName} ($ip) đã kết nối lại');
        }
        _setStatus(printer, AgentPrinterState.connected);
      } else {
        down.add(lan[i]);
      }
    }
    for (final (printer, ip) in down) {
      if ((_printing > 0 || _timer == null) && !force) return;
      await _relocate(printer, ip);
    }
  }

  /// Máy in không trả lời: có thể bật lại nhận IP mới (DHCP) — tìm theo MAC,
  /// cập nhật luôn.
  Future<void> _relocate(P printer, String ip) async {
    final key = '${printer.refId ?? ip}';
    if (_down.add(key)) {
      _log('[AGENT] ${printer.refName} ($ip) không trả lời — tìm lại');
    }
    final moved = await _gateway.relocate(printer);
    if (moved != null) {
      _down.remove(key);
      _log('[AGENT] ${printer.refName} đổi IP $ip → ${moved.refAddress}');
      statuses.removeWhere((e) => _keyOf(e.printer) == _keyOf(printer));
      _setStatus(
        moved,
        AgentPrinterState.connected,
        note: '$ip → ${moved.refAddress}',
      );
      return;
    }
    _setStatus(printer, AgentPrinterState.disconnected);
  }

  static bool _relocatable(AgentPrinterRef p) =>
      p.refKind == AgentPrinterKind.lan ||
      (p.refKind != AgentPrinterKind.usb &&
          p.refKind != AgentPrinterKind.bluetooth &&
          (p.refMac?.isNotEmpty ?? false));

  /// Cổng in (9100) của [ip] có mở không — thử nhanh, không gửi gì.
  static Future<bool> tcpOpen(String ip) => _tcpOpen(ip);

  static Future<bool> _tcpOpen(String ip) async {
    try {
      final socket = await Socket.connect(
        ip,
        9100,
        timeout: const Duration(milliseconds: 1500),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
