import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';

import '../desktop/keep_awake.dart';
import '../printers/data/desktop_printer_discovery.dart';
import '../printers/printer_type_detector.dart';
import 'label_preset.dart';

import '../printers/paper_size_detector.dart';
import 'agent_config.dart';
import 'agent_printer.dart';
import 'printer_settings.dart';
import 'agent_store.dart';
import 'desktop_agent_host.dart';
import 'desktop_job_printer.dart';
import 'desktop_printer.dart';
import 'desktop_printer_gateway.dart';
import 'desktop_web_print.dart';
import 'desktop_printer_auto_add.dart';
import '../auth/auth_session.dart';
import '../store/printer_auto_add.dart';
import '../store/printer_auto_add_plan.dart' show FoundPrinter;
import '../ui/dashboard/desktop_header.dart';
import 'desktop_wifi.dart';

/// Agent máy tính (Windows / Linux / macOS): dùng chung [AgentService] + màn
/// Máy Agent với app EasyPOS — nhận lệnh như Agent Android (giành lệnh, đường
/// LAN 9101, điều khiển từ xa), in ESC/POS thẳng ra máy in không cần driver.
///
/// Lớp này chỉ giữ phần riêng của máy tính: cấu hình đăng nhập / máy in, khay
/// hệ thống ([isOn], [addListener]), in thử.
class DesktopAgent extends ChangeNotifier {
  DesktopAgent(this._config) {
    _migrate();
    PrintAgentModule.init(DesktopAgentHost(() => _config));
    gateway = DesktopPrinterGateway(
      () => _config,
      // Máy in của Agent đổi IP (tìm lại theo MAC): lưu địa chỉ mới.
      onRelocated: (address) => update(_config.copyWith(printer: address)),
    );
    service = AgentService<DesktopPrinter>(
      gateway: gateway,
      printer: DesktopJobPrinter(
        () => _config,
        gateway,
        settingsOf: settingsOf,
      ),
      // Đi qua được tường lửa chỉ mở cổng web.
      mqttConfig: const MqttRelayConfig.secureWebSocket(),
      canHandleOther: _canHandleLan,
    );
    PrintAgentUi.init(
      DesktopAgentUiKit(this),
      station: AgentServiceStation(
        service,
        wifi: const DesktopWifi(),
        networkChanges: gateway.networkChanges,
      ),
    );
    service.relay.isStation.addListener(_onStationChanged);
    gateway.builtInChanges.listen((_) => notifyListeners());
    _wake = WakeDetector(_onWake)..start();
  }

  StreamSubscription<void>? _autoAddNet;

  /// Phiên gọi API EasyPOS của công ty (tự thêm máy in vào cửa hàng).
  late final AuthSession auth = AuthSession(companyId: () => _config.companyId);

  /// Tự thêm máy in LAN dò thấy vào danh sách máy in của cửa hàng.
  late final PrinterAutoAdd autoAdd = desktopPrinterAutoAdd(this);

  late final WakeDetector _wake;

  /// Cổng web: trang EasyPOS trên trình duyệt của máy này in qua trạm in
  /// (không cần driver). Thêm trang được phép ở cấu hình `webOrigins`.
  late final WebBridgeServer web = WebBridgeServer(
    DesktopWebPrint(this),
    policy: () => WebOriginPolicy.parse(AgentStore.get('webOrigins')),
    log: PrintAgentModule.host.log,
  );

  /// Đang làm Agent: chặn máy ngủ (máy ngủ = không nhận lệnh in).
  void _onStationChanged() {
    unawaited(KeepAwake.set(isOn));
    // Vừa bật trạm in: dò + thêm máy in sớm (không chờ lượt định kỳ).
    if (isOn) autoAdd.networkChanged();
    notifyListeners();
  }

  /// Máy vừa ngủ dậy: kiểm tra lại máy in + báo lại thông tin trạm ngay, không
  /// chờ nhịp canh định kỳ (MQTT tự nối lại).
  void _onWake() {
    PrintAgentModule.host.log('[AGENT] Máy vừa thức dậy — kiểm tra lại máy in');
    unawaited(gateway.reconnectBuiltIn());
    if (isOn) {
      unawaited(service.watchdog.checkNow());
      unawaited(service.relay.refreshStationInfo());
    }
  }

