import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/printers/printer_option.dart';
import 'package:print_agent_desktop/ui/dashboard/printer_picker/printer_option_tile.dart';

Widget _tile({bool added = false, bool? connected}) => MaterialApp(
  home: Scaffold(
    body: PrinterOptionTile(
      option: PrinterOption.lan('192.168.1.64', model: 'HPRT'),
      selected: false,
      current: false,
      added: added,
      connected: connected,
      onTap: null,
    ),
  ),
);

void main() {
  testWidgets('máy đã thêm và đang kết nối: hiện "Đã kết nối"', (t) async {
    await t.pumpWidget(_tile(added: true, connected: true));
    expect(find.text('Đã thêm'), findsOneWidget);
    expect(find.text('Đã kết nối'), findsOneWidget);
    expect(find.text('Mất kết nối'), findsNothing);
  });

  testWidgets('máy đã thêm nhưng mất kết nối: hiện "Mất kết nối"', (t) async {
    await t.pumpWidget(_tile(added: true, connected: false));
    expect(find.text('Mất kết nối'), findsOneWidget);
    expect(find.text('Đã kết nối'), findsNothing);
  });

  testWidgets('máy chưa thêm: không hiện trạng thái kết nối', (t) async {
    await t.pumpWidget(_tile());
    expect(find.text('Đã kết nối'), findsNothing);
    expect(find.text('Mất kết nối'), findsNothing);
  });
}
