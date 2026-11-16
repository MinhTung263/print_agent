import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:print_agent_core/print_agent_core.dart';

/// Cách mở Realtime Database cho hàng đợi (app chủ cung cấp — không lưu thông
/// tin đăng nhập trong thư viện).
class FirebaseRelayConfig {
  const FirebaseRelayConfig({
    required this.options,
    required this.databaseUrl,
    required this.email,
    required this.password,
    this.appName = 'print-station',
    this.log,
  });

  /// Cấu hình project chứa database (có thể khác project mặc định của app).
  final FirebaseOptions options;
  final String databaseUrl;

  /// Tài khoản Firebase Auth đăng nhập trước khi đọc / ghi.
  final String email;
  final String password;

  /// Tên Firebase app phụ (tách khỏi app mặc định).
  final String appName;
  final void Function(String message)? log;
}

/// Hàng đợi lệnh in của một quán trên Firebase Realtime Database, dưới [root]:
/// - `stations/{id}`: trạm đang trực tuyến (tự xoá khi mất kết nối);
/// - `jobs/{id}`: lệnh in ([PrintRelayJob.toMap]).
class FirebasePrintRelayTransport implements PrintRelayTransport {
  FirebasePrintRelayTransport(this._db, this.root);

  /// Mở hàng đợi ở nhánh [path]; `null` khi không mở được database.
  static Future<FirebasePrintRelayTransport?> open(
    String path,
    FirebaseRelayConfig config,
  ) async {
    final db = await _database(config);
    return db == null ? null : FirebasePrintRelayTransport(db, db.ref(path));
  }

  static Future<FirebaseDatabase?>? _databaseFuture;

  static Future<FirebaseDatabase?> _database(FirebaseRelayConfig config) =>
      _databaseFuture ??= _openDatabase(config).then((db) {
        // Lỗi (VD mất mạng lúc đăng nhập): lần sau thử lại.
        if (db == null) _databaseFuture = null;
        return db;
      });

  static Future<FirebaseDatabase?> _openDatabase(
    FirebaseRelayConfig config,
  ) async {
    try {
      final app = Firebase.apps.any((a) => a.name == config.appName)
          ? Firebase.app(config.appName)
          : await Firebase.initializeApp(
              name: config.appName,
              options: config.options,
            );
      final auth = FirebaseAuth.instanceFor(app: app);
      if (auth.currentUser == null) {
        await auth.signInWithEmailAndPassword(
          email: config.email,
          password: config.password,
        );
      }
      return FirebaseDatabase.instanceFor(
        app: app,
        databaseURL: config.databaseUrl,
      );
    } catch (e) {
      (config.log ?? debugPrint)('[REMOTE-PRINT] Mở Firebase Database lỗi: $e');
      return null;
    }
  }

  final FirebaseDatabase _db;
  final DatabaseReference root;

  DatabaseReference get _jobs => root.child('jobs');
  DatabaseReference get _stations => root.child('stations');

  DatabaseReference? _presence;
  StreamSubscription<DatabaseEvent>? _connectedSub;
  Timer? _heartbeat;

  /// Nhịp tim của trạm: rút điện / sập nguồn (không kịp báo ngắt) thì server
  /// mất 1–2 phút mới chạy `onDisconnect` — máy gửi bỏ qua trạm có nhịp tim cũ
  /// hơn [staleAfter] thay vì gửi lệnh vào "trạm ma".
  static const Duration heartbeatEvery = Duration(seconds: 30);
  static const Duration staleAfter = Duration(minutes: 3);

  @override
  Future<void> goOnline(Map<String, Object?> info) async {
    await goOffline();
    // Khoá cố định theo mã trạm (không `push()` mỗi lần): báo lại / nối lại
    // ghi đè đúng một nút, không sinh nút trạm thừa.
    final id = info['id'];
    final presence = _presence = id is String && id.isNotEmpty
        ? _stations.child(id)
        : _stations.push();
    // Mất mạng rồi có lại: đăng ký lại trạng thái trực tuyến (onDisconnect chỉ
    // có hiệu lực cho một lần kết nối).
    _connectedSub = _db.ref('.info/connected').onValue.listen((event) async {
      if (event.snapshot.value != true) return;
      try {
        await presence.onDisconnect().remove();
        await presence.set({
          ...info,
          'at': ServerValue.timestamp,
          'hb': ServerValue.timestamp,
        });
      } catch (_) {}
    });
    _heartbeat = Timer.periodic(heartbeatEvery, (_) {
      unawaited(
        presence
            .update({'hb': ServerValue.timestamp})
            .catchError((Object _) {}),
      );
    });
  }

