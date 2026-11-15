import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:print_agent/print_agent.dart';
import 'package:printer_label/desktop.dart';

import '../desktop/keep_awake.dart';
import '../web/web_bridge_server.dart';
import '../web/web_origin_policy.dart';

import 'agent_config.dart';
import 'agent_printer.dart';
import 'agent_store.dart';
import 'desktop_agent_host.dart';
import 'desktop_job_printer.dart';
import 'desktop_printer.dart';
import 'desktop_printer_gateway.dart';
import 'desktop_web_print.dart';
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
      printer: DesktopJobPrinter(() => _config, gateway),
      // Đi qua được tường lửa chỉ mở cổng web.
      mqttConfig: const MqttRelayConfig.secureWebSocket(),
      canHandleOther: _canHandleLan,
    );
    PrintAgentUi.init(
      const MaterialAgentUiKit(),
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

  /// Lệnh in hộ máy in LAN: chỉ nhận khi bật "In hộ máy in LAN" và máy in kết
  /// nối được từ đây (Agent ở mạng khác không giành mất lệnh). USB của máy
  /// khác: không nhận.
  Future<bool> _canHandleLan(PrintRelayJob job) async {
    if (job.isLabel || job.printer.isUsb || !_config.acceptAll) return false;
    return AgentPrinter.reachable(job.printer.address);
  }

  /// Vào công ty (sau đăng nhập / mở app): khôi phục trạng thái Agent.
  Future<void> start() async {
    if (!_config.ready) return;
    await service.init();
    unawaited(gateway.reconnectBuiltIn());
    unawaited(_learnPrinterMac());
  }

  Future<void> setOn(bool on) => service.setEnabled(on);

  /// Thoát ứng dụng: rút khỏi danh sách Agent, thôi chặn máy ngủ.
  Future<void> shutdown() async {
    _wake.stop();
    await web.stop();
    await KeepAwake.set(false);
    // Tạm dừng (GIỮ ghim công ty): bật lại máy / mở lại app thì Agent tự bật.
    // KHÔNG `setStation(false)` — đó là người dùng tắt Agent (bỏ ghim).
    await service.suspend();
  }

  /// Đăng xuất: tạm dừng Agent (giữ ghim công ty — đăng nhập lại cửa hàng
  /// này thì tự bật lại), bỏ công ty đã lưu.
  Future<void> logout() async {
    await service.suspend();
    AgentConfig.clearSession();
    _config = _config.withoutCompany();
    notifyListeners();
  }

  /// Đổi cấu hình (lưu lại); đổi máy in thì kiểm tra lại + báo máy khác.
  Future<void> update(AgentConfig next) async {
    final printerChanged =
        next.printer != _config.printer || next.paper != _config.paper;
    final acceptAllChanged = next.acceptAll != _config.acceptAll;
    _config = next..save();
    notifyListeners();
    if (acceptAllChanged) gateway.lanPrintersChanged();
    if (printerChanged) {
      await gateway.printerChanged();
      unawaited(_learnPrinterMac());
    }
  }

  /// In thử ra máy in của Agent; `null` = in được, ngược lại là lý do lỗi.
  Future<String?> printTest() async {
    final failure = await AgentPrinter.printTest(
      address: _config.printer,
      label: AgentIdentity.label(service.displayName, service.stationId),
      paperMm: _config.paper.pageMm,
    );
    unawaited(gateway.reconnectBuiltIn());
    return failure == null ? null : (failure.detail ?? failure.error.name);
  }

  @override
  void dispose() {
    _wake.stop();
    super.dispose();
  }
}
