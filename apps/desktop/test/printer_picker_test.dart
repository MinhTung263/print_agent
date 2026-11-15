import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/printers/printer_discovery.dart';
import 'package:print_agent_desktop/printers/printer_option.dart';
import 'package:print_agent_desktop/printers/printer_picker_list.dart';
import 'package:print_agent_desktop/ui/dashboard/printer_picker_dialog.dart';

class _FakeDiscovery implements PrinterDiscovery {
  _FakeDiscovery(this.found, {this.models = const {}});

  final List<PrinterOption> found;
  final Map<String, String> models;
  final setups = <String>[];

  @override
  Future<List<PrinterOption>> find() async => found;

  @override
  PrinterOption missing(String address) => PrinterOption.lan(address);

  @override
  Future<String?> modelOf(String address) async => models[address];

  @override
  Future<bool> reachable(String ip) async => true;

  @override
  Future<String?> localIp() async => '192.168.1.20';

  @override
  Future<String?> setupUsb(String setupPort) async {
    setups.add(setupPort);
    return 'queue:EasyPOS_USB';
  }
}

void main() {
  group('PrinterPickerList', () {
    final lan1 = PrinterOption.lan('192.168.1.10');
    final lan2 = PrinterOption.lan('192.168.1.11');

    test('máy đang dùng lên đầu; không dò thấy vẫn hiện', () {
      final all = PrinterPickerList.merge(
        found: [lan1, lan2],
        current: '192.168.1.11',
        missing: PrinterOption.lan,
      );
      expect(all.map((o) => o.address), ['192.168.1.11', '192.168.1.10']);
      final gone = PrinterPickerList.merge(
        found: [lan1],
        current: '10.0.0.9',
        missing: PrinterOption.lan,
      );
      expect(gone.first.address, '10.0.0.9');
    });

    test('máy nhập tay không lặp với máy dò thấy', () {
      final all = PrinterPickerList.merge(
        found: [lan1],
        manual: [
          PrinterOption.lan('192.168.1.10', manual: true),
          PrinterOption.lan('192.168.1.50', manual: true),
        ],
      );
      expect(all.map((o) => o.address), ['192.168.1.50', '192.168.1.10']);
    });

    test('chọn sẵn khi chỉ có 1 máy; cập nhật tên model', () {
      expect(PrinterPickerList.preselect([lan1], null), lan1.key);
      expect(PrinterPickerList.preselect([lan1, lan2], null), isNull);
      final named = PrinterPickerList.withModel([lan1], lan1.address, 'XP-80C');
      expect(named.single.title, 'XP-80C');
    });
  });

  group('Hộp chọn máy in', () {
    Future<String?> open(WidgetTester t, PrinterDiscovery d) async {
      await t.binding.setSurfaceSize(const Size(1000, 900));
      String? result;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await showPrinterPickerDialog(context, discovery: d),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      await t.tap(find.text('Dùng máy in này'));
      await t.pumpAndSettle();
      return result;
    }

    testWidgets('một máy in: chọn sẵn, hiện tên model, dùng ngay', (t) async {
      final d = _FakeDiscovery(
        [PrinterOption.lan('192.168.1.10')],
        models: {'192.168.1.10': 'Xprinter XP-80C'},
      );
      expect(await open(t, d), '192.168.1.10');
    });

    testWidgets('máy USB chưa cài: cài khi bấm dùng', (t) async {
      final d = _FakeDiscovery([
        PrinterOption.usb(address: '', name: 'XP-58', setupPort: 'USB001'),
      ]);
      expect(await open(t, d), 'queue:EasyPOS_USB');
      expect(d.setups, ['USB001']);
    });
  });
}
