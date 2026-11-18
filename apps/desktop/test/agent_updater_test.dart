import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/update/agent_updater.dart';
import 'package:print_agent_desktop/update/app_version.dart';
import 'package:print_agent_desktop/update/update_installer.dart';
import 'package:print_agent_desktop/update/update_manifest.dart';

const _base =
    'https://github.com/MinhTung263/print_agent/releases/download/v0.2.0';

String _manifest({
  String version = '0.2.0',
  int build = 3,
  String? winHash,
  String? winUrl,
  bool linux = true,
}) {
  final h = winHash ?? sha256.convert(utf8.encode('exe-bytes')).toString();
  return jsonEncode({
    'version': version,
    'build': build,
    'windows': {
      'url': winUrl ?? '$_base/TramInEasyPOS-Setup-$version.exe',
      'sha256': h,
    },
    if (linux)
      'linux': {
        'url': '$_base/easypos-print-agent_$version%2B${build}_amd64.deb',
        'sha256': sha256.convert(utf8.encode('deb-bytes')).toString(),
      },
  });
}

class _FakeInstaller implements UpdateInstaller {
  _FakeInstaller({this.ok = true});
  final bool ok;
  final installed = <File>[];

  @override
  Future<bool> install(File file) async {
    installed.add(file);
    return ok;
  }
}

