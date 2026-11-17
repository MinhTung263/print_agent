import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/printer_type.dart';
import 'package:print_agent_desktop/printers/printer_discovery.dart';
import 'package:print_agent_desktop/printers/printer_option.dart';
import 'package:print_agent_desktop/printers/printer_picker_list.dart';
import 'package:print_agent_desktop/ui/dashboard/printer_picker_dialog.dart';

class _FakeDiscovery implements PrinterDiscovery {
  _FakeDiscovery(this.found, {this.models = const {}, this.types = const {}});

  final List<PrinterOption> found;
  final Map<String, String> models;
  final Map<String, PrinterType> types;

  final List<String> beeped = [];

  @override
  Future<String?> beep(String address, {PrinterType? type}) async {
    beeped.add('$address|${type?.name}');
    return null;
  }

  @override
  String? get setupError => null;
  final setups = <String>[];
  final reachableCalls = <String>[];

  @override
  Future<List<PrinterOption>> find() async => found;

  @override
  PrinterOption missing(String address) => PrinterOption.lan(address);

  @override
  Future<String?> modelOf(String address) async => models[address];

  @override
  Future<PrinterType?> typeOf(String address, {String? model}) async =>
      types[address];

  @override
  Future<bool> reachable(String address) async {
    reachableCalls.add(address);
    return true;
  }

  @override
  Future<List<String>> scannedNetworks() async => const ['192.168.1.x'];

  @override
  Future<String?> localIp() async => '192.168.1.20';

  @override
  Future<String?> setupUsb(String setupPort) async {
    setups.add(setupPort);
    return 'queue:EasyPOS_USB';
  }
}

