import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/agent_printers_map.dart';

import 'support/fake_host.dart';
import 'support/fake_station.dart';

AgentPrinterStatus<AgentPrinterRef> _status(FakePrinter p) =>
    AgentPrinterStatus<AgentPrinterRef>(
      printer: p,
      state: AgentPrinterState.connected,
    );

void main() {
  setUp(() {
    PrintAgentModule.init(FakeHost());
    PrintAgentUi.init(const MaterialAgentUiKit(), station: FakeStation());
  });

  // Máy in của Agent máy tính: loại "tích hợp" nhưng địa chỉ là IP máy in LAN đã chọn.
  const desktopPrinter = FakePrinter(
    refKind: AgentPrinterKind.builtIn,
    refAddress: '192.168.1.100',
    refName: 'Máy in tem · XP-420B',
    refMac: '00:5C:17:DA:C8:88',
  );
  // Máy in tích hợp của máy POS: địa chỉ giả, không phải IP.
  const posBuiltIn = FakePrinter(
    refKind: AgentPrinterKind.builtIn,
    refAddress: 'BUILT_IN',
    refName: 'Máy in tích hợp',
  );

  test('sơ đồ chỉ hiện TÊN máy in của Agent máy tính (không dòng IP)', () {
    expect(AgentPrintersMap.addressLineOf(_status(desktopPrinter)), isNull);
  });

  test('máy in tích hợp của máy POS vẫn có dòng "Có sẵn trên máy"', () {
    expect(AgentPrintersMap.addressLineOf(_status(posBuiltIn)), isNotNull);
  });

  test('máy in LAN thường: dòng phụ "LAN" như cũ', () {
    const lan = FakePrinter(
      refKind: AgentPrinterKind.lan,
      refAddress: '192.168.1.50',
      refName: 'Bếp',
    );
    expect(AgentPrintersMap.addressLineOf(_status(lan))?.text, 'LAN');
  });

  test('chi tiết máy in của Agent máy tính: kết nối LAN + IP + MAC', () {
    final d = AgentPrintersMap.detailOf(_status(desktopPrinter), const {});
    expect(d.kind, 'lan');
    expect(d.address, '192.168.1.100');
    expect(d.mac, '00:5C:17:DA:C8:88');
    expect(d.name, 'Máy in tem · XP-420B');
  });

  group('máy in chính là máy USB của Agent máy tính', () {
    const usb = FakePrinter(
      refId: -1,
      refKind: AgentPrinterKind.builtIn,
      refAddress: 'cups:EasyPOS_Gprinter',
      refName: 'Máy in hoá đơn · Gprinter',
    );
    tearDown(() {
      PrintAgentUi.printerSettings = null;
      PrintAgentUi.onRemovePrinter = null;
    });

    test('chi tiết có phần cài đặt + xoá, kết nối USB, không hiện mã -1', () {
      PrintAgentUi.printerSettings = (_) => const SizedBox();
      PrintAgentUi.onRemovePrinter = (_) async => true;
      final d = AgentPrintersMap.detailOf(_status(usb), const {});
      expect(d.kind, 'usb');
      expect(d.settings, isNotNull);
      expect(d.onRemove, isNotNull);
      expect(d.id, isNull);
    });

    test('máy in tích hợp của máy POS: không có phần cài đặt', () {
      PrintAgentUi.printerSettings = (_) => const SizedBox();
      expect(
        AgentPrintersMap.detailOf(_status(posBuiltIn), const {}).settings,
        isNull,
      );
    });

    test('sơ đồ ghi "USB" dưới tên máy', () {
      expect(AgentPrintersMap.addressLineOf(_status(usb))?.text, 'USB');
    });
  });

  test('app chủ tự lo in thử → chi tiết không có nút "In thử" chung', () {
    addTearDown(() => PrintAgentUi.hasOwnTestPrint = null);
    expect(
      AgentPrintersMap.detailOf(_status(desktopPrinter), const {}).onTestPrint,
      isNotNull,
    );
    PrintAgentUi.hasOwnTestPrint = (_) => true;
    expect(
      AgentPrintersMap.detailOf(_status(desktopPrinter), const {}).onTestPrint,
      isNull,
    );
  });

  group('xoá nhanh máy in trong chi tiết', () {
    tearDown(() => PrintAgentUi.onRemovePrinter = null);

    test('chưa có hook xoá của app chủ → không có nút xoá', () {
      PrintAgentUi.onRemovePrinter = null;
      expect(
        AgentPrintersMap.detailOf(_status(desktopPrinter), const {}).onRemove,
        isNull,
      );
    });

    test(
      'có hook: máy in đã chọn của Agent máy tính (IP thật) xoá được',
      () async {
        final removed = <String?>[];
        PrintAgentUi.onRemovePrinter = (p) async {
          removed.add(p.refAddress);
          return true;
        };
        final d = AgentPrintersMap.detailOf(_status(desktopPrinter), const {});
        expect(d.onRemove, isNotNull);
        expect(await d.onRemove!(), isTrue);
        expect(removed, ['192.168.1.100']);
      },
    );

    test(
      'máy in LAN / USB đã lưu xoá được; máy in tích hợp của máy POS thì không',
      () {
        PrintAgentUi.onRemovePrinter = (_) async => true;
        const lan = FakePrinter(
          refId: 3,
          refKind: AgentPrinterKind.lan,
          refAddress: '192.168.1.50',
          refName: 'Bếp',
        );
        expect(
          AgentPrintersMap.detailOf(_status(lan), const {}).onRemove,
          isNotNull,
        );
        expect(
          AgentPrintersMap.detailOf(_status(posBuiltIn), const {}).onRemove,
          isNull,
        );
      },
    );
  });

  test('chi tiết máy in tích hợp của máy POS vẫn là "tích hợp"', () {
    final d = AgentPrintersMap.detailOf(_status(posBuiltIn), const {});
    expect(d.kind, 'builtin');
  });
}
