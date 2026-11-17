import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/desktop/firewall_guard.dart';

const _exe = r'C:\Program Files\EasyPOS Agent\easypos_print_agent.exe';

String _rule({
  String program = _exe,
  String enabled = 'Yes',
  String action = 'Allow',
  String direction = 'In',
}) =>
    'Rule Name:                            Tram in EasyPOS\r\n'
    '----------------------------------------------------------------------\r\n'
    'Enabled:                              $enabled\r\n'
    'Direction:                            $direction\r\n'
    'Profiles:                             Domain,Private,Public\r\n'
    'Protocol:                             TCP\r\n'
    'LocalPort:                            9101\r\n'
    'Program:                              $program\r\n'
    'Action:                               $action\r\n';

void main() {
  test('quy tắc bật, cho phép vào, đúng chương trình → đủ', () {
    expect(FirewallGuard.ruleCoversProgram(_rule(), _exe), isTrue);
    expect(
      FirewallGuard.ruleCoversProgram(_rule(), _exe.toUpperCase()),
      isTrue,
    );
  });

  test('sai chương trình / tắt / chặn / chiều ra → chưa đủ', () {
    expect(
      FirewallGuard.ruleCoversProgram(_rule(program: r'D:\other.exe'), _exe),
      isFalse,
    );
    expect(
      FirewallGuard.ruleCoversProgram(_rule(enabled: 'No'), _exe),
      isFalse,
    );
    expect(
      FirewallGuard.ruleCoversProgram(_rule(action: 'Block'), _exe),
      isFalse,
    );
    expect(
      FirewallGuard.ruleCoversProgram(_rule(direction: 'Out'), _exe),
      isFalse,
    );
    expect(FirewallGuard.ruleCoversProgram('', _exe), isFalse);
  });

  test(
    'Windows ngôn ngữ khác (nhãn không phải tiếng Anh): khớp đường dẫn là đủ',
    () {
      final vi =
          'Tên quy tắc: Tram in EasyPOS\r\n-----------------------\r\n'
          'Đã bật: Có\r\nChương trình: $_exe\r\n';
      expect(FirewallGuard.ruleCoversProgram(vi, _exe), isTrue);
      expect(FirewallGuard.ruleCoversProgram(vi, r'D:\x.exe'), isFalse);
    },
  );
}