/// Dò hiện dần: test tự đẩy từng đợt kết quả vào [stream].
class _ProgressiveDiscovery extends _FakeDiscovery
    implements ProgressivePrinterDiscovery {
  _ProgressiveDiscovery({super.models, super.types}) : super(const []);

  final stream = StreamController<List<PrinterOption>>();

  @override
  Stream<List<PrinterOption>> findStream() => stream.stream;
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

    testWidgets('chọn nhiều máy: tick từng máy, máy đang dùng không chọn lại', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(1000, 900));
      final d = _FakeDiscovery([
        PrinterOption.lan('192.168.1.10'),
        PrinterOption.lan('192.168.1.11'),
        PrinterOption.usb(address: '', name: 'XP-58', setupPort: 'USB001'),
      ]);
      List<String>? result;
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showPrintersPickerDialog(
                context,
                current: '192.168.1.10',
                discovery: d,
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      // Máy đang dùng bấm không có tác dụng; chưa tick máy nào thì nút bị khoá.
      await t.tap(find.text('Máy in mạng (LAN)').first);
      await t.pumpAndSettle();
      expect(find.text('Thêm 0 máy in'), findsOneWidget);
      await t.tap(find.text('192.168.1.11'));
      await t.tap(find.text('XP-58'));
      await t.pumpAndSettle();
      expect(find.text('Thêm 2 máy in'), findsOneWidget);
      await t.tap(find.text('Thêm 2 máy in'));
      await t.pumpAndSettle();
      expect(result, ['192.168.1.11', 'queue:EasyPOS_USB']);
      expect(d.setups, ['USB001']);
    });

    testWidgets('nút bíp trên thẻ máy: gửi lệnh bíp đúng loại máy, báo kết quả', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(1000, 900));
      final d = _FakeDiscovery([
        PrinterOption.lan('192.168.1.10', type: PrinterType.label),
        PrinterOption.usb(address: 'cups:Q1', name: 'Gprinter'),
        PrinterOption.lan(
          '192.168.1.99',
          warning: 'IP bị trùng',
          hardBlock: true,
        ),
      ]);
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showPrintersPickerDialog(context, discovery: d),
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
      // Máy bị chặn (IP trùng) không có nút bíp: còn 2 nút cho 2 máy dùng được.
      expect(find.byIcon(Icons.volume_up_rounded), findsNWidgets(2));
      await t.tap(find.byIcon(Icons.volume_up_rounded).first);
      await t.pumpAndSettle();
      expect(d.beeped, ['192.168.1.10|label']);
      expect(find.textContaining('Đã gửi lệnh bíp'), findsOneWidget);
    });

    testWidgets(
      'máy đã thêm vào trạm: hiện "Đã thêm" + dấu V, không chọn lại được',
      (t) async {
        await t.binding.setSurfaceSize(const Size(1000, 900));
        final d = _FakeDiscovery([
          PrinterOption.usb(address: 'cups:Main', name: 'Máy chính'),
          PrinterOption.usb(address: 'cups:Added', name: 'Gprinter'),
          PrinterOption.usb(address: 'cups:Free', name: 'Máy mới'),
        ]);
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showPrintersPickerDialog(
                    context,
                    current: 'cups:Main',
                    added: {'cups:Added'},
                    discovery: d,
                  ),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('mở'));
        await t.pumpAndSettle();
        expect(find.text('Đang dùng'), findsOneWidget);
        expect(find.text('Đã thêm'), findsOneWidget);
        // Hai máy đã có → dấu V xanh; máy mới (chưa có duy nhất) được tick sẵn.
        expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
        expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
        // Bấm máy đã thêm: không tick, nút vẫn "Thêm 1 máy in" (chỉ còn máy mới được tự tick vì là máy duy nhất chưa có).
        await t.tap(find.text('Gprinter'));
        await t.pumpAndSettle();
        expect(find.text('Thêm 1 máy in'), findsOneWidget);
      },
    );

    testWidgets(
      'máy chưa kết nối được (cảnh báo mềm): vẫn bíp thử và thêm được; IP trùng thì chặn cứng',
      (t) async {
        await t.binding.setSurfaceSize(const Size(1000, 900));
        final d = _FakeDiscovery([
          PrinterOption.lan(
            '192.168.1.100',
            warning: 'Chưa kết nối được — vẫn thêm được',
          ),
          PrinterOption.lan(
            '192.168.1.99',
            warning: 'IP trùng',
            hardBlock: true,
          ),
        ]);
        List<String>? result;
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async => result =
                      await showPrintersPickerDialog(context, discovery: d),
                  child: const Text('mở'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('mở'));
        await t.pumpAndSettle();
        // Hiện cả địa chỉ lẫn cảnh báo.
        expect(find.text('192.168.1.100'), findsOneWidget);
        expect(find.textContaining('Chưa kết nối được'), findsOneWidget);
        // Chỉ máy cảnh báo mềm có nút bíp.
        expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
        await t.tap(find.byIcon(Icons.volume_up_rounded));
        await t.pumpAndSettle();
        expect(d.beeped, ['192.168.1.100|null']);
        // Máy cảnh báo mềm là máy duy nhất chọn được nên được tick sẵn; bấm máy IP trùng không thêm gì.
        await t.tap(find.text('192.168.1.99'));
        await t.pumpAndSettle();
        expect(find.text('Thêm 1 máy in'), findsOneWidget);
        await t.tap(find.text('Thêm 1 máy in'));
        await t.pumpAndSettle();
        expect(result, ['192.168.1.100']);
      },
    );

    Future<void> openOnly(
      WidgetTester t,
      PrinterDiscovery d,
      void Function(String?) done,
    ) async {
      await t.binding.setSurfaceSize(const Size(1000, 900));
      await t.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  done(await showPrinterPickerDialog(context, discovery: d)),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();
    }

    testWidgets(
      'không thấy máy in: hiện dải mạng đã quét + gợi ý máy bận / cổng khác',
      (t) async {
        await openOnly(t, _FakeDiscovery(const []), (_) {});
        expect(find.text('Chưa thấy máy in nào'), findsOneWidget);
        expect(find.textContaining('Đã quét mạng 192.168.1.x'), findsOneWidget);
        expect(find.textContaining('MỘT kết nối'), findsOneWidget);
        expect(find.textContaining('kèm cổng'), findsOneWidget);
      },
    );

    testWidgets(
      'nhập IP thủ công kèm cổng 9101: kiểm tra và dùng đúng ip:cổng',
      (t) async {
        String? result;
        final d = _FakeDiscovery(const []);
        await openOnly(t, d, (r) => result = r);
        await t.ensureVisible(find.textContaining('Nhập IP thủ công'));
        await t.pumpAndSettle();
        await t.tap(find.textContaining('Nhập IP thủ công'));
        await t.pumpAndSettle();
        // Ô IP: 3 ô đầu điền sẵn theo mạng máy này (192.168.1), gõ ô cuối.
        final boxes = find.byType(TextField);
        await t.enterText(boxes.at(3), '100');
        // Ô cuối cùng là ô cổng.
        await t.enterText(boxes.last, '9101');
        await t.pump();
        await t.ensureVisible(find.text('Kiểm tra kết nối'));
        await t.pumpAndSettle();
        await t.tap(find.text('Kiểm tra kết nối'));
        await t.pumpAndSettle();
        expect(d.reachableCalls, ['192.168.1.100:9101']);
        await t.tap(find.text('Dùng máy in này'));
        await t.pumpAndSettle();
        expect(result, '192.168.1.100:9101');
      },
    );

    testWidgets('cổng để trống / mặc định 9100: địa chỉ không kèm cổng', (
      t,
    ) async {
      String? result;
      final d = _FakeDiscovery(const []);
      await openOnly(t, d, (r) => result = r);
      await t.ensureVisible(find.textContaining('Nhập IP thủ công'));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Nhập IP thủ công'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(3), '100');
      await t.pump();
      await t.ensureVisible(find.text('Kiểm tra kết nối'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kiểm tra kết nối'));
      await t.pumpAndSettle();
      expect(d.reachableCalls, ['192.168.1.100']);
      await t.tap(find.text('Dùng máy in này'));
      await t.pumpAndSettle();
      expect(result, '192.168.1.100');
    });

    testWidgets('mỗi máy in mạng hiện nhãn loại: máy in tem / máy in hoá đơn', (
      t,
    ) async {
      final d = _FakeDiscovery(
        [PrinterOption.lan('192.168.1.10'), PrinterOption.lan('192.168.1.11')],
        models: {
          '192.168.1.10': 'Xprinter XP-420B',
          '192.168.1.11': 'Xprinter XP-80C',
        },
        types: {
          '192.168.1.10': PrinterType.label,
          '192.168.1.11': PrinterType.receipt,
        },
      );
      await openOnly(t, d, (_) {});
      expect(find.text('Máy in tem'), findsOneWidget);
      expect(find.text('Máy in hoá đơn'), findsOneWidget);
      expect(find.text('Xprinter XP-420B'), findsOneWidget);
    });

    testWidgets('máy chưa nhận ra loại: không hiện nhãn (không đoán bừa)', (
      t,
    ) async {
      final d = _FakeDiscovery([PrinterOption.lan('192.168.1.10')]);
      await openOnly(t, d, (_) {});
      expect(find.text('Máy in tem'), findsNothing);
      expect(find.text('Máy in hoá đơn'), findsNothing);
    });

    testWidgets('máy nhập tay cũng được nhận ra loại', (t) async {
      final d = _FakeDiscovery(
        const [],
        types: {'192.168.1.100': PrinterType.label},
      );
      await openOnly(t, d, (_) {});
      await t.ensureVisible(find.textContaining('Nhập IP thủ công'));
      await t.pumpAndSettle();
      await t.tap(find.textContaining('Nhập IP thủ công'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).at(3), '100');
      await t.pump();
      await t.ensureVisible(find.text('Kiểm tra kết nối'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kiểm tra kết nối'));
      await t.pumpAndSettle();
      expect(find.text('Máy in tem'), findsOneWidget);
    });

    testWidgets(
      'dò hiện dần: máy USB hiện trước, máy mạng hiện tới đâu thấy tới đó; kết quả cuối không làm mất nhãn đã đọc',
      (t) async {
        final d = _ProgressiveDiscovery(
          models: {'192.168.1.10': 'Xprinter XP-420B'},
          types: {'192.168.1.10': PrinterType.label},
        );
        await t.binding.setSurfaceSize(const Size(1000, 900));
        await t.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => showPrinterPickerDialog(context, discovery: d),
                child: const Text('mở'),
              ),
            ),
          ),
        );
        await t.tap(find.text('mở'));
        await t.pump(const Duration(milliseconds: 100));
        // Chưa có máy nào: đang quét.
        expect(find.text('XP-58'), findsNothing);

        // Máy USB về trước — hiện NGAY dù quét mạng chưa xong (vẫn đang quét).
        final usb = PrinterOption.usb(address: 'cups:XP_58', name: 'XP-58');
        d.stream.add([usb]);
        await t.pump(const Duration(milliseconds: 100));
        expect(find.text('XP-58'), findsOneWidget);

        // Máy mạng đầu tiên thấy: hiện thêm, tên model + loại đọc xong.
        d.stream.add([usb, PrinterOption.lan('192.168.1.10')]);
        await t.pump(const Duration(milliseconds: 300));
        expect(find.text('Máy in tem'), findsOneWidget);
        expect(find.text('Xprinter XP-420B'), findsOneWidget);

        // Kết quả cuối thay danh sách: nhãn đã đọc vẫn còn, không đọc lại từ đầu.
        d.stream.add([usb, PrinterOption.lan('192.168.1.10')]);
        await d.stream.close();
        await t.pumpAndSettle();
        expect(find.text('Máy in tem'), findsOneWidget);
        expect(find.text('Xprinter XP-420B'), findsOneWidget);
        expect(find.text('XP-58'), findsOneWidget);
      },
    );
  });
}
