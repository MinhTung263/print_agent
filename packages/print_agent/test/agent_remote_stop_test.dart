import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';

void main() {
  const printers = {
    'printers': {'ok': 1, 'total': 1},
  };

  test('ngắt kết nối từ xa: trạm không có máy in luôn ngắt được', () {
    expect(AgentIdentity.canStopRemotely(const {'id': 'a'}), isTrue);
  });

  test('ngắt kết nối từ xa: trạm bản mới còn máy in vẫn ngắt được', () {
    expect(AgentIdentity.canStopRemotely({...printers, 'stop': true}), isTrue);
    expect(
      AgentIdentity.canStopRemotely(const {
        'builtIn': {'paper': 80},
        'stop': true,
      }),
      isTrue,
    );
  });

  test(
    'ngắt kết nối từ xa: trạm bản cũ còn máy in thì không (báo cập nhật)',
    () {
      expect(AgentIdentity.canStopRemotely(printers), isFalse);
    },
  );

  test('máy nhận: có force thì ngắt cả khi còn máy in', () {
    const cmd = {'cmd': 'stop', 'by': 'Quầy 1', 'force': true};
    expect(AgentService.shouldStop(cmd, hasNoPrinters: false), isTrue);
  });

  test('máy nhận: không force (máy gửi dùng thông tin cũ) thì giữ máy in', () {
    const cmd = {'cmd': 'stop', 'by': 'Quầy 1'};
    expect(AgentService.shouldStop(cmd, hasNoPrinters: false), isFalse);
    expect(AgentService.shouldStop(cmd, hasNoPrinters: true), isTrue);
  });
}