  @override
  Future<void> goOffline() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _connectedSub?.cancel();
    _connectedSub = null;
    final presence = _presence;
    _presence = null;
    if (presence == null) return;
    try {
      await presence.onDisconnect().cancel();
      await presence.remove();
    } catch (_) {}
  }

  @override
  Stream<PrintRelayQueuedJob> watchJobs() => _jobs.onChildAdded
      // Không dùng `snapshot.ref`: trên Android, snapshot của onChildAdded trả ref
      // của nút cha (`jobs`) chứ không phải của lệnh vừa thêm.
      .where((e) => e.snapshot.key != null && e.snapshot.key != _jobs.key)
      .map((e) => PrintRelayQueuedJob(e.snapshot.key!, e.snapshot.value));

  @override
  Future<bool> claimJob(String id) async {
    // Lần chạy đầu Firebase gọi hàm với giá trị trong bộ nhớ đệm — thường là
    // `null`. Trả `abort` lúc đó là huỷ hẳn, không bao giờ thử lại với giá trị
    // thật trên server. Trả `success(null)` để server so sánh, thấy khác và gọi
    // lại với giá trị thật.
    final result = await _jobs.child(id).child('status').runTransaction((
      value,
    ) {
      if (value == null) return Transaction.success(null);
      return value == PrintRelayStatus.pending
          ? Transaction.success(PrintRelayStatus.printing)
          : Transaction.abort();
    });
    return result.committed &&
        result.snapshot.value == PrintRelayStatus.printing;
  }

  @override
  Future<void> holdJob(String id) =>
      _jobs.child(id).child('status').set(PrintRelayStatus.held);

  @override
  Future<void> ackJob(String id) =>
      _jobs.child(id).child('status').set(PrintRelayStatus.printing);

  /// Máy gửi tự xoá lệnh khi nhận kết quả; máy gửi rớt mạng / tắt app trước
  /// đó thì trạm xoá sau [_cleanupAfter] — lệnh cũ không tích tụ trên `jobs`.
  static const Duration _cleanupAfter = Duration(minutes: 1);

  @override
  Future<void> completeJob(String id, {required bool success}) async {
    await _jobs.child(id).update({
      'status': success ? PrintRelayStatus.done : PrintRelayStatus.failed,
      // Bỏ ảnh khỏi lệnh ngay khi in xong — không giữ nội dung in trên mây.
      'image': null,
      'images': null,
    });
    Timer(_cleanupAfter, () => unawaited(deleteJob(id).catchError((_) {})));
  }

  @override
  Future<void> deleteJob(String id) => _jobs.child(id).remove();

  /// Độ lệch đồng hồ máy này so với server (ms) — để so nhịp tim đúng kể cả
  /// khi giờ máy sai.
  int _serverOffset = 0;
  StreamSubscription<DatabaseEvent>? _offsetSub;

  /// Xoá mọi nút trạm có mã Agent trùng [station] (khoá có thể là mã Agent hoặc
  /// khoá `push()` của app bản cũ).
  @override
  Future<bool> removeStation(Map<Object?, Object?> station) async {
    final id = station['id']?.toString() ?? '';
    if (id.isEmpty) return false;
    try {
      final snap = await _stations.get();
      final value = snap.value;
      if (value is! Map) return false;
      var removed = false;
      for (final e in value.entries) {
        final v = e.value;
        if (e.key == id || (v is Map && v['id']?.toString() == id)) {
          await _stations.child('${e.key}').remove();
          removed = true;
        }
      }
      return removed;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<List<Map<Object?, Object?>>> watchStations() {
    _offsetSub ??= _db.ref('.info/serverTimeOffset').onValue.listen((e) {
      final v = e.snapshot.value;
      if (v is num) _serverOffset = v.toInt();
    });
    return _stations.onValue.map((e) {
      final value = e.snapshot.value;
      if (value is! Map) return const [];
      final now = DateTime.now().millisecondsSinceEpoch + _serverOffset;
      return [
        for (final station in value.values)
          if (station is Map && !_stale(station, now))
            Map<Object?, Object?>.from(station),
      ];
    });
  }

  /// Trạm bản mới (có nhịp tim `hb`) im lặng quá [staleAfter] = trạm ma. Trạm
  /// bản cũ không có `hb` thì giữ như trước.
  static bool _stale(Map<Object?, Object?> station, int now) {
    final hb = station['hb'];
    return hb is num && now - hb.toInt() > staleAfter.inMilliseconds;
  }

  @override
  Future<String> submitJob(Map<String, Object?> data) async {
    final ref = _jobs.push();
    await ref.set(data);
    return ref.key!;
  }

  /// Kết nối thật tới Firebase (`.info/connected`): rớt mạng / nối lại phát ngay.
  @override
  Stream<bool> watchConnection() =>
      _db.ref('.info/connected').onValue.map((e) => e.snapshot.value == true);

  @override
  Stream<String?> watchJobStatus(String id) => _jobs
      .child(id)
      .child('status')
      .onValue
      .map((e) => e.snapshot.value?.toString());
}
