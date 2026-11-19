import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
import 'package:print_agent_desktop/agent/agent_config.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/desktop_agent.dart';
import 'package:print_agent_desktop/agent/desktop_print_routing_store.dart';
import 'package:print_agent_desktop/store/print_function_codes.dart';
import 'package:print_agent_desktop/store/store_printer.dart';
import 'package:print_agent_desktop/store/store_printer_api.dart';

class _Api implements StorePrinterEditor {
  _Api(this.printers);

  List<StorePrinter> printers;
  final updates = <(int?, List<int>)>[];
  bool fail = false;

  @override
  Future<List<StorePrinter>> list() async => printers;

  @override
  Future<void> create(StorePrinter printer) async {}

  @override
  Future<void> updateTemplates(StorePrinter p, List<int> templates) async {
    if (fail) throw const StoreApiException('lỗi');
    updates.add((p.id, templates));
    printers = [
      for (final x in printers)
        if (x.id == p.id)
          StorePrinter.fromJson({...x.raw, 'typeTemplates': templates})!
        else
          x,
    ];
  }
}

StorePrinter _p(int id, String name, String ip, List<int> templates) =>
    StorePrinter.fromJson({
      'id': id,
      'printName': name,
      'ipAddress': ip,
      'type': 1,
      'pageSize': 'K80',
      'processingAreaIds': [9],
      'typeTemplates': templates,
      'comId': 7,
    })!;

StorePrinter _usb(int id, String name, String code) => StorePrinter.fromJson({
  'id': id,
  'printName': name,
  'ipAddress': code,
  'type': 2,
  'pageSize': 'K80',
  'typeTemplates': [1],
  'comId': 7,
})!;

