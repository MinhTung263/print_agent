import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

void main() {
  const lan = {'192.168.1'};

  bool primary(String id, int rank, List<Map<String, Object?>> stations) =>
      AgentPrimary.isPrimary(
        selfId: id,
        selfRank: rank,
        selfNets: lan,
        stations: stations,
      );

  Map<String, Object?> station(
    String id,
    int? rank, [
    String net = '192.168.1',
  ]) => {
    'id': id,
    'rank': ?rank,
    'net': [net],
  };

  test('một mình trong mạng: là trạm chính', () {
    expect(primary('b', AgentPrimary.rankAndroid, const []), isTrue);
  });

  test('máy tính cùng mạng ưu tiên hơn Android: Android làm dự phòng', () {
    final stations = [
      station('pc', AgentPrimary.rankDesktop),
      station('pos', AgentPrimary.rankAndroid),
    ];
    expect(primary('pos', AgentPrimary.rankAndroid, stations), isFalse);
    expect(primary('pc', AgentPrimary.rankDesktop, stations), isTrue);
  });

  test(
    'bằng ưu tiên: mã trạm nhỏ hơn làm trạm chính (mọi máy cùng kết quả)',
    () {
      final stations = [
        station('a1', AgentPrimary.rankAndroid),
        station('b2', AgentPrimary.rankAndroid),
      ];
      expect(primary('a1', AgentPrimary.rankAndroid, stations), isTrue);
      expect(primary('b2', AgentPrimary.rankAndroid, stations), isFalse);
    },
  );

  test('trạm khác mạng / bản cũ (không báo rank) không tính', () {
    final stations = [
      station('pc', AgentPrimary.rankDesktop, '10.0.0'),
      station('old', null),
    ];
    expect(primary('pos', AgentPrimary.rankAndroid, stations), isTrue);
  });

  test('dải mạng lấy từ IPv4', () {
    expect(AgentPrimary.netsOf(['192.168.1.20', '10.0.0.5', 'fe80::1']), {
      '192.168.1',
      '10.0.0',
    });
  });
}
