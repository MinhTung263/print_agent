import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/desktop_agent_host.dart';
import 'package:print_agent_desktop/agent/desktop_job_printer.dart';
import 'package:print_agent_desktop/agent/desktop_printer_gateway.dart';
import 'package:printer_label/desktop.dart';

/// Lệnh như trạm nhận từ hàng đợi (cùng định dạng app gửi).
PrintRelayJob job(Map<String, Object?> map) =>
    PrintRelayJob.fromMap('j1', {'printerIp': 'builtin', ...map})!;

void main() {
  var config = const AgentConfig(printer: '192.168.1.50');
  final gateway = DesktopPrinterGateway(() => config);
  final printer = DesktopJobPrinter(() => config, gateway);

  test('lệnh tới máy in tích hợp của Agent → máy in đã chọn', () {
    final p = printer.resolve(job({'printerType': 'builtin'}));
    expect(p.kind, AgentPrinterKind.builtIn);
    expect(p.address, '192.168.1.50');
  });

  test('lệnh in hộ máy LAN → in thẳng tới IP của lệnh', () {
    final p = printer.resolve(
      job({'printerType': 'lan', 'printerIp': ' 10.0.0.9 ', 'printerId': 3}),
    );
    expect(p.kind, AgentPrinterKind.lan);
    expect(p.address, '10.0.0.9');
    expect(p.id, 3);
  });

  test('lệnh tem: Agent máy tính báo chưa in được', () async {
    final failure = await printer.printJob(
      gateway.builtInPrinter(),
      job({'kind': 'label', 'printerType': 'builtin'}),
    );
    expect(failure?.detail, 'Agent máy tính chưa in được tem');
  });

  test('máy in tích hợp báo cho máy khác theo khổ giấy đã chọn', () {
    config = const AgentConfig(printer: '10.0.0.5', paper: PaperSize.size58);
    expect(gateway.hasBuiltIn, isTrue);
    expect(printer.builtInSpec()?.paper, 'size58');
    config = const AgentConfig();
    expect(gateway.hasBuiltIn, isFalse);
  });

  group('DesktopAgentHost', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('agent_host_');
      AgentStore.debugDirectory = dir;
    });
    tearDown(() {
      AgentStore.debugDirectory = null;
      dir.deleteSync(recursive: true);
    });

    test('khoá hàng đợi giống app EasyPOS', () {
      var c = const AgentConfig(env: 'Dev-Test', companyId: 7, ownerId: 9);
      final host = DesktopAgentHost(() => c);
      expect(host.shopKey, 'dev_test/c7_9');
      c = const AgentConfig();
      expect(host.shopKey, isNull);
    });

    test('lưu giá trị JSON của module vào file cấu hình', () async {
      final host = DesktopAgentHost(() => const AgentConfig());
      await host.storage.put('known_agents_1', [
        {'id': 'a1'},
      ]);
      expect(host.storage.get('known_agents_1'), [
        {'id': 'a1'},
      ]);
      expect(AgentStore.get('m.known_agents_1'), '[{"id":"a1"}]');
    });
  });

  test('tách địa chỉ máy in', () {
    expect(parsePrinterAddress('192.168.1.5'), ('192.168.1.5', 9100));
    expect(parsePrinterAddress('192.168.1.5:9101'), ('192.168.1.5', 9101));
    expect(parsePrinterAddress('  '), isNull);
  });

  test('bỏ dấu tiếng Việt cho phiếu in thử', () {
    expect(EscPosCommands.asciiFold('Quầy Thu Ngân Đà'), 'Quay Thu Ngan Da');
  });
}
