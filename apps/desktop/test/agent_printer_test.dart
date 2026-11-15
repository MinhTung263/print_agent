import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_printer.dart';
import 'package:printer_label/desktop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const withPrinter = AgentConfig(printer: '192.168.1.50');
  const noPrinter = AgentConfig();

  test('máy in tích hợp của Agent → máy in đã chọn', () {
    final job = {'kind': 'receipt', 'printerType': 'builtin'};
    expect(AgentPrinter.targetOf(job, withPrinter), '192.168.1.50');
    expect(AgentPrinter.targetOf(job, noPrinter), isNull);
  });

  test('máy in LAN → in thẳng tới printerIp của lệnh', () {
    final job = {
      'kind': 'receipt',
      'printerType': 'lan',
      'printerIp': ' 10.0.0.9 ',
    };
    expect(AgentPrinter.targetOf(job, noPrinter), '10.0.0.9');
    expect(AgentPrinter.targetOf({...job, 'printerIp': ''}, noPrinter), isNull);
  });

  test('tem và USB: Agent máy tính chưa in', () {
    expect(
      AgentPrinter.targetOf({
        'kind': 'label',
        'printerType': 'builtin',
      }, withPrinter),
      isNull,
    );
    expect(
      AgentPrinter.targetOf({
        'kind': 'receipt',
        'printerType': 'usb',
      }, withPrinter),
      isNull,
    );
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
