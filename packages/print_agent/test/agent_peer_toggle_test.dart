import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/utils/agent_peer_printer_toggle.dart';

void main() {
  test('Agent bản cũ (máy in không có khoá): nhận ra, vẫn bấm được để báo', () {
    const station = {'id': 'agent-old', 'name': 'Máy Agent'};
    const old = {'name': 'PDIT', 'kind': 'lan', 'addr': '192.168.1.100'};
    const fresh = {'name': 'Hair', 'kind': 'lan', 'key': 'id:7'};
    expect(agentPeerIsOldVersion(old), isTrue);
    expect(agentPeerIsOldVersion(fresh), isFalse);
    expect(agentPeerPrinterToggle(station, old), isNotNull);
    expect(agentPeerPrinterToggle(station, fresh), isNotNull);
    expect(agentPeerPrinterToggle(const {'name': 'x'}, fresh), isNull);
  });
}