void main() {
  _macTests();
  group('AppVersion', () {
    test('đọc 0.2.0, 0.2.0+3, v0.2.0+3; sai thì null', () {
      expect(AppVersion.parse('0.2.0+3').toString(), '0.2.0+3');
      expect(AppVersion.parse('v1.10.0').toString(), '1.10.0');
      expect(AppVersion.parse('abc'), isNull);
      expect(AppVersion.parse(''), isNull);
      expect(AppVersion.parse(null), isNull);
    });

    test('so sánh theo số, không theo chuỗi (0.10 > 0.9), rồi theo build', () {
      bool newer(String a, String b) =>
          AppVersion.parse(a)! > AppVersion.parse(b)!;
      expect(newer('0.10.0', '0.9.9'), isTrue);
      expect(newer('1.0.0', '0.99.99'), isTrue);
      expect(newer('0.2.0+4', '0.2.0+3'), isTrue);
      expect(newer('0.2.0', '0.2.0'), isFalse);
      expect(newer('0.2', '0.2.0'), isFalse, reason: '0.2 = 0.2.0');
      expect(newer('0.1.9', '0.2.0'), isFalse);
    });

    test('bản chạy từ mã nguồn (không đóng dấu) thì current = null', () {
      expect(AppVersion.current, isNull);
    });
  });

  group('UpdateManifest', () {
    test('hợp lệ: đọc bản, bộ cài từng hệ điều hành; macOS không có', () {
      final m = UpdateManifest.parse(_manifest())!;
      expect(m.version.toString(), '0.2.0+3');
      expect(m.assetFor('windows')!.fileName, 'TramInEasyPOS-Setup-0.2.0.exe');
      expect(
        m.assetFor('linux')!.fileName,
        'easypos-print-agent_0.2.0+3_amd64.deb',
      );
      expect(m.assetFor('macos'), isNull);
    });

    test(
      'địa chỉ tải ngoài trang phát hành của dự án: bị loại (chống giả mạo)',
      () {
        expect(
          UpdateManifest.parse(
            _manifest(
              winUrl: 'https://evil.example.com/setup.exe',
              linux: false,
            ),
          ),
          isNull,
        );
      },
    );

    test('mã băm sai định dạng / JSON hỏng / thiếu bản: null', () {
      expect(
        UpdateManifest.parse(_manifest(winHash: 'abc')),
        isNotNull,
        reason: 'còn bộ cài Linux hợp lệ',
      );
      expect(
        UpdateManifest.parse(_manifest(winHash: 'abc', linux: false)),
        isNull,
      );
      expect(UpdateManifest.parse('không phải json'), isNull);
      expect(UpdateManifest.parse('{"version":"0.2.0"}'), isNull);
    });
  });

  group('UpdateCommands', () {
    test('Windows: chờ Agent thoát, chạy ngầm kèm /RESTART=1, tự xoá', () {
      final s = UpdateCommands.windowsScript(r'C:\Users\A B\Temp\Setup.exe');
      expect(s, contains('timeout /t 2'));
      expect(
        s,
        contains(
          'start "" /wait "C:\\Users\\A B\\Temp\\Setup.exe" /VERYSILENT',
        ),
      );
      expect(s, contains('/RESTART=1'));
      expect(s, contains('del "%~f0"'));
    });

    test(
      'Linux: pkexec apt-get install, tham số truyền riêng (đường dẫn có khoảng trắng)',
      () {
        expect(
          UpdateCommands.linuxScript,
          contains('pkexec apt-get install -y "\$1"'),
        );
        expect(UpdateCommands.linuxScript, contains('"\$2"'));
      },
    );
  });

  group('AgentUpdater', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('upd_test_'));
    tearDown(() => dir.deleteSync(recursive: true));

    AgentUpdater make({
      required String manifest,
      String current = '0.1.0+1',
      UpdateInstaller? installer,
      Duration? Function()? sinceLastJob,
      void Function()? onExit,
      bool autoInstall = true,
      Duration idle = const Duration(minutes: 10),
      String os = 'windows',
      String? downloaded,
    }) => AgentUpdater(
      current: AppVersion.parse(current),
      fetch: (_) async => manifest,
      download: (asset, target, onProgress) async {
        target.writeAsStringSync(
          downloaded ?? (os == 'windows' ? 'exe-bytes' : 'deb-bytes'),
        );
        onProgress(1);
      },
      installer: installer,
      os: os,
      workDir: dir,
      sinceLastJob: sinceLastJob,
      onExit: onExit,
      autoInstall: autoInstall,
      idleBeforeInstall: idle,
    );

    test(
      'có bản mới + máy rảnh: tải, kiểm mã băm, cài, rồi thoát Agent',
      () async {
        final inst = _FakeInstaller();
        var exited = false;
        final u = make(
          manifest: _manifest(),
          installer: inst,
          sinceLastJob: () => const Duration(hours: 1),
          onExit: () => exited = true,
        );
        await u.check();
        await Future<void>.delayed(const Duration(milliseconds: 900));
        expect(u.available!.version.toString(), '0.2.0+3');
        expect(inst.installed, hasLength(1));
        expect(inst.installed.single.readAsStringSync(), 'exe-bytes');
        expect(exited, isTrue);
        u.dispose();
      },
    );

    test('đang in (vừa có lệnh): tải sẵn nhưng CHƯA cài', () async {
      final inst = _FakeInstaller();
      final u = make(
        manifest: _manifest(),
        installer: inst,
        sinceLastJob: () => const Duration(seconds: 20),
      );
      await u.check();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(u.stage, UpdateStage.ready);
      expect(inst.installed, isEmpty);
      u.dispose();
    });

    test(
      'tắt tự cài: chỉ tải sẵn; khách bấm "Cập nhật ngay" mới cài',
      () async {
        final inst = _FakeInstaller();
        var exited = false;
        final u = make(
          manifest: _manifest(),
          installer: inst,
          autoInstall: false,
          onExit: () => exited = true,
        );
        await u.check();
        expect(u.stage, UpdateStage.ready);
        expect(inst.installed, isEmpty);
        await u.install();
        expect(inst.installed, hasLength(1));
        expect(exited, isTrue);
        u.dispose();
      },
    );

    test('mã băm không khớp: không cài, báo lỗi, xoá tệp hỏng', () async {
      final inst = _FakeInstaller();
      final u = make(
        manifest: _manifest(),
        installer: inst,
        downloaded: 'bi-sua',
        sinceLastJob: () => const Duration(hours: 1),
      );
      await u.check(manual: true);
      expect(u.stage, UpdateStage.error);
      expect(u.error, contains('mã băm'));
      expect(inst.installed, isEmpty);
      expect(dir.listSync(), isEmpty);
      u.dispose();
    });

    test(
      'đã là bản mới nhất / bản cũ hơn: không làm gì; kiểm tra tay thì báo "mới nhất"',
      () async {
        final inst = _FakeInstaller();
        final u = make(
          manifest: _manifest(),
          current: '0.2.0+3',
          installer: inst,
        );
        await u.check();
        expect(u.stage, UpdateStage.idle);
        expect(u.upToDate, isFalse);
        await u.check(manual: true);
        expect(u.upToDate, isTrue);
        expect(inst.installed, isEmpty);
        u.dispose();
      },
    );

    test(
      'bản chạy từ mã nguồn (current = null): tắt hẳn, không hỏi mạng',
      () async {
        var asked = false;
        final u = AgentUpdater(
          current: null,
          fetch: (_) async {
            asked = true;
            return _manifest();
          },
        );
        await u.check();
        u.start();
        expect(u.enabled, isFalse);
        expect(asked, isFalse);
        u.dispose();
      },
    );

    test(
      'mất mạng khi hỏi nền: im lặng (không báo lỗi làm phiền); khách bấm tay thì báo',
      () async {
        final u = AgentUpdater(
          current: AppVersion.parse('0.1.0'),
          fetch: (_) async => throw const SocketException('mất mạng'),
          workDir: dir,
        );
        await u.check();
        expect(u.stage, UpdateStage.idle);
        expect(u.error, isNull);
        await u.check(manual: true);
        expect(u.stage, UpdateStage.error);
        expect(u.error, contains('Không hỏi được'));
        u.dispose();
      },
    );

    test(
      'bộ cài không chạy được (thiếu quyền / pkexec): không thoát Agent, hướng dẫn cài tay',
      () async {
        final inst = _FakeInstaller(ok: false);
        var exited = false;
        final u = make(
          manifest: _manifest(),
          installer: inst,
          os: 'linux',
          sinceLastJob: () => const Duration(hours: 1),
          onExit: () => exited = true,
        );
        await u.check();
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(exited, isFalse);
        expect(u.manualInstall, isTrue);
        expect(u.stage, UpdateStage.ready);
        expect(u.error, contains('sudo apt install'));
        u.dispose();
      },
    );

    test('Linux lấy bộ cài .deb (không phải .exe)', () async {
      final inst = _FakeInstaller();
      final u = make(
        manifest: _manifest(),
        installer: inst,
        os: 'linux',
        sinceLastJob: () => const Duration(hours: 1),
        onExit: () {},
      );
      await u.check();
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(inst.installed.single.path, endsWith('_amd64.deb'));
      u.dispose();
    });
  });
}

