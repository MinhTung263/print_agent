import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:print_agent/print_agent.dart';

import 'support/fake_host.dart';

void main() {
  late FakeHost host;

  setUp(() {
    PrintAgentModule.init(host = FakeHost(companyKey: 'A'));
    AgentPeersVisibility.show.value = false;
  });

  test('mặc định ẨN trạm in khác cùng công ty', () {
    AgentPeersVisibility.ensureLoaded();
    expect(AgentPeersVisibility.show.value, isFalse);
  });

  test(
    'bật được, lưu riêng theo công ty, đổi công ty thì đọc lại lựa chọn của công ty đó',
    () async {
      AgentPeersVisibility.ensureLoaded();
      await AgentPeersVisibility.set(true);
      expect(AgentPeersVisibility.show.value, isTrue);
      expect(host.storage.get('agent_show_peers_A'), isTrue);

      // Công ty B chưa từng bật: mặc định ẩn.
      host.companyKey = 'B';
      AgentPeersVisibility.ensureLoaded();
      expect(AgentPeersVisibility.show.value, isFalse);

      // Quay lại công ty A: vẫn nhớ đã bật.
      host.companyKey = 'A';
      AgentPeersVisibility.ensureLoaded();
      expect(AgentPeersVisibility.show.value, isTrue);

      await AgentPeersVisibility.set(false);
      expect(host.storage.get('agent_show_peers_A'), isFalse);
    },
  );

  testWidgets(
    'đọc lựa chọn lúc đang dựng giao diện: không lỗi "setState() during build", cập nhật sau khung hình',
    (t) async {
      host.companyKey = 'C-build';
      await host.storage.put('agent_show_peers_C-build', true);
      final seen = <bool>[];
      await t.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              // Obx theo dõi giá trị (như nút con mắt ở đầu sơ đồ).
              Obx(() {
                seen.add(AgentPeersVisibility.show.value);
                return const SizedBox();
              }),
              // Nơi khác gọi ensureLoaded NGAY TRONG build (như bản đồ máy in).
              Obx(() {
                AgentPeersVisibility.ensureLoaded();
                return const SizedBox();
              }),
            ],
          ),
        ),
      );
      expect(t.takeException(), isNull);
      await t.pump();
      expect(t.takeException(), isNull);
      expect(AgentPeersVisibility.show.value, isTrue);
      expect(seen.last, isTrue);
    },
  );
}
