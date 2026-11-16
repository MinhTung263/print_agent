import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/data/machine_id.dart';

void main() {
  test('đọc mã máy từ kết quả lệnh của từng hệ điều hành', () {
    expect(
      MachineId.parseWindows(
        '\r\nHKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Cryptography\r\n'
        '    MachineGuid    REG_SZ    8B1C2D3E-4F50-6172-8394-A5B6C7D8E9F0\r\n',
      ),
      '8b1c2d3e-4f50-6172-8394-a5b6c7d8e9f0',
    );
    expect(
      MachineId.parseMac(
        '  | "IOPlatformUUID" = "7F3A9C10-2B44-5E6D-8A91-0C1D2E3F4A5B"\n',
      ),
      '7f3a9c10-2b44-5e6d-8a91-0c1d2e3f4a5b',
    );
    expect(
      MachineId.parseLinux('0123456789abcdef0123456789abcdef\n'),
      isNotNull,
    );
  });

  test('mã rỗng / toàn số 0 / quá ngắn: không dùng làm mã máy', () {
    expect(MachineId.parseWindows('không có gì'), isNull);
    expect(
      MachineId.parseMac(
        '"IOPlatformUUID" = "00000000-0000-0000-0000-000000000000"',
      ),
      isNull,
    );
    expect(MachineId.parseLinux(''), isNull);
    expect(MachineId.parseLinux('abc'), isNull);
  });

  test(
    'mã trạm cố định theo máy (cài lại vẫn y nguyên), khác theo người dùng hệ điều hành',
    () {
      final a = AgentDeviceIdentity.stationIdFor(
        'guid-1234-abcd',
        user: 'quan',
      );
      expect(
        a,
        AgentDeviceIdentity.stationIdFor('guid-1234-abcd', user: 'quan'),
      );
      expect(a.length, 16);
      expect(RegExp(r'^[0-9a-f]{16}$').hasMatch(a), isTrue);
      expect(
        a,
        isNot(
          AgentDeviceIdentity.stationIdFor('guid-1234-abcd', user: 'thungan'),
        ),
      );
      expect(
        a,
        isNot(AgentDeviceIdentity.stationIdFor('guid-9999-abcd', user: 'quan')),
      );
      // Android (không có user) giữ công thức cũ.
      expect(
        AgentDeviceIdentity.stationIdFor('abc'),
        AgentDeviceIdentity.stationIdFor('abc', user: ''),
      );
    },
  );

  test('máy này đọc được mã máy thật', () async {
    if (!(Platform.isMacOS || Platform.isLinux || Platform.isWindows)) return;
    final id = await MachineId.read();
    expect(id, isNotNull);
    expect(id!.length, greaterThanOrEqualTo(8));
  });
}