  /// Máy in LAN của Agent chưa biết MAC: đọc từ bảng ARP (sau khi vừa mở kết
  /// nối tới máy in) để sau này tìm lại được khi máy in đổi IP.
  Future<void> _learnPrinterMac() async {
    final address = _config.printer.trim();
    if (address.isEmpty ||
        _config.printerMac.isNotEmpty ||
        UsbPrinters.isLocal(address)) {
      return;
    }
    final parsed = parsePrinterAddress(address);
    if (parsed == null || !await AgentPrinter.reachable(address)) return;
    final mac = await ArpTable.macOf(parsed.$1);
    if (mac == null || _config.printer.trim() != address) return;
    PrintAgentModule.host.log('[AGENT] MAC máy in $address: $mac');
    _config = _config.copyWith(printerMac: mac)..save();
  }

  AgentConfig _config;
  AgentConfig get config => _config;

  late final DesktopPrinterGateway gateway;
  late final AgentService<DesktopPrinter> service;

  /// Đang làm Agent (nhận lệnh).
  bool get isOn => service.relay.isStation.value;

  /// Máy in của Agent kết nối được không (`null` = chưa chọn máy in).
  bool? get printerOk => _config.hasPrinter ? gateway.connected : null;

  /// Bản trước lưu mã Agent / tên / tự bật ở khoá riêng: chuyển sang khoá của
  /// module để máy bán hàng vẫn nhận ra đúng Agent này.
  void _migrate() {
    void move(String from, String to, String? value) {
      if (value == null || value.isEmpty) return;
      if (AgentStore.get('m.$to') != null) return;
      AgentStore.set('m.$to', '"$value"');
    }

    move('id', 'print_station_id', AgentStore.get('id'));
    move('name', 'print_station_name', _config.name);
    // Bản trước tự bật Agent theo "Tự chạy": ghim công ty đang đăng nhập —
    // chỉ chuyển MỘT lần (đánh dấu), người dùng tắt rồi thì không bật lại.
    if (AgentStore.get('migratedBound') == null) {
      if (_config.autoStart &&
          _config.ready &&
          AgentStore.get('m.print_station_bound_company') == null) {
        AgentStore.set(
          'm.print_station_bound_company',
          '"${_config.companyId}"',
        );
      }
      AgentStore.set('migratedBound', '1');
    }
  }

  /// Lệnh in tới máy in KHÁC máy in chính: chỉ nhận khi đó là máy in của trạm này (đã thêm
  /// tay hoặc tự tìm thấy khi quét mạng) và kết nối được từ đây — Agent ở mạng khác không
  /// giành mất lệnh. Nhận mọi loại lệnh (hoá đơn, tem, USB).
  Future<bool> _canHandleLan(PrintRelayJob job) async {
    final extra = gateway.extras.byAddress(job.printer.address);
    if (extra == null) return false;
    return AgentPrinter.reachable(extra.address, mac: extra.mac);
  }

  /// Vào công ty (sau đăng nhập / mở app): khôi phục trạng thái Agent.
  Future<void> start() async {
    if (!_config.ready) return;
    await service.init();
    _startUsbWatch();
    autoAdd.start();
    _autoAddNet ??= gateway.networkChanges.listen(
      (_) => autoAdd.networkChanged(),
    );
    unawaited(gateway.reconnectBuiltIn());
    unawaited(_learnPrinterMac());
    // Bản trước lưu ĐỊA CHỈ làm tên máy in và luôn coi là máy in hoá đơn: nhận ra lại.
    if (_config.hasPrinter && _config.printerName == _config.printer) {
      unawaited(identifyPrinter());
    }
  }

  Future<void> setOn(bool on) => service.setEnabled(on);

  /// Thoát ứng dụng: rút khỏi danh sách Agent, thôi chặn máy ngủ.
  Future<void> shutdown() async {
    _usbTimer?.cancel();
    _wake.stop();
    _stopAutoAdd();
    await web.stop();
    await KeepAwake.set(false);
    // Tạm dừng (GIỮ ghim công ty): bật lại máy / mở lại app thì Agent tự bật.
    // KHÔNG `setStation(false)` — đó là người dùng tắt Agent (bỏ ghim).
    await service.suspend();
  }

