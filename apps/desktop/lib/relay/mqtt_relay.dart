import 'dart:async';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import 'relay_crypto.dart';

/// Trạng thái lệnh — giống `PrintRelayStatus` của app.
abstract final class RelayStatus {
  static const String pending = 'pending';
  static const String printing = 'printing';
  static const String done = 'done';
  static const String failed = 'failed';
}

/// Kênh MQTT của trạm in desktop (WebSocket bảo mật — đi qua được tường lửa chỉ
/// mở cổng web, giống bản web trước). Cùng broker, cùng
/// topic, cùng mã hoá với app EasyPOS nên máy bán hàng thấy trạm này như một
/// máy Agent bình thường.
///
/// Topic dưới [RelayCrypto.topicRoot]:
/// - `stations/{phiên}` (retained): trạm trực tuyến; Last Will xoá khi rớt mạng.
/// - `jobs/{id}`: lệnh in. `claims/{id}`: giành lệnh. `status/{id}`: kết quả.
class MqttRelay {
  MqttRelay({
    required this.crypto,
    this.url = 'wss://broker.emqx.io/mqtt',
    this.port = 8084,
    this.log = print,
  });

  final RelayCrypto crypto;
  final String url;
  final int port;
  final void Function(String message) log;

  /// Mã phiên trên broker (khác mã Agent `id` báo trong thông tin trạm).
  final String sessionId = RelayCrypto.randomId();

  String get _root => crypto.topicRoot;

  MqttServerClient? _client;
  Future<MqttServerClient?>? _connecting;
  final Set<String> _subscribed = {};
  final _messages =
      StreamController<MqttReceivedMessage<MqttMessage>>.broadcast();

  final _connection = StreamController<bool>.broadcast();
  bool connected = false;
  Stream<bool> get connection => _connection.stream;

  void _setConnected(bool value) {
    if (connected == value) return;
    connected = value;
    _connection.add(value);
  }

  Map<String, Object?>? _onlineInfo;

  Future<MqttServerClient?> _connect() {
    final c = _client;
    if (c != null &&
        c.connectionStatus?.state == MqttConnectionState.connected) {
      return Future.value(c);
    }
    return _connecting ??= _open().whenComplete(() => _connecting = null);
  }