void main() {
  late Directory dir;
  late DesktopAgent agent;
  late _Api api;
  late DesktopPrintRoutingStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('routing_');
    AgentStore.debugDirectory = dir;
    agent = DesktopAgent(AgentConfig(companyId: 7, ownerId: 1));
    api = _Api([
      _p(1, 'Máy in mới 1', '192.168.1.100', [0, 1]),
      _p(2, 'HPRT', '192.168.1.101', []),
    ]);
    store = DesktopPrintRoutingStore(agent, api: api);
  });
  tearDown(() {
    AgentStore.debugDirectory = null;
    dir.deleteSync(recursive: true);
  });

  test(
    'mã chức năng: API gán Tem = 5, QR = 6 (đảo so với thứ tự tài liệu)',
    () {
      expect(PrintFunctionCodes.apiCode(AgentPrintFunction.label), 5);
      expect(PrintFunctionCodes.apiCode(AgentPrintFunction.paymentQr), 6);
      expect(PrintFunctionCodes.fromApiCode(5), AgentPrintFunction.label);
      expect(PrintFunctionCodes.fromApiCode(6), AgentPrintFunction.paymentQr);
      for (final f in AgentPrintFunction.values) {
        expect(
          PrintFunctionCodes.fromApiCode(PrintFunctionCodes.apiCode(f)),
          f,
        );
      }
    },
  );

  test('load: chức năng của từng máy in lấy từ máy in cửa hàng', () async {
    final routes = await store.load();
    expect(
      {for (final r in routes) '${r.printerName}:${r.function.name}'},
      {'Máy in mới 1:provisional', 'Máy in mới 1:payment'},
    );
    expect(await store.printers(), ['Máy in mới 1', 'HPRT']);
  });

  test(
    'khớp máy in của máy này với máy in cửa hàng theo IP (kể cả ip:cổng)',
    () async {
      await store.refresh();
      expect(store.nameOfAddress('192.168.1.101'), 'HPRT');
      expect(store.nameOfAddress('192.168.1.100:9100'), 'Máy in mới 1');
      expect(store.nameOfAddress('10.0.0.9'), isNull);
      expect(store.nameOfAddress(''), isNull);
    },
  );

  test(
    'USB: khớp theo serial, hoặc theo hãng+dòng máy khi chỉ có một máy',
    () async {
      // 1155 = 0x0483, 22336 = 0x5740 (cửa hàng lưu số thập phân, Agent đọc số thập lục phân).
      api.printers = [
        _usb(10, 'USB A', 'USB:v1155_p22336_sAAA'),
        _usb(11, 'USB B', 'USB:v1155_p22336_sBBB'),
        _usb(12, 'Epson', 'USB:v1208_p514'),
      ];
      await store.refresh();
      expect(store.nameOfAddress('usb:0483:5740:BBB'), 'USB B');
      expect(store.nameOfAddress('usb:0483:5740:AAA'), 'USB A');
      // Hai máy cùng model, serial lạ: không đoán bừa.
      expect(store.nameOfAddress('usb:0483:5740:ZZZ'), isNull);
      // Chỉ một máy cùng model (Epson 04b8:0202), local không có serial: nhận.
      expect(store.nameOfAddress('usb:04b8:0202:'), 'Epson');
      // Windows: serial do hệ thống đặt theo cổng (có '&') bị bỏ qua.
      expect(
        store.nameOfAddress(
          r'usbp:\\?\usb#vid_04b8&pid_0202#5&2a1b&0&1#{guid}',
        ),
        'Epson',
      );
      expect(store.nameOfAddress('usb:1234:5678:'), isNull);
    },
  );

  test('máy đổi IP: vẫn khớp đúng máy của cửa hàng theo MAC', () async {
    api.printers = [
      StorePrinter.fromJson({
        'id': 5,
        'printName': 'Máy bếp',
        'ipAddress': '192.168.1.50',
        'macAddress': 'aa-bb-cc-dd-ee-ff',
        'type': 1,
        'typeTemplates': [2],
      })!,
    ];
    await store.refresh();
    // IP đã đổi nhưng cùng MAC (viết hoa / dấu khác nhau vẫn khớp).
    expect(
      store.nameOfAddress('192.168.1.77', mac: 'AA:BB:CC:DD:EE:FF'),
      'Máy bếp',
    );
    expect(store.nameOfAddress('192.168.1.77'), isNull);
  });

  test('save: chỉ máy đổi chức năng mới được cập nhật, đúng mã API', () async {
    final routes = await store.load();
    await store.save([
      ...routes,
      const AgentPrintRoute(
        function: AgentPrintFunction.label,
        printerName: 'HPRT',
        templateId: 6,
      ),
    ]);
    expect(
      api.updates.length,
      1,
      reason: 'máy 1 không đổi nên không gọi cập nhật',
    );
    expect(api.updates.single.$1, 2);
    expect(api.updates.single.$2, [5], reason: 'Tem nhãn = mã 5 của API');
  });

  test('sửa chức năng giữ nguyên khổ giấy / khu vực chế biến của máy', () {
    final p = _p(1, 'Máy in mới 1', '192.168.1.100', [0, 1]);
    final body = p.toUpdateJson([1, 2], 7);
    expect(body['pageSize'], 'K80');
    expect(body['processingAreaIds'], [9]);
    expect(body['typeTemplates'], [1, 2]);
    expect(p.toUpdateJson([], 7)['typeTemplates'], isNull);
  });

  test('save: máy chủ từ chối → ném lỗi', () async {
    api.fail = true;
    await store.refresh();
    expect(
      () => store.save(const [
        AgentPrintRoute(
          function: AgentPrintFunction.kitchen,
          printerName: 'HPRT',
          templateId: 2,
        ),
      ]),
      throwsA(isA<StoreApiException>()),
    );
  });

  test('xem trước / hỏi số bản lưu trên máy theo công ty', () async {
    expect(await store.previewBeforePayment(), isTrue);
    await store.setPreviewBeforePayment(false);
    expect(await store.previewBeforePayment(), isFalse);
    await store.setAskCopiesEachPrint(true);
    expect(await store.askCopiesEachPrint(), isTrue);
  });
}