  /// Đăng xuất: tạm dừng Agent (giữ ghim công ty — đăng nhập lại cửa hàng
  /// này thì tự bật lại), bỏ công ty đã lưu.
  Future<void> logout() async {
    _stopAutoAdd();
    await auth.clear();
    await service.suspend();
    AgentConfig.clearSession();
    _config = _config.withoutCompany();
    notifyListeners();
  }

  /// Đổi cấu hình (lưu lại); đổi máy in thì kiểm tra lại + báo máy khác.
  Future<void> update(AgentConfig next) async {
    final printerChanged =
        next.printer != _config.printer || next.paper != _config.paper;
    _config = next..save();
    notifyListeners();
    if (printerChanged) {
      await gateway.printerChanged();
      unawaited(_learnPrinterMac());
      // Máy in mới chọn (chưa nhận ra): đọc model + loại (hoá đơn / tem). Máy in chỉ
      // đổi IP (đã có tên) thì giữ nguyên, không ghi đè lựa chọn của người dùng.
      if (next.hasPrinter && next.printerName.isEmpty) {
        unawaited(identifyPrinter());
      }
    }
  }

  /// Xoá máy in của Agent (để chọn lại / thêm lại): máy bán hàng không còn thấy "máy
  /// in của trạm in" này cho tới khi chọn máy in mới.
  Future<void> removePrinter() => update(_config.withoutPrinter());

  /// Thêm máy in [address] vào trạm in: chưa có máy in chính thì làm máy in chính, có rồi
  /// thì thêm vào danh sách máy in (hiện trên sơ đồ). Trả `false` khi máy in đã có.
  Future<bool> addPrinter(String address) async {
    final a = address.trim();
    if (a.isEmpty ||
        a == _config.printer.trim() ||
        gateway.extras.contains(a)) {
      return false;
    }
    if (!_config.hasPrinter) {
      await update(_config.copyWith(printer: a, printerName: ''));
      return true;
    }
    // Người dùng chủ động thêm lại: bỏ khỏi danh sách đã xoá.
    gateway.extras.undismiss(a);
    if (!gateway.extras.add(a)) return false;
    notifyListeners();
    gateway.extrasChanged();
    unawaited(_learnExtraMac(a));
    unawaited(_identifyExtra(a));
    return true;
  }

  /// Cài đặt riêng của máy in ở [address] (máy in chính hoặc máy thêm).
  PrinterSettings settingsOf(String address) {
    final a = address.trim();
    final extra = gateway.extras.byAddress(a);
    if (extra != null && a != _config.printer.trim()) return extra.settings;
    return PrinterSettings(
      type: _config.printerType,
      paper: _config.paper,
      offsetXMm: _config.labelOffsetXMm,
      offsetYMm: _config.labelOffsetYMm,
      gapMm: _config.labelGapMm,
      beep: _config.beep,
    );
  }

  /// Máy in [address] đang kết nối (lần kiểm tra gần nhất của trạm in). Đọc từ danh sách
  /// trạng thái của watchdog (GetX `RxList`) nên dùng trong `Obx` thì giao diện tự đổi khi
  /// máy in mất / có lại kết nối.
  bool isPrinterConnected(String address) {
    final a = address.trim();
    for (final st in service.watchdog.statuses) {
      if ((st.printer.refAddress ?? '').trim() == a) {
        return st.state == AgentPrinterState.connected;
      }
    }
    return false;
  }

  /// Lưu cài đặt riêng của máy in [address] (trừ loại máy in — chốt từ lúc thêm).
  Future<void> updateSettings(String address, PrinterSettings value) async {
    final a = address.trim();
    // Loại máy in (hoá đơn / tem) chốt từ lúc thêm — không đổi qua cài đặt.
    final next = value.copyWith(type: settingsOf(a).type);
    if (a == _config.printer.trim()) {
      await update(
        _config.copyWith(
          printerType: next.type,
          paper: next.paper,
          labelOffsetXMm: next.offsetXMm,
          labelOffsetYMm: next.offsetYMm,
          labelGapMm: next.gapMm,
          beep: next.beep,
        ),
      );
    } else if (gateway.extras.updateSettings(a, next)) {
      notifyListeners();
      gateway.extrasChanged();
    }
  }

