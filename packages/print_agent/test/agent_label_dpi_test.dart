import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/data/agent_sender.dart';
// ignore: implementation_imports
import 'package:print_agent/src/data/agent_station_info.dart';

import 'support/fake_host.dart';

void main() {
  setUp(() => PrintAgentModule.init(FakeHost()));

  final stations = <Map<Object?, Object?>>[
    {
      'id': 'A',
      'builtIn': {
        'dpi': {'builtin': 300, '10.0.0.7': 300},
      },
    },
    {
      'id': 'B',
      'builtIn': {'paper': 'size80'}, // không báo dpi: 203
    },
    {'id': 'C'}, // trạm không có máy in tích hợp
  ];
  const mm300 = 300 / 25.4;

  test('máy in tích hợp của trạm: tra theo mã trạm', () {
    final a = PrintRelayPrinter.stationBuiltIn(stationId: 'A');
    final b = PrintRelayPrinter.stationBuiltIn(stationId: 'B');
    expect(AgentSender.dotsPerMmOf(stations, a), mm300);
    expect(AgentSender.dotsPerMmOf(stations, b), 8);
  });

  test('máy in thêm theo địa chỉ; địa chỉ lạ → 203dpi', () {
    expect(
      AgentSender.dotsPerMmOf(
        stations,
        const PrintRelayPrinter(address: '10.0.0.7'),
      ),
      mm300,
    );
    expect(
      AgentSender.dotsPerMmOf(
        stations,
        const PrintRelayPrinter(address: ' 10.0.0.7 '),
      ),
      mm300,
      reason: 'bỏ khoảng trắng thừa',
    );
    expect(
      AgentSender.dotsPerMmOf(
        stations,
        const PrintRelayPrinter(address: '10.0.0.9'),
      ),
      8,
    );
  });

  test('không có trạm nào / bản Agent cũ không báo dpi: 8 chấm/mm như cũ', () {
    const p = PrintRelayPrinter(address: '10.0.0.7');
    expect(AgentSender.dotsPerMmOf(const [], p), 8);
    expect(AgentSender.dotsPerMmOf([stations[1], stations[2]], p), 8);
  });

  test(
    'thông tin trạm báo dpi của máy tem 300dpi; máy 203dpi không ghi gì',
    () {
      Map<String, Object?> info(AgentBuiltInSpec spec) =>
          AgentStationInfo.build(
            name: 'Quầy',
            model: null,
            builtIn: spec,
            builtInConnected: true,
            statuses: const [],
          );
      final withDpi = info(
        const AgentBuiltInSpec(labelDpis: {'builtin': 300, '10.0.0.7': 300}),
      );
      expect((withDpi['builtIn']! as Map)['dpi'], {
        'builtin': 300,
        '10.0.0.7': 300,
      });
      expect(
        (info(const AgentBuiltInSpec())['builtIn']! as Map).containsKey('dpi'),
        isFalse,
      );
    },
  );
}
