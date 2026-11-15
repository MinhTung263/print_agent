import 'package:flutter_test/flutter_test.dart';
import 'package:print_agent_desktop/auth/auth_service.dart';
import 'package:print_agent_desktop/auth/auth_session.dart';
import 'package:print_agent_desktop/auth/saved_login.dart';
import 'package:print_agent_desktop/auth/secret_store.dart';
import 'package:print_agent_desktop/store/printer_auto_add.dart';
import 'package:print_agent_desktop/store/printer_auto_add_plan.dart';
import 'package:print_agent_desktop/store/store_printer.dart';
import 'package:print_agent_desktop/store/store_printer_api.dart';

class _FakeRepo implements StorePrinterRepository {
  _FakeRepo(this.printers);

  final List<StorePrinter> printers;
  final created = <StorePrinter>[];
  bool failList = false;

  @override
  Future<List<StorePrinter>> list() async {
    if (failList) throw const StoreApiException('lỗi');
    return [...printers];
  }

  @override
  Future<void> create(StorePrinter printer) async {
    created.add(printer);
    printers.add(printer);
  }
}

const _mac1 = '00-5C-17-DA-C8-88';
const _mac2 = 'aa:bb:cc:dd:ee:02';

StorePrinter _store(String ip, {String? mac, String name = 'Bếp'}) =>
    StorePrinter(id: 1, name: name, ip: ip, mac: mac);

