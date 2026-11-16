import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';

import 'fake_gateway.dart';
import 'fake_host.dart';

class FakeWifi implements AgentWifi {
  @override
  String? ssidOf(AgentPrinterRef printer) => null;
  @override
  Future<void> ensureNamePermission({bool force = false}) async {}
  @override
  Future<String?> passwordFor(String ssid) async => null;
  @override
  Future<bool> switchTo(String ssid, {String password = ''}) async => true;
  @override
  Future<bool> usesSystemPanel() async => false;
  @override
  Future<String?> currentSsid() async => null;
  @override
  Future<List<String>> nearby() async => const [];
  @override
  Future<void> openSettings() async {}
}

class FakeStation implements AgentStation {
  FakeStation() {
    final gateway = FakeGateway();
    final dog = AgentPrinterWatchdog<FakePrinter>(gateway);
    watchdog = dog;
    reconnect = AgentPrinterReconnect<FakePrinter>(gateway, dog);
    remote = AgentPrinterRemote<FakePrinter>(
      watchdog: dog,
      sendControl: (_, _) async => true,
      senderName: () => 'Quầy 1',
    );
  }

  final List<bool> enabledCalls = [];

  @override
  final PrintRelay relay = PrintRelay(
    queues: () async => const [],
    onJob: (_) async => true,
  );
  @override
  String get stationId => 'agent-1';
  @override
  final RxString name = RxString('');
  @override
  String get displayName => name.value.isEmpty ? 'Máy test' : name.value;
  @override
  Future<void> setName(String value) async => name.value = value;
  @override
  bool boundElsewhere = false;
  @override
  Future<bool> setEnabled(
    bool on, {
    void Function(String otherApp)? onOtherApp,
  }) async {
    enabledCalls.add(on);
    relay.isStation.value = on;
    return true;
  }

  @override
  Future<bool> removeAgent(Map<Object?, Object?> station) async => true;

  @override
  final RxBool isPrimary = true.obs;
  @override
  final RxInt printed = 0.obs;
  @override
  final RxInt failed = 0.obs;
  @override
  final Rxn<DateTime> lastJobAt = Rxn<DateTime>();
  @override
  Stream<void> get networkChanges => const Stream.empty();
  @override
  late final AgentPrinterWatchdog<AgentPrinterRef> watchdog;
  @override
  late final AgentPrinterReconnect<AgentPrinterRef> reconnect;
  @override
  late final AgentPrinterRemote<AgentPrinterRef> remote;
  @override
  final AgentWifi wifi = FakeWifi();

  final List<Object?> deleted = [];

  @override
  Future<bool> deleteAgent(Map<Object?, Object?> station) async {
    deleted.add(station['id']);
    return true;
  }

  /// Máy in đã được bấm "In thử" (tên) và kết quả giả.
  final List<String> testPrinted = [];
  AgentTestPrintResult testResult = AgentTestPrintResult.done;

  @override
  Future<AgentTestPrintResult> testPrint(AgentPrinterRef printer) async {
    testPrinted.add(printer.refName);
    return testResult;
  }

  @override
  Future<AgentTestPrintResult> testPrintPeer(
    Map<Object?, Object?> station,
    Map<Object?, Object?> printer,
  ) async {
    testPrinted.add('${printer['name']}');
    return testResult;
  }

  @override
  Future<void> refreshPeerBuiltIns() async {}
}