  /// Cài đặt (nếu cần) rồi thêm máy USB [address] (địa chỉ giả `setup:...` trên sơ đồ)
  /// vào trạm in. `null` = xong, ngược lại là lý do lỗi để hiện cho người dùng.
  Future<String?> setupUsbPrinter(String address) async {
    final info = gateway.pendingByAddress(address);
    if (info == null) return 'Không thấy máy in USB này — hãy cắm lại cáp USB';
    var queue = info.address;
    if (info.needsSetup) {
      final created = await UsbPrinters.setup(info.setupPort!);
      if (created == null) {
        return UsbPrinters.lastSetupError ??
            'Chưa cài được máy in USB này — máy tính cần quyền quản trị';
      }
      queue = created;
    }
    await addPrinter(queue);
    await gateway.refreshUsb();
    return null;
  }

  Timer? _usbTimer;

  /// Dò máy USB đang cắm định kỳ để hiện trên sơ đồ (chỉ khi đang làm Agent).
  void _startUsbWatch() {
    _usbTimer?.cancel();
    unawaited(gateway.refreshUsb());
    _usbTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (isOn) unawaited(gateway.refreshUsb());
    });
  }

  /// Thêm nhiều máy in một lúc; trả số máy thật sự được thêm (bỏ máy đã có).
  Future<int> addPrinters(Iterable<String> addresses) async {
    var added = 0;
    for (final a in addresses) {
      if (await addPrinter(a)) added++;
    }
    return added;
  }

  /// Bỏ máy in thêm [address]; `false` khi không phải máy in thêm.
  bool removeExtraPrinter(String address) {
    if (!gateway.extras.remove(address)) return false;
    // Người dùng chủ động xoá: lần quét mạng sau không tự thêm lại máy này.
    gateway.extras.dismiss(address);
    notifyListeners();
    gateway.extrasChanged();
    unawaited(service.relay.refreshStationInfo());
    return true;
  }

  /// Máy in LAN vừa tìm thấy khi quét mạng: thêm vào trạm này (hiện trên sơ đồ, nhận lệnh
  /// in) — trừ máy in chính, máy đã có và máy người dùng đã xoá. Trả số máy mới thêm.
  int registerScanned(List<FoundPrinter> found) {
    var added = 0;
    for (final f in found) {
      final a = f.address.trim();
      if (a == _config.printer.trim() ||
          gateway.extras.contains(a) ||
          gateway.extras.isDismissed(a)) {
        continue;
      }
      if (!gateway.extras.add(a, name: f.model ?? '', mac: f.mac ?? '')) break;
      added++;
      unawaited(_identifyExtra(a));
    }
    if (added > 0) {
      notifyListeners();
      gateway.extrasChanged();
      unawaited(service.relay.refreshStationInfo());
    }
    return added;
  }

  /// Máy in LAN vừa thêm chưa biết MAC: đọc từ bảng ARP (sau khi mở được cổng in) — để
  /// biết đúng máy in này (không nhầm máy khác nhận IP cũ) và tìm lại khi đổi IP.
  Future<void> _learnExtraMac(String address) async {
    if (UsbPrinters.isLocal(address)) return;
    final parsed = parsePrinterAddress(address);
    if (parsed == null ||
        !await LanPrinterScanner.probe(parsed.$1, port: parsed.$2)) {
      return;
    }
    final mac = await ArpTable.macOf(parsed.$1);
    if (mac == null || !gateway.extras.contains(address)) return;
    gateway.extras.update(address, mac: mac);
    gateway.extrasChanged();
  }

  Future<void> _identifyExtra(String address) async {
    final found = await _recognize(address, PrinterType.receipt);
    if (!gateway.extras.contains(address)) return; // đã xoá trong lúc dò
    gateway.extras.update(
      address,
      name: found.name,
      type: found.type,
      paper: PaperSizeDetector.guess(found.name).size,
    );
    PrintAgentModule.host.log('[AGENT] Nhận ra máy in $address: ${found.note}');
    notifyListeners();
    gateway.extrasChanged();
  }

  /// Nhận ra máy in của Agent: model (SNMP) và loại. Máy in LAN trả lời lệnh TSPL là
  /// máy in TEM (máy in hoá đơn không trả lời — lệnh in hoá đơn gửi tới máy in tem
  /// không ra gì). Máy trả lời cả hai kiểu cũng chọn Tem (máy hoá đơn không hiểu TSPL);
  /// không trả lời nào thì dựa vào tên model, vẫn không rõ thì giữ loại hiện tại.
  Future<void> identifyPrinter() async {
    final address = _config.printer.trim();
    if (address.isEmpty) return;
    final found = await _recognize(address, _config.printerType);
    final name = found.name;
    final type = found.type;
    final note = found.note;
    PrintAgentModule.host.log('[AGENT] Nhận ra máy in $address: $note');
    if (_config.printer.trim() != address) return; // đã đổi máy in khác
    // Chưa đọc được model: để trống (sơ đồ chỉ ghi loại), KHÔNG lưu địa chỉ làm tên.
    // Đoán được khổ giấy từ tên máy thì đặt luôn (không đoán được: giữ khổ đang chọn).
    final paper = PaperSizeDetector.guess(name);
    _config = _config.copyWith(
      printerName: name,
      printerType: type,
      paper: paper.detected && type == PrinterType.receipt ? paper.size : null,
    )..save();
    notifyListeners();
    unawaited(service.relay.refreshStationInfo());
  }

  /// Nhận ra máy in [address]: model (SNMP) và loại (hoá đơn / tem). Không rõ loại thì
  /// giữ [current].
  Future<({String name, PrinterType type, String note})> _recognize(
    String address,
    PrinterType current,
  ) async {
    var name = '';
    var type = current;
    var note = '';
    if (UsbPrinters.isLocal(address)) {
      name = UsbPrinters.label(address);
      note = 'Máy in USB: chọn loại máy in bằng tay nếu chưa đúng.';
    } else {
      final parsed = parsePrinterAddress(address);
      if (parsed != null) {
        name =
            await const DesktopPrinterDiscovery()
                .modelOf(address)
                .timeout(const Duration(seconds: 5), onTimeout: () => null) ??
            '';
        PrinterLanguage? language;
        try {
          language = await PrinterLanguageProbe.probeLan(
            parsed.$1,
            port: parsed.$2,
          );
        } catch (_) {}
        final guess = PrinterTypeDetector.decide(
          language: language,
          model: name,
        );
        type = guess.type ?? type;
        note = guess.type == null
            ? 'Máy không trả lời lệnh nào: giữ "${type.short}", hãy chọn tay nếu '
                  'chưa đúng.'
            : guess.note;
      }
    }
    return (name: name, type: type, note: note);
  }

  /// In thử ra máy in [address]; `null` = in được, ngược lại là lý do lỗi. Máy tem in một
  /// tem thử (lệnh hoá đơn gửi tới máy tem không ra gì), máy hoá đơn in phiếu thử.
  Future<String?> printTestTo(String address) async {
    final a = address.trim();
    final s = settingsOf(a);
    final failure = s.type == PrinterType.label
        ? await AgentPrinter.printLabelCalibration(
            address: a,
            spec: LabelPreset.defaultPreset.spec,
            calibration: s.calibration,
            gapOverrideMm: s.gapMm,
            labelsPerRow: LabelPreset.defaultPreset.count,
            temWidthMm: LabelPreset.defaultPreset.temWidthMm,
          )
        : await AgentPrinter.printTest(
            address: a,
            label: AgentIdentity.label(service.displayName, service.stationId),
            paperMm: s.paper.pageMm,
          );
    if (a == _config.printer.trim()) unawaited(gateway.reconnectBuiltIn());
    return failure == null
        ? null
        : AgentJobErrorText.message(failure.error, detail: failure.detail);
  }

  void _stopAutoAdd() {
    autoAdd.stop();
    unawaited(_autoAddNet?.cancel());
    _autoAddNet = null;
  }

  @override
  void dispose() {
    _usbTimer?.cancel();
    _wake.stop();
    _stopAutoAdd();
    super.dispose();
  }
}
