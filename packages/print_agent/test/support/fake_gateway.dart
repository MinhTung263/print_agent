import 'dart:async';

import 'package:print_agent/print_agent.dart';

import 'fake_host.dart';

class FakeGateway implements AgentPrinterGateway<FakePrinter> {
  @override
  List<FakePrinter> printers = [];
  @override
  bool hasBuiltIn = false;
  @override
  bool builtInConnected = false;
  final builtIn = StreamController<bool>.broadcast();
  final network = StreamController<void>.broadcast();
  bool usbAttached = false;
  bool usbConnects = true;
  bool ready = true;
  FakePrinter? relocated;
  int builtInRestarts = 0;
  bool builtInComesBack = true;

  @override
  Stream<bool> get builtInChanges => builtIn.stream;
  @override
  Stream<void> get networkChanges => network.stream;
  @override
  Stream<void> get printersChanged => const Stream.empty();
  @override
  FakePrinter builtInPrinter() => const FakePrinter(
    refId: -1,
    refKind: AgentPrinterKind.builtIn,
    refName: 'Tích hợp',
  );
  @override
  Future<void> reconnectBuiltIn() async {
    builtInRestarts++;
    builtInConnected = builtInComesBack;
  }

  @override
  Future<bool> isUsbAttached(FakePrinter printer) async => usbAttached;
  @override
  Future<bool> connectUsb(FakePrinter printer) async => usbConnects;
  @override
  Future<bool> isReady(FakePrinter printer) async => ready;
  @override
  Future<FakePrinter?> relocate(
    FakePrinter printer, {
    Duration? timeout,
  }) async => relocated;
  @override
  String? wifiSsidOf(FakePrinter printer) => 'Wifi-Bep';
}
