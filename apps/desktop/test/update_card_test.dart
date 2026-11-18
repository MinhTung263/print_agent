import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent/print_agent.dart' show AgentSwitch;
import 'package:print_agent_desktop/ui/dashboard/update_card.dart';
import 'package:print_agent_desktop/update/agent_updater.dart';
import 'package:print_agent_desktop/update/app_version.dart';
import 'package:print_agent_desktop/update/update_installer.dart';

const _base =
    'https://github.com/MinhTung263/print_agent/releases/download/v0.2.0';

String _manifest() => jsonEncode({
  'version': '0.2.0',
  'build': 1,
  'windows': {
    'url': '$_base/TramInEasyPOS-Setup-0.2.0.exe',
    'sha256': sha256.convert(utf8.encode('exe')).toString(),
  },
});

class _Installer implements UpdateInstaller {
  final installed = <File>[];
  @override
  Future<bool> install(File file) async {
    installed.add(file);
    return true;
  }
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('upd_card_'));
  tearDown(() => dir.deleteSync(recursive: true));

  AgentUpdater make({
    String current = '0.1.0',
    bool auto = false,
    _Installer? inst,
  }) => AgentUpdater(
    current: AppVersion.parse(current),
    fetch: (_) async => _manifest(),
    download: (a, t, p) async {
      t.writeAsStringSync('exe');
      p(1);
    },
    installer: inst,
    os: 'windows',
    workDir: dir,
    autoInstall: auto,
    onExit: () {},
  );

  Future<void> pump(WidgetTester t, AgentUpdater u) => t.pumpWidget(
    MaterialApp(
      home: Scaffold(body: UpdateCard(updater: u)),
    ),
  );

  testWidgets('bản chạy từ mã nguồn (không có phiên bản): không hiện gì', (
    t,
  ) async {
    await pump(t, AgentUpdater(current: null));
    expect(find.byType(Card), findsNothing);
    expect(find.textContaining('Phiên bản'), findsNothing);
  });

  testWidgets(
    'bình thường: hiện phiên bản + nút kiểm tra; kiểm tra tay ra "mới nhất"',
    (t) async {
      final u = make(current: '0.2.0+1');
      await pump(t, u);
      expect(find.text('Phiên bản 0.2.0+1'), findsOneWidget);
      await t.tap(find.text('Kiểm tra cập nhật'));
      await t.pumpAndSettle();
      expect(find.text('Đã là bản mới nhất.'), findsOneWidget);
      u.dispose();
    },
  );

  testWidgets(
    'có bản mới đã tải: hiện bản mới + "Cập nhật ngay" cài đúng tệp đã tải',
    (t) async {
      final inst = _Installer();
      final u = make(inst: inst);
      await pump(t, u);
      await t.runAsync(() => u.check());
      await t.pump();
      expect(find.text('Có bản mới 0.2.0+1'), findsOneWidget);
      await t.tap(find.text('Cập nhật ngay'));
      // Chờ hết khoảng nghỉ 600ms trước khi Agent thoát (đồng hồ giả của test).
      await t.pump(const Duration(seconds: 1));
      expect(
        inst.installed.single.path,
        endsWith('TramInEasyPOS-Setup-0.2.0.exe'),
      );
      u.dispose();
    },
  );

  testWidgets('công tắc "Tự cập nhật khi máy rảnh" đổi được và báo để lưu', (
    t,
  ) async {
    bool? saved;
    final u = AgentUpdater(
      current: AppVersion.parse('0.1.0'),
      os: 'windows',
      autoInstall: true,
      onAutoInstallChanged: (on) => saved = on,
    );
    await pump(t, u);
    expect(t.widget<AgentSwitch>(find.byType(AgentSwitch)).value, isTrue);
    await t.tap(find.byType(AgentSwitch));
    await t.pump();
    expect(u.autoInstall, isFalse);
    expect(saved, isFalse);
    u.dispose();
  });
}
