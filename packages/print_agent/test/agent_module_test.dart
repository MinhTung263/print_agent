import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_host.dart';

void main() {
  late FakeHost host;
  setUp(() => PrintAgentModule.init(host = FakeHost()));

  test('init gắn app chủ vào module', () {
    expect(PrintAgentModule.host, same(host));
  });

  group('AgentIdentity', () {
    test('tên + mã ngắn, chưa đặt tên dùng tên mặc định của app chủ', () {
      expect(
        AgentIdentity.label('Quầy bar', 'abcdef12a3f9'),
        'Quầy bar · #A3F9',
      );
      expect(AgentIdentity.label(' ', 'abcdef12a3f9'), 'Trạm in · #A3F9');
      expect(AgentIdentity.label('Quầy', null), 'Quầy');
    });
  });

  group('AgentPrinterSwitches', () {
    const lan = FakePrinter(
      refId: 7,
      refKind: AgentPrinterKind.lan,
      refAddress: '10.0.0.9',
    );

    test('khoá máy in theo loại / mã / IP', () {
      expect(AgentPrinterSwitches.keyOf(lan), 'id:7');
      expect(
        AgentPrinterSwitches.keyOf(
          const FakePrinter(refKind: AgentPrinterKind.builtIn),
        ),
        'builtin',
      );
      expect(
        AgentPrinterSwitches.keyOf(
          const FakePrinter(
            refKind: AgentPrinterKind.lan,
            refAddress: ' 1.2.3.4 ',
          ),
        ),
        'ip:1.2.3.4',
      );
    });

    test('tắt máy in: lưu theo công ty, lệnh tới IP đó bị từ chối', () async {
      host.printers = [lan];
      AgentPrinterSwitches.ensureLoaded();
      await AgentPrinterSwitches.setOn(lan, false);
      expect(host.storage.data['agent_printer_off_1'], ['id:7']);
      // Lệnh không kèm mã máy in: tra máy in đã lưu theo IP.
      expect(
        AgentPrinterSwitches.accepts(
          const PrintRelayPrinter(address: '10.0.0.9'),
        ),
        isFalse,
      );
      await AgentPrinterSwitches.setOn(lan, true);
      expect(
        AgentPrinterSwitches.accepts(
          const PrintRelayPrinter(address: '10.0.0.9'),
        ),
        isTrue,
      );
    });
  });

  test('AgentPrintActivity khớp máy in theo mã / IP / tích hợp', () {
    const a = AgentPrintActivity(
      seq: 1,
      phase: AgentPrintPhase.printing,
      isLabel: false,
      builtIn: false,
      usb: false,
      ips: {'10.0.0.9'},
    );
    expect(
      a.matches(
        const FakePrinter(
          refKind: AgentPrinterKind.lan,
          refAddress: '10.0.0.9',
        ),
      ),
      isTrue,
    );
    expect(
      a.matches(const FakePrinter(refKind: AgentPrinterKind.builtIn)),
      isFalse,
    );
  });

  test('KnownAgents nhớ Agent theo công ty, quên được + hoàn tác', () {
    KnownAgents.sync([
      {'id': 'agent-1', 'name': 'Quầy 1'},
    ]);
    expect(KnownAgents.items.single.id, 'agent-1');
    expect(host.storage.data['known_agents_1'], isA<List<Object?>>());
    final removed = KnownAgents.forget('agent-1');
    expect(KnownAgents.items, isEmpty);
    KnownAgents.restore(removed!);
    expect(KnownAgents.items.single.id, 'agent-1');
  });
}
