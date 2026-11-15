import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Khoá + topic của hàng đợi in MQTT — PHẢI giống hệt app EasyPOS
/// (`MqttPrintRelayTransport` trong plugin printer_label):
/// - secret = `easypos-print-relay-v1|{env}/c{companyId}_{ownerId}`;
/// - topic gốc = `{prefix}/{sha256('topic|secret')[0..32]}`;
/// - khoá AES-256-GCM = `sha256('key|secret')`; gói = base64(iv 12 byte + bản mã).
class RelayCrypto {
  RelayCrypto(String shopKey, {String prefix = 'easypos/print_relay'})
    : _secret = 'easypos-print-relay-v1|$shopKey',
      _prefix = prefix;

  final String _secret;
  final String _prefix;

  late final String topicRoot =
      '$_prefix/'
      '${sha256.convert(utf8.encode('topic|$_secret')).toString().substring(0, 32)}';

  late final enc.Encrypter _aes = enc.Encrypter(
    enc.AES(
      enc.Key(
        Uint8List.fromList(sha256.convert(utf8.encode('key|$_secret')).bytes),
      ),
      mode: enc.AESMode.gcm,
    ),
  );

  /// Khoá hàng đợi của công ty — giống `_shopKey` của app: môi trường (chữ
  /// thường, ký tự lạ → `_`) + `c{companyId}_{ownerId}`.
  static String shopKey({
    required String env,
    required int companyId,
    required int ownerId,
  }) {
    final e = env.replaceAll(RegExp('[^A-Za-z0-9]+'), '_').toLowerCase();
    return '$e/c${companyId}_$ownerId';
  }

  String encrypt(Object data) {
    final iv = enc.IV.fromSecureRandom(12);
    final encrypted = _aes.encryptBytes(utf8.encode(jsonEncode(data)), iv: iv);
    return base64Encode([...iv.bytes, ...encrypted.bytes]);
  }

  /// `null` khi gói không giải mã được (khoá khác / bị sửa / gói rác).
  Object? decrypt(List<int> payload) {
    try {
      final raw = base64Decode(utf8.decode(payload));
      if (raw.length < 13) return null;
      final plain = _aes.decryptBytes(
        enc.Encrypted(Uint8List.fromList(raw.sublist(12))),
        iv: enc.IV(Uint8List.fromList(raw.sublist(0, 12))),
      );
      return jsonDecode(utf8.decode(plain));
    } catch (_) {
      return null;
    }
  }

  static String randomId() {
    final r = Random.secure();
    return List.generate(
      8,
      (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}
