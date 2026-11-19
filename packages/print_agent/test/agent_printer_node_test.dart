import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/agent_printers_map.dart';
// ignore: implementation_imports
import 'package:print_agent/src/presentation/widgets/sheets/agent_printer_detail_sheet.dart';

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

  test('iOS không in USB được: máy in USB có cảnh báo, máy LAN thì không', () {
    const usbSaved = FakePrinter(
      refId: 5,
      refKind: AgentPrinterKind.usb,
      refAddress: 'v1155_p22336',
      refName: 'XP-80C',
    );
    const lan = FakePrinter(
      refId: 6,
      refKind: AgentPrinterKind.lan,
      refAddress: '192.168.1.5',
      refName: 'LAN',
    );
    addTearDown(() => PrintAgentUi.usbSupported = true);
    expect(
      AgentPrintersMap.detailOf(_status(usbSaved), const {}).usbUnsupported,
      isFalse,
    );
    PrintAgentUi.usbSupported = false;
    expect(
      AgentPrintersMap.detailOf(_status(usbSaved), const {}).usbUnsupported,
      isTrue,
    );
    expect(
      AgentPrintersMap.detailOf(_status(lan), const {}).usbUnsupported,
      isFalse,
    );
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

  test(
    'tên nút: model ở dòng tên, loại máy ở dòng phụ (không bị cắt mất model)',
    () {
      final hd = AgentPrintersMap.splitName('Máy in hoá đơn · XP-80C');
      expect(hd.title, 'XP-80C');
      expect(hd.typeLine?.text, 'Hoá đơn');
      final tem = AgentPrintersMap.splitName('Máy in tem · XP-420B');
      expect(tem.title, 'XP-420B');
      expect(tem.typeLine?.text, 'Tem');
    },
  );

  test(
    'tên không có dấu " · " hoặc thiếu model: giữ nguyên, không dòng phụ',
    () {
      expect(AgentPrintersMap.splitName('Bếp').title, 'Bếp');
      expect(AgentPrintersMap.splitName('Bếp').typeLine, isNull);
      expect(
        AgentPrintersMap.splitName('Máy in tem · ').title,
        'Máy in tem · ',
      );
      expect(AgentPrintersMap.splitName('').title, '');
    },
  );

  test(
    'địa chỉ USB của Windows / Linux CUPS là máy USB (không phải "tích hợp")',
    () {
      for (final a in [
        r'usbp:\\?\usb#vid_0483&pid_5740#1#{g}',
        'lpq:Xprinter',
      ]) {
        final p = FakePrinter(
          refKind: AgentPrinterKind.builtIn,
          refAddress: a,
          refName: 'Máy in hoá đơn · XP',
        );
        expect(AgentPrintersMap.addressLineOf(_status(p))?.text, 'USB');
      }
    },
  );

  AgentPrinterStatus<AgentPrinterRef> statusOf(
    FakePrinter p,
    AgentPrinterState state,
  ) => AgentPrinterStatus<AgentPrinterRef>(printer: p, state: state);

  const lan = FakePrinter(
    refKind: AgentPrinterKind.lan,
    refAddress: '192.168.1.64',
    refName: 'Máy in hoá đơn · HPRT',
  );

  test(
    'chi tiết máy in lỗi: có "Kết nối lại"; máy ổn / đã tắt nhận lệnh thì không',
    () {
      final down = AgentPrintersMap.detailOf(
        statusOf(lan, AgentPrinterState.disconnected),
        const {},
      );
      expect(down.state, AgentPrinterDetailState.notReady);
      expect(down.onReconnect, isNotNull);
      expect(
        down.onSwitchNetwork,
        isNull,
        reason: 'mất kết nối: chưa phải khác mạng',
      );

      final ok = AgentPrintersMap.detailOf(
        statusOf(lan, AgentPrinterState.connected),
        const {},
      );
      expect(ok.onReconnect, isNull);
      expect(ok.onSwitchNetwork, isNull);

      // Đã tắt nhận lệnh: không tính là lỗi.
      final paused = AgentPrintersMap.detailOf(
        statusOf(lan, AgentPrinterState.disconnected),
        {AgentPrinterSwitches.keyOf(lan)},
      );
      expect(paused.state, AgentPrinterDetailState.paused);
      expect(paused.onReconnect, isNull);
    },
  );

  test(
    'máy in LAN ở mạng khác: có thêm "Đổi mạng"; máy USB khác mạng không có',
    () {
      final other = AgentPrintersMap.detailOf(
        statusOf(lan, AgentPrinterState.otherNetwork),
        const {},
      );
      expect(other.onReconnect, isNotNull);
      expect(other.onSwitchNetwork, isNotNull);

      const usb = FakePrinter(
        refKind: AgentPrinterKind.usb,
        refAddress: 'usb:1',
        refName: 'Máy in tem',
      );
      final usbOther = AgentPrintersMap.detailOf(
        statusOf(usb, AgentPrinterState.otherNetwork),
        const {},
      );
      expect(usbOther.onSwitchNetwork, isNull);
    },
  );

  test('ghép loại máy + kiểu kết nối thành MỘT hàng "Hoá đơn | USB"', () {
    final hd = AgentPrintersMap.splitName('Máy in hoá đơn · XP-80C');
    final usb = AgentPrintersMap.addressLineOf(
      _status(
        const FakePrinter(
          refId: 1,
          refKind: AgentPrinterKind.usb,
          refAddress: 'usb:1',
          refName: 'XP',
        ),
      ),
    );
    final joined = AgentPrintersMap.joinLines(hd.typeLine, usb)!;
    expect(joined.text, hd.typeLine!.text);
    expect(joined.next?.text, 'USB');
    // Thiếu một phần: hiện phần còn lại.
    expect(AgentPrintersMap.joinLines(null, usb)?.text, 'USB');
    expect(AgentPrintersMap.joinLines(hd.typeLine, null)?.next, isNull);
    expect(AgentPrintersMap.joinLines(null, null), isNull);
  });
}