  Future<MqttServerClient?> _open() async {
    final client =
        MqttServerClient.withPort(
            url,
            'easypos_desktop_${RelayCrypto.randomId()}',
            port,
          )
          ..useWebSocket = true
          ..keepAlivePeriod = 30
          ..autoReconnect = true
          ..resubscribeOnAutoReconnect = true
          ..websocketProtocols = MqttClientConstants.protocolsSingleDefault
          ..logging(on: false);
    client.onConnected = () => _setConnected(true);
    client.onDisconnected = () => _setConnected(false);
    client.onAutoReconnect = () => _setConnected(false);
    client.onAutoReconnected = () {
      _setConnected(true);
      final info = _onlineInfo;
      log('Đã nối lại broker');
      if (info != null) unawaited(goOnline(info).catchError((Object _) {}));
    };
    // Rớt mạng / đóng tab: broker tự xoá trạng thái trực tuyến (retained rỗng).
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(client.clientIdentifier)
        .withWillTopic('$_root/stations/$sessionId')
        .withWillMessage('')
        .withWillRetain()
        .withWillQos(MqttQos.atLeastOnce)
        .startClean();
    try {
      await client.connect();
    } catch (e) {
      log('Kết nối broker lỗi: $e');
      client.disconnect();
      return null;
    }
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      return null;
    }
    client.updates?.listen((events) => events.forEach(_messages.add));
    _client = client;
    _subscribed.clear();
    _setConnected(true);
    log('Đã kết nối broker');
    return client;
  }

  Future<void> _publish(
    String topic,
    Object? data, {
    bool retain = false,
  }) async {
    final client = await _connect();
    if (client == null) throw StateError('MQTT chưa kết nối');
    final builder = MqttClientPayloadBuilder();
    if (data != null) builder.addString(crypto.encrypt(data));
    client.publishMessage(
      topic,
      MqttQos.atLeastOnce,
      builder.payload!,
      retain: retain,
    );
  }

  /// Tin theo [filter] (`/+` ở cuối = mọi id) → (id, nội dung đã giải mã).
  Stream<(String, Object?)> _watch(String filter) {
    final base = filter.endsWith('/+')
        ? filter.substring(0, filter.length - 1)
        : null;
    late StreamController<(String, Object?)> out;
    StreamSubscription<MqttReceivedMessage<MqttMessage>>? sub;
    out = StreamController<(String, Object?)>(
      onListen: () async {
        sub = _messages.stream.listen((e) {
          final topic = e.topic;
          String id;
          if (base != null) {
            if (!topic.startsWith(base)) return;
            id = topic.substring(base.length);
          } else {
            if (topic != filter) return;
            id = topic.split('/').last;
          }
          final message = e.payload;
          if (message is! MqttPublishMessage) return;
          final bytes = message.payload.message;
          out.add((id, bytes.isEmpty ? null : crypto.decrypt(bytes)));
        });
        final client = await _connect();
        if (client == null) {
          out.addError(StateError('MQTT chưa kết nối'));
        } else if (_subscribed.add(filter)) {
          client.subscribe(filter, MqttQos.atLeastOnce);
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  // --- Trạm in ---------------------------------------------------------------

  Future<void> goOnline(Map<String, Object?> info) async {
    _onlineInfo = info;
    await _publish('$_root/stations/$sessionId', {
      ...info,
      'at': DateTime.now().millisecondsSinceEpoch,
    }, retain: true);
    _listenClaims();
  }

  Future<void> goOffline() async {
    _onlineInfo = null;
    final client = _client;
    if (client == null) return;
    try {
      client.publishMessage(
        '$_root/stations/$sessionId',
        MqttQos.atLeastOnce,
        MqttClientPayloadBuilder().payload!,
        retain: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } catch (_) {}
  }

  /// Lệnh in mới: (mã lệnh, nội dung lệnh).
  Stream<(String, Map<String, Object?>)> watchJobs() => _watch('$_root/jobs/+')
      .where((e) => e.$2 is Map)
      .map((e) => (e.$1, Map<String, Object?>.from(e.$2! as Map)));

  final Map<String, Set<String>> _claimers = {};
  final Map<String, Completer<void>> _ownEcho = {};
  StreamSubscription<(String, Object?)>? _claimSub;

  void _listenClaims() {
    _claimSub ??= _watch('$_root/claims/+').listen((e) {
      final by = e.$2 is Map ? (e.$2! as Map)['by'] : null;
      if (by is! String) return;
      _claimers.putIfAbsent(e.$1, () => <String>{}).add(by);
      if (by == sessionId) {
        final echo = _ownEcho[e.$1];
        if (echo != null && !echo.isCompleted) echo.complete();
      }
    });
  }

  /// Giành lệnh như app: gửi gói giành, chờ gói mình quay về + gom gói trạm khác
  /// 0,5s; trạm có mã phiên NHỎ NHẤT thắng (mọi trạm ra cùng kết quả).
  Future<bool> claimJob(String id) async {
    _listenClaims();
    final echo = _ownEcho.putIfAbsent(id, Completer<void>.new);
    await _publish('$_root/claims/$id', {'by': sessionId});
    try {
      await echo.future.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      return false;
    } finally {
      Timer(const Duration(minutes: 3), () {
        _ownEcho.remove(id);
        _claimers.remove(id);
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final claimers = _claimers[id] ?? {sessionId};
    final winner = claimers.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    if (winner != sessionId) return false;
    await _publish('$_root/status/$id', RelayStatus.printing);
    return true;
  }

  Future<void> ackJob(String id) =>
      _publish('$_root/status/$id', RelayStatus.printing);

  Future<void> completeJob(String id, {required bool success}) => _publish(
    '$_root/status/$id',
    success ? RelayStatus.done : RelayStatus.failed,
  );

  /// Các trạm đang trực tuyến (theo topic `stations/+`, retained) — gồm cả
  /// trạm này; rỗng sau 1,5s khi chưa có trạm nào.
  Stream<List<Map<Object?, Object?>>> watchStations() {
    final stations = <String, Map<Object?, Object?>>{};
    late StreamController<List<Map<Object?, Object?>>> out;
    StreamSubscription<(String, Object?)>? sub;
    Timer? empty;
    out = StreamController(
      onListen: () {
        empty = Timer(const Duration(milliseconds: 1500), () {
          if (stations.isEmpty) out.add(const []);
        });
        sub = _watch('$_root/stations/+').listen((e) {
          final info = e.$2;
          if (info is Map) {
            stations[e.$1] = Map<Object?, Object?>.from(info);
          } else {
            stations.remove(e.$1);
          }
          out.add(stations.values.toList());
        }, onError: out.addError);
      },
      onCancel: () {
        empty?.cancel();
        return sub?.cancel();
      },
    );
    return out.stream;
  }

  /// Gửi lệnh điều khiển tới Agent [agentId] (mã Agent) — giống app.
  Future<void> sendControl(String agentId, Map<String, Object?> command) =>
      _publish('$_root/control/$agentId', {
        ...command,
        'at': DateTime.now().millisecondsSinceEpoch,
      });

  /// Lệnh điều khiển gửi tới Agent [agentId].
  Stream<Map<Object?, Object?>> watchControl(String agentId) =>
      _watch('$_root/control/$agentId')
          .where((e) => e.$2 is Map)
          .map((e) => Map<Object?, Object?>.from(e.$2! as Map));

  /// Kết nối (dùng để báo trạng thái ban đầu).
  Future<bool> connect() async => await _connect() != null;

  Future<void> dispose() async {
    await goOffline();
    await _claimSub?.cancel();
    _claimSub = null;
    _client?.disconnect();
    _client = null;
  }
}
