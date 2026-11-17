import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/desktop_agent.dart';
import 'package:print_agent_desktop/agent/desktop_web_print.dart';

void main() {
  test(
    'GET /v1/info có stationId: trang web nhận ra "Agent này chính là trạm đang chọn"',
    () {
      final agent = DesktopAgent(const AgentConfig(printer: '10.0.0.5'));
      final info = DesktopWebPrint(agent).info();
      final id = info['stationId'];
      expect(id, isA<String>());
      expect(id as String, isNotEmpty);
      // Cùng mã Agent báo trên hàng đợi (`id` trong thông tin trạm).
      expect(id, agent.service.stationId);
      agent.dispose();
    },
  );
}
