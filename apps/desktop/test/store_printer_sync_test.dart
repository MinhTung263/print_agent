import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/agent/agent_store.dart';
import 'package:print_agent_desktop/agent/paper_size.dart';
import 'package:print_agent_desktop/agent/printer_type.dart';
import 'package:print_agent_desktop/agent/store_printer_sync.dart';
import 'package:print_agent_desktop/store/store_printer.dart';

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('sync_');
    AgentStore.debugDirectory = dir;
  });
  tearDown(() {
    AgentStore.debugDirectory = null;
    dir.deleteSync(recursive: true);
  });

  test(
    'máy thêm từ cửa hàng được đánh dấu "Từ EasyPOS", theo từng công ty',
    () {
      StorePrinterSync.markAdded(7, '192.168.1.100');
      expect(StorePrinterSync.isFromStore(7, '192.168.1.100'), isTrue);
      expect(StorePrinterSync.isFromStore(8, '192.168.1.100'), isFalse);
      expect(StorePrinterSync.isFromStore(7, '192.168.1.101'), isFalse);
    },
  );

  test(
    'xoá khỏi Agent: bỏ nhãn và nhớ để không tự thêm lại; thêm tay lại thì gỡ nhớ',
    () {
      StorePrinterSync.markAdded(7, '192.168.1.100');
      StorePrinterSync.ignore(7, '192.168.1.100');
      expect(StorePrinterSync.isFromStore(7, '192.168.1.100'), isFalse);
      expect(StorePrinterSync.ignored(7), contains('192.168.1.100'));
      StorePrinterSync.unignore(7, '192.168.1.100');
      expect(StorePrinterSync.ignored(7), isEmpty);
    },
  );

  test('chỉ đồng bộ máy LAN có IP; loại máy và khổ giấy theo cửa hàng', () {
    StorePrinter p(Map<String, Object?> m) => StorePrinter.fromJson({
      'id': 1,
      'printName': 'M',
      'ipAddress': '192.168.1.5',
      'type': 1,
      'pageSize': 'K80',
      ...m,
    })!;
    expect(StorePrinterSync.isSyncable(p({})), isTrue);
    expect(
      StorePrinterSync.isSyncable(p({'type': 0})),
      isFalse,
      reason: 'Bluetooth',
    );
    expect(StorePrinterSync.isSyncable(p({'ipAddress': ''})), isFalse);
    expect(
      StorePrinterSync.typeOf(
        p({
          'typeTemplates': [5],
        }),
      ),
      PrinterType.label,
    );
    expect(
      StorePrinterSync.typeOf(
        p({
          'typeTemplates': [0, 1],
        }),
      ),
      PrinterType.receipt,
    );
    expect(StorePrinterSync.paperOf(p({'pageSize': 'K58'})), PaperSize.size58);
    expect(StorePrinterSync.paperOf(p({})), PaperSize.size80);
  });
}
