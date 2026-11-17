import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';

import '../desktop/keep_awake.dart';
import '../printers/data/desktop_printer_discovery.dart';
import '../printers/printer_type_detector.dart';
import 'label_preset.dart';

import '../printers/label_dpi_guess.dart';
import '../printers/paper_size_detector.dart';
import 'agent_config.dart';
import 'agent_printer.dart';
import 'printer_settings.dart';
import 'printer_settings_memory.dart';
import 'agent_store.dart';
import 'desktop_agent_host.dart';
import 'desktop_job_printer.dart';
import 'desktop_printer.dart';
import 'desktop_printer_gateway.dart';
import 'desktop_web_print.dart';
import 'desktop_printer_auto_add.dart';
import '../auth/auth_session.dart';
import '../store/printer_auto_add.dart';
import '../ui/dashboard/desktop_header.dart';
import 'desktop_wifi.dart';
import '../printers/printer_beep_plan.dart';

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
    autoAdd.start();
    _autoAddNet ??= gateway.networkChanges.listen((_) {
      autoAdd.networkChanged();
      // Mạng đổi (Wi-Fi tắt / bật lại): báo lại trạng thái trạm sau khi có IP mới.
      Future<void>.delayed(const Duration(seconds: 3), () {
        if (isOn) unawaited(service.relay.refreshStationInfo());
      });
    });
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
    // Máy từng thêm trước đây: cài đặt (tắt cắt giấy, còi, khổ giấy...) quay về.
    final mac = await _macForRemember(a);
    final saved = PrinterSettingsMemory.recall(
      a,
      const PrinterSettings(),
      mac: mac,
    );
    if (!_config.hasPrinter) {
      await update(
        _config.copyWith(
          printer: a,
          printerName: '',
          paper: saved?.paper,
          labelOffsetXMm: saved?.offsetXMm,
          labelOffsetYMm: saved?.offsetYMm,
          labelGapMm: saved?.gapMm,
          beep: saved?.beep,
          autoCut: saved?.autoCut,
          labelDpi: saved?.dpi,
          labelRibbon: saved?.ribbon,
        ),
      );
      return true;
    }
    if (!gateway.extras.add(a, paper: saved?.paper ?? PaperSize.size80)) {
      return false;
    }
    // Loại máy (hoá đơn / tem) giữ nguyên như vừa thêm — chỉ khôi phục phần còn lại.
    if (saved != null) {
      gateway.extras.updateSettings(
        a,
        saved.copyWith(type: gateway.extras.byAddress(a)?.type),
      );
    }
    notifyListeners();
    gateway.extrasChanged();
    unawaited(_learnExtraMac(a));
    unawaited(_identifyExtra(a));
    return true;
  }

  /// MAC máy in LAN [address] đọc nhanh từ bảng ARP (để nhớ / tìm lại cài đặt theo máy,
  /// không theo IP); rỗng khi không phải LAN hoặc chưa biết.
  Future<String> _macForRemember(String address) async {
    if (UsbPrinters.isLocal(address)) return '';
    final parsed = parsePrinterAddress(address);
    if (parsed == null) return '';
    try {
      return await ArpTable.macOf(parsed.$1) ?? '';
    } catch (_) {
      return '';
    }
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
      autoCut: _config.autoCut,
      dpi: _config.labelDpi,
      ribbon: _config.labelRibbon,
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
    final knownMac = a == _config.printer.trim()
        ? _config.printerMac
        : (gateway.extras.byAddress(a)?.mac ?? '');
    PrinterSettingsMemory.remember(a, next, mac: knownMac);
    if (a == _config.printer.trim()) {
      await update(
        _config.copyWith(
          printerType: next.type,
          paper: next.paper,
          labelOffsetXMm: next.offsetXMm,
          labelOffsetYMm: next.offsetYMm,
          labelGapMm: next.gapMm,
          beep: next.beep,
          autoCut: next.autoCut,
          labelDpi: next.dpi,
          labelRibbon: next.ribbon,
        ),
      );
    } else if (gateway.extras.updateSettings(a, next)) {
      notifyListeners();
      gateway.extrasChanged();
    }
    // Độ phân giải đầu in đổi: báo lại cho máy gửi (dựng ảnh tem đúng độ mịn).
    if (service.relay.isStation.value) {
      unawaited(service.relay.refreshStationInfo());
    }
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
    notifyListeners();
    gateway.extrasChanged();
    unawaited(service.relay.refreshStationInfo());
    return true;
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

  /// Máy tem vừa được nhận ra: tên model ghi "300" (máy 300dpi) và khách CHƯA từng chỉnh
  /// độ phân giải của máy này (không có cài đặt đã nhớ, đang 203) thì đặt sẵn 300dpi. Trả
  /// `null` khi không đổi.
  int? _dpiGuessFor(
    String address,
    String model,
    PrinterType type,
    int currentDpi, [
    String mac = '',
  ]) {
    if (type != PrinterType.label || currentDpi != 203) return null;
    if (PrinterSettingsMemory.recall(
          address,
          const PrinterSettings(),
          mac: mac,
        ) !=
        null) {
      return null; // khách đã chỉnh máy này trước đây: tôn trọng
    }
    final guess = LabelDpiGuess.fromModel(model);
    if (guess != null) {
      PrintAgentModule.host.log(
        '[AGENT] $address: tên model "$model" ghi 300 — đặt sẵn 300dpi',
      );
    }
    return guess;
  }

  Future<void> _identifyExtra(String address) async {
    final found = await _recognize(address, PrinterType.receipt);
    if (!gateway.extras.contains(address)) return; // đã xoá trong lúc dò
    final extra = gateway.extras.byAddress(address);
    gateway.extras.update(
      address,
      name: found.name,
      type: found.type,
      paper: PaperSizeDetector.guess(found.name).size,
      dpi: _dpiGuessFor(
        address,
        found.name,
        found.type,
        extra?.dpi ?? 203,
        extra?.mac ?? '',
      ),
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
      labelDpi: _dpiGuessFor(
        address,
        name,
        type,
        _config.labelDpi,
        _config.printerMac,
      ),
    )..save();
    notifyListeners();
    unawaited(service.relay.refreshStationInfo());
  }

  /// Nhận ra máy in [address]: model (SNMP) và loại (hoá đơn / tem). Không rõ loại thì
  /// giữ [current].
  /// Cho máy in [address] kêu bíp ngắn để nhận ra đó là máy nào; `null` = đã gửi, ngược lại là lý
  /// do lỗi.
  ///
  /// [attempt]: lần thử (0 = cách đúng với loại máy đã biết; bấm lại khi không nghe thấy thì thử cách khác —
  /// xem [PrinterBeepPlan]).
  Future<String?> beepPrinter(String address, {int attempt = 0}) async {
    final type = settingsOf(address).type;
    final failure = await AgentPrinter.beep(
      address.trim(),
      label: type == PrinterType.label,
      style: PrinterBeepPlan.styleFor(type, attempt),
    );
    return failure == null
        ? null
        : AgentJobErrorText.message(failure.error, detail: failure.detail);
  }

  /// Hàng in Windows (`queue:...`) mới có hàng đợi spooler để xả.
  bool canPurgeQueue(String address) =>
      Platform.isWindows &&
      address.trim().startsWith(WindowsRawPrinters.prefix);

  /// Xả mọi lệnh đang kẹt trong hàng đợi Windows của máy in [address] (máy từng tắt /
  /// hết giấy làm lệnh cũ kẹt) — `null` = đã xả, ngược lại là lý do lỗi.
  Future<String?> purgeQueue(String address) async {
    if (!canPurgeQueue(address)) {
      return 'Máy in này không có hàng đợi để làm sạch';
    }
    final name = address.trim().substring(WindowsRawPrinters.prefix.length);
    final ok = await WindowsRawPrinters.purgeQueue(name);
    return ok
        ? null
        : 'Không làm sạch được hàng đợi (cần quyền quản trị với máy in này)';
  }

  Future<({String name, PrinterType type, String note})> _recognize(
    String address,
    PrinterType current,
  ) async {
    var name = '';
    var type = current;
    var note = '';
    if (UsbPrinters.isLocal(address)) {
      // Máy USB tự báo hãng / model / lệnh hiểu (IEEE 1284): nhận ra máy tem hay hoá đơn.
      final id = await UsbPrinters.deviceId(address);
      final idName = id == null ? '' : Ieee1284.name(id);
      name = idName.isNotEmpty ? idName : UsbPrinters.label(address);
      final language = id == null
          ? null
          : PrinterLanguageProbe.fromIeee1284(id);
      final guess = PrinterTypeDetector.decide(language: language, model: name);
      type = guess.type ?? type;
      note = guess.type == null
          ? 'Máy in USB: chưa nhận ra loại máy, giữ "${type.short}".'
          : guess.note;
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
            dpi: s.dpi,
            ribbon: s.ribbon.value,
          )
        : await AgentPrinter.printTest(
            address: a,
            label: AgentIdentity.label(service.displayName, service.stationId),
            paperMm: s.paper.pageMm,
            autoCut: s.autoCut,
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

  bool _disposed = false;

  /// Việc chạy nền (nhận dạng máy in, dò mạng...) có thể xong SAU khi Agent đã đóng: bỏ qua
  /// thông báo thay vì ném lỗi "dùng sau khi đóng".
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _wake.stop();
    _stopAutoAdd();
    super.dispose();
  }
}