void _macTests() {
  group('macOS (chỉ báo + mở trang tải, không tự cài)', () {
    test('manifest có bản macOS (.dmg)', () {
      final m = UpdateManifest.parse(
        jsonEncode({
          'version': '0.2.0',
          'build': 3,
          'macos': {
            'url': '$_base/TramInEasyPOS-0.2.0.dmg',
            'sha256': sha256.convert(utf8.encode('dmg')).toString(),
          },
        }),
      )!;
      expect(m.assetFor('macos')!.fileName, 'TramInEasyPOS-0.2.0.dmg');
      expect(m.assetFor('windows'), isNull);
    });

    test(
      'có bản mới: stage manual, KHÔNG tải, KHÔNG cài; "Tải về" mở đúng địa chỉ',
      () async {
        Uri? opened;
        var downloaded = false;
        final u = AgentUpdater(
          current: AppVersion.parse('0.1.0+1'),
          os: 'macos',
          fetch: (_) async => jsonEncode({
            'version': '0.2.0',
            'build': 3,
            'macos': {
              'url': '$_base/TramInEasyPOS-0.2.0.dmg',
              'sha256': sha256.convert(utf8.encode('dmg')).toString(),
            },
          }),
          download: (a, t, p) async => downloaded = true,
          openUrl: (url) async => opened = url,
        );
        expect(u.manualOnly, isTrue);
        await u.check();
        expect(u.stage, UpdateStage.manual);
        expect(downloaded, isFalse);
        await u.openDownload();
        expect(opened.toString(), '$_base/TramInEasyPOS-0.2.0.dmg');
        u.dispose();
      },
    );
  });
}