void main() {
  final now = DateTime(2026, 11, 15, 10);

  group('PrinterAutoAddPlan', () {
    test('thêm máy in chưa có, bỏ máy đã có (theo MAC hoặc IP)', () {
      final r = PrinterAutoAddPlan.plan(
        found: const [
          FoundPrinter(address: '192.168.1.12', mac: _mac1),
          FoundPrinter(address: '192.168.1.20', mac: _mac2),
          FoundPrinter(address: '192.168.1.30'),
        ],
        existing: [
          // Cùng MAC, đã đổi IP → coi là đã có.
          _store('192.168.1.99', mac: '00:5C:17:DA:C8:88'),
          // Cùng IP (máy cũ không lưu MAC) → đã có.
          _store('192.168.1.30', name: 'Quầy'),
        ],
        memory: const AutoAddMemory(),
        now: now,
      );
      expect(r.toCreate.map((p) => p.ip), ['192.168.1.20']);
      final p = r.toCreate.single;
      expect(p.mac, 'AA:BB:CC:DD:EE:02');
      expect(p.name, 'Máy in mới 1');
      expect(p.pageSize, 'K80');
      expect(p.templates, StorePrinter.receiptTemplates);
      expect(p.templates, isNot(contains(5)), reason: 'không gồm tem');
    });

    test(
      'máy dò thấy không có MAC nhưng trùng IP máy đã lưu → không tạo trùng',
      () {
        final r = PrinterAutoAddPlan.plan(
          found: const [FoundPrinter(address: '192.168.1.12')],
          existing: [_store('192.168.1.12', mac: _mac1)],
          memory: const AutoAddMemory(),
          now: now,
        );
        expect(r.toCreate, isEmpty);
      },
    );

    test('tên không trùng tên đã có', () {
      final r = PrinterAutoAddPlan.plan(
        found: const [
          FoundPrinter(address: '10.0.0.5', mac: _mac1),
          FoundPrinter(address: '10.0.0.6', mac: _mac2),
        ],
        existing: [_store('10.0.0.9', name: 'Máy in mới 1')],
        memory: const AutoAddMemory(),
        now: now,
      );
      expect(r.toCreate.map((p) => p.name), ['Máy in mới 2', 'Máy in mới 3']);
    });

    test('người dùng vừa xoá → 7 ngày không tự thêm lại, sau đó thêm', () {
      // Lượt trước máy có trong danh sách.
      final before = PrinterAutoAddPlan.plan(
        found: const [],
        existing: [_store('192.168.1.12', mac: _mac1)],
        memory: const AutoAddMemory(),
        now: now,
      );
      // Người dùng xoá khỏi danh sách.
      final after = PrinterAutoAddPlan.plan(
        found: const [FoundPrinter(address: '192.168.1.12', mac: _mac1)],
        existing: const [],
        memory: before.memory,
        now: now.add(const Duration(minutes: 30)),
      );
      expect(after.toCreate, isEmpty);
      final later = PrinterAutoAddPlan.plan(
        found: const [FoundPrinter(address: '192.168.1.12', mac: _mac1)],
        existing: const [],
        memory: after.memory,
        now: now.add(const Duration(days: 8)),
      );
      expect(later.toCreate, hasLength(1));
    });

    test('trí nhớ đọc / ghi JSON', () {
      final m = AutoAddMemory(
        known: const {'mac:AA:BB:CC:DD:EE:02'},
        removed: {'ip:10.0.0.5': now},
      );
      final back = AutoAddMemory.fromJson(m.toJson());
      expect(back.known, m.known);
      expect(back.removed, m.removed);
    });
  });

  group('PrinterAutoAdd', () {
    late Map<String, String> store;
    late _FakeRepo repo;
    var enabled = true;
    var added = <StorePrinter>[];

    PrinterAutoAdd build(List<FoundPrinter> found) => PrinterAutoAdd(
      repository: repo,
      scan: () async => found,
      enabled: () => enabled,
      companyKey: () => '7',
      readStore: (k) => store[k],
      writeStore: (k, v) => store[k] = v,
      onAdded: (a) => added = a,
      now: () => now,
    );

    setUp(() {
      store = {};
      repo = _FakeRepo([]);
      enabled = true;
      added = [];
    });

    test('thêm máy in mới, chạy lại không thêm lần hai', () async {
      final auto = build(const [
        FoundPrinter(address: '192.168.1.12', mac: _mac1),
      ]);
      expect(await auto.runOnce(), 1);
      expect(added.single.name, 'Máy in mới 1');
      expect(await auto.runOnce(), 0);
      expect(repo.created, hasLength(1));
    });

    test('không phải trạm chính / trạm tắt → không thêm', () async {
      enabled = false;
      final auto = build(const [FoundPrinter(address: '10.0.0.5')]);
      expect(await auto.runOnce(), 0);
      expect(repo.created, isEmpty);
    });

    test('không đọc được danh sách cửa hàng → không thêm gì', () async {
      repo.failList = true;
      final auto = build(const [FoundPrinter(address: '10.0.0.5')]);
      expect(await auto.runOnce(), 0);
      expect(repo.created, isEmpty);
    });
  });

  group('AuthSession', () {
    test('token theo công ty; đổi công ty thì không dùng token cũ', () async {
      var company = 1;
      final s = AuthSession(
        companyId: () => company,
        store: MemorySecretStore(),
      );
      await s.signedIn(const AuthTokens(idToken: 'a', refreshToken: 'r'));
      expect(await s.token(), 'a');
      company = 2;
      expect(await s.token(), isNull);
    });

    test('hết hạn: gia hạn bằng refresh token', () async {
      final s = AuthSession(
        companyId: () => 1,
        store: MemorySecretStore(),
        refresh: (r, t) async => const AuthTokens(idToken: 'b'),
      );
      await s.signedIn(const AuthTokens(idToken: 'a', refreshToken: 'r'));
      expect(await s.renew(), 'b');
      expect(await s.token(), 'b');
    });

    test('refresh hỏng: đăng nhập lại bằng tài khoản đã nhớ', () async {
      final secrets = MemorySecretStore();
      final saved = SecureSavedLoginStore(secrets);
      await saved.save(const SavedLogin(username: 'u', password: 'p'));
      int? loginCompany;
      final s = AuthSession(
        companyId: () => 9,
        store: secrets,
        savedLogin: saved,
        refresh: (r, t) async => null,
        login: (u, p, c) async {
          loginCompany = c;
          return const AuthTokens(idToken: 'fresh');
        },
      );
      await s.signedIn(const AuthTokens(idToken: 'old', refreshToken: 'r'));
      expect(await s.renew(), 'fresh');
      expect(loginCompany, 9);
    });

    test('không có cách gia hạn → null', () async {
      final s = AuthSession(
        companyId: () => 1,
        store: MemorySecretStore(),
        refresh: (r, t) async => null,
      );
      expect(await s.renew(), isNull);
    });
  });
}
