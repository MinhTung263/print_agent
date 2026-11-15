import 'package:print_agent/print_agent.dart';

class MemoryStorage implements AgentStorage {
  final Map<String, Object?> data = {};

  @override
  Object? get(String key) => data[key];

  @override
  Future<void> put(String key, Object? value) async =>
      value == null ? data.remove(key) : data[key] = value;
}

class FakePrinter implements AgentPrinterRef {
  const FakePrinter({
    this.refId,
    this.refKind,
    this.refAddress,
    this.refName = '',
    this.refMac,
  });

  @override
  final Object? refId;
  @override
  final AgentPrinterKind? refKind;
  @override
  final String? refAddress;
  @override
  final String refName;
  @override
  final String? refMac;
}

class FakeHost implements AgentHost {
  FakeHost({this.companyKey = '1'});

  @override
  final MemoryStorage storage = MemoryStorage();
  @override
  String companyKey;
  @override
  String get appPackage => 'vn.test.app';
  @override
  List<AgentPrinterRef> printers = [];
  @override
  String? shopKey = 'dev/c1_1';
  @override
  String? appDeviceName;
  @override
  AgentDeviceInfo? device = const AgentDeviceInfo(
    manufacturer: 'SUNMI',
    model: 'SUNMI T1-G',
  );
  final List<String> notices = [];
  @override
  void notify(
    String message, {
    AgentNoticeLevel level = AgentNoticeLevel.info,
    Duration? duration,
    String? actionLabel,
    void Function()? onAction,
  }) => notices.add(message);
  @override
  void log(String message) {}
}
