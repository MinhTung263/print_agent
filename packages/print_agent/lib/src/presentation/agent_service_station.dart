import 'package:get/get.dart';
import 'package:print_agent_core/print_agent_core.dart';

import '../data/agent_printer_reconnect.dart';
import '../data/agent_printer_remote.dart';
import '../data/agent_printer_watchdog.dart';
import '../data/agent_service.dart';
import '../domain/entities/agent_printer_ref.dart';
import '../domain/entities/agent_test_print_result.dart';
import 'ports/agent_station.dart';

/// [AgentStation] dựng từ [AgentService] — app chủ chỉ cần thêm [AgentWifi]
/// và luồng đổi mạng.
class AgentServiceStation implements AgentStation {
  AgentServiceStation(
    this._service, {
    required this.wifi,
    required Stream<void> networkChanges,
  }) : networkChanges = networkChanges.isBroadcast
           ? networkChanges
           : networkChanges.asBroadcastStream();

  final AgentService<AgentPrinterRef> _service;

  @override
  final AgentWifi wifi;

  /// Luồng đổi mạng, nghe được NHIỀU lần (màn Trạm in mở lại sau đăng xuất /
  /// vào lại công ty nghe lại — luồng một-người-nghe sẽ lỗi).
  @override
  final Stream<void> networkChanges;

  @override
  PrintRelay get relay => _service.relay;

  @override
  String get stationId => _service.stationId;

  @override
  RxString get name => _service.name;

  @override
  String get displayName => _service.displayName;

  @override
  Future<void> setName(String name) => _service.setName(name);

  @override
  bool get boundElsewhere => _service.boundElsewhere;

  @override
  Future<bool> setEnabled(
    bool on, {
    void Function(String otherApp)? onOtherApp,
  }) => _service.setEnabled(on, onOtherApp: onOtherApp);

  @override
  Future<bool> removeAgent(Map<Object?, Object?> station) =>
      _service.removeAgent(station);

  @override
  Future<bool> deleteAgent(Map<Object?, Object?> station) =>
      _service.deleteAgent(station);

  @override
  RxBool get isPrimary => _service.isPrimary;

  @override
  RxInt get printed => _service.jobs.printed;

  @override
  RxInt get failed => _service.jobs.failed;

  @override
  Rxn<DateTime> get lastJobAt => _service.jobs.lastJobAt;

  @override
  AgentPrinterWatchdog<AgentPrinterRef> get watchdog => _service.watchdog;

  @override
  AgentPrinterReconnect<AgentPrinterRef> get reconnect => _service.reconnect;

  @override
  AgentPrinterRemote<AgentPrinterRef> get remote => _service.remote;

  @override
  Future<AgentTestPrintResult> testPrint(AgentPrinterRef printer) =>
      _service.testPrint.local(printer);

  @override
  Future<AgentTestPrintResult> testPrintPeer(
    Map<Object?, Object?> station,
    Map<Object?, Object?> printer,
  ) => _service.testPrint.peer(station, printer);

  @override
  Future<void> refreshPeerBuiltIns() => _service.refreshPeerBuiltIns();
}
