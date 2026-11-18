import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'update_installer.dart';
import 'update_manifest.dart';

enum UpdateStage {
  /// Chưa có gì / đã là bản mới nhất.
  idle,
  checking,

  /// Có bản mới, đang tải.
  downloading,

  /// Có bản mới nhưng máy này không tự cài được (macOS): khách bấm "Tải về" rồi cài tay.
  manual,

  /// Đã tải và kiểm tra mã băm xong, sẵn sàng cài.
  ready,
  installing,
  error,
}

typedef ManifestFetcher = Future<String> Function(Uri url);

/// Tải [asset] về [target], báo tiến độ 0..1 qua [onProgress].
typedef AssetDownloader =
    Future<void> Function(
      UpdateAsset asset,
      File target,
      void Function(double progress) onProgress,
    );

/// Agent tự cập nhật: hỏi `update.json` trên GitHub Releases, có bản mới thì tải (kiểm tra SHA-256) rồi cài
/// khi máy rảnh (không in lệnh nào gần đây) hoặc khi khách bấm "Cập nhật ngay".
///
/// Bản chạy từ mã nguồn ([AppVersion.current] `null`) thì không làm gì.
class AgentUpdater extends ChangeNotifier {
  AgentUpdater({
    this.current,
    Uri? manifestUrl,
    ManifestFetcher? fetch,
    AssetDownloader? download,
    UpdateInstaller? installer,
    String? os,
    Directory? workDir,
    Duration? Function()? sinceLastJob,
    void Function()? onExit,
    this.checkEvery = const Duration(hours: 6),
    this.firstCheckAfter = const Duration(seconds: 45),
    this.idleBeforeInstall = const Duration(minutes: 10),
    this.autoInstall = true,
    this.onAutoInstallChanged,
    Future<void> Function(Uri url)? openUrl,
  }) : manifestUrl = manifestUrl ?? defaultManifestUrl,
       _fetch = fetch ?? _httpFetch,
       _download = download ?? _httpDownload,
       _installer = installer ?? platformUpdateInstaller(),
       _os = os ?? Platform.operatingSystem,
       _workDir = workDir,
       _sinceLastJob = sinceLastJob,
       _onExit = onExit ?? (() => exit(0)),
       _openUrl = openUrl ?? _systemOpen;

  static final Uri defaultManifestUrl = Uri.parse(
    'https://github.com/MinhTung263/print_agent/releases/latest/download/update.json',
  );

  /// Bản đang chạy; `null` = tắt cập nhật.
  final AppVersion? current;
  final Uri manifestUrl;
  final Duration checkEvery;
  final Duration firstCheckAfter;

  /// Tự cài khi máy rảnh ít nhất chừng này (không in lệnh nào) — tránh cắt ngang lúc đang in.
  final Duration idleBeforeInstall;

  /// Tắt thì chỉ tải sẵn, khách bấm "Cập nhật ngay" mới cài.
  bool autoInstall;

  /// Gọi khi khách đổi lựa chọn tự cài (để lưu).
  final void Function(bool on)? onAutoInstallChanged;

  final ManifestFetcher _fetch;
  final AssetDownloader _download;
  final UpdateInstaller? _installer;
  final String _os;
  final Directory? _workDir;
  final Duration? Function()? _sinceLastJob;
  final void Function() _onExit;
  final Future<void> Function(Uri url) _openUrl;

  UpdateStage stage = UpdateStage.idle;

  /// Bản mới tìm thấy (khi [stage] là downloading / ready / installing).
  UpdateManifest? available;

  /// Tiến độ tải 0..1.
  double progress = 0;

  /// Lý do lỗi gần nhất (hiện cho khách khi họ tự bấm cập nhật).
  String? error;

  /// Lần kiểm tra tự bấm vừa rồi cho thấy đã là bản mới nhất.
  bool upToDate = false;

  /// Không cài tự động được (không có quyền / thiếu `pkexec`): khách cài tay từ [file].
  bool manualInstall = false;
  File? file;

  Timer? _timer;
  Timer? _idleTimer;
  bool _disposed = false;

  bool get enabled => current != null;

  /// Hệ điều hành này không tự cài bản mới (macOS): chỉ báo và mở trang tải.
  bool get manualOnly => _os == 'macos';

  /// Mở trang tải bản mới bằng trình duyệt / Finder (macOS).
  Future<void> openDownload() async {
    final asset = available?.assetFor(_os);
    if (asset == null) return;
    await _openUrl(asset.url);
  }

  /// Bật / tắt tự cài khi máy rảnh ([onAutoInstallChanged] lưu lại lựa chọn).
  void setAutoInstall(bool on) {
    if (autoInstall == on) return;
    autoInstall = on;
    onAutoInstallChanged?.call(on);
    notifyListeners();
    if (on) _maybeAutoInstall();
  }

  /// Bắt đầu hỏi định kỳ (lần đầu sau [firstCheckAfter] cho Agent khởi động xong).
  void start() {
    if (!enabled) return;
    _timer?.cancel();
    _timer = Timer(firstCheckAfter, () {
      unawaited(check());
      _timer = Timer.periodic(checkEvery, (_) => unawaited(check()));
    });
  }

  /// Hỏi bản mới ngay. [manual]: khách tự bấm — báo lỗi / "đã là bản mới nhất" rõ ràng.
  Future<void> check({bool manual = false}) async {
    final cur = current;
    if (cur == null ||
        stage == UpdateStage.checking ||
        stage == UpdateStage.downloading ||
        stage == UpdateStage.installing) {
      return;
    }
    if (stage == UpdateStage.ready && !manual) {
      _maybeAutoInstall();
      return;
    }
    upToDate = false;
    _set(UpdateStage.checking, error: null);
    UpdateManifest? m;
    try {
      m = UpdateManifest.parse(
        await _fetch(manifestUrl).timeout(const Duration(seconds: 20)),
      );
    } catch (e) {
      _fail('Không hỏi được bản mới: $e', quiet: !manual);
      return;
    }
    if (m == null) {
      _fail('Thông tin bản mới không hợp lệ', quiet: !manual);
      return;
    }
    final asset = m.assetFor(_os);
    if (asset == null || !(m.version > cur)) {
      available = null;
      // Khách tự bấm kiểm tra: cho biết đã là bản mới nhất.
      upToDate = manual;
      _set(UpdateStage.idle, error: null);
      return;
    }
    available = m;
    // macOS: không tải / không cài ngầm (chưa ký Developer ID) — chỉ báo có bản mới và mở trang tải.
    if (manualOnly) {
      _set(UpdateStage.manual, error: null);
      return;
    }
    await _downloadAndVerify(asset);
  }

  Future<void> _downloadAndVerify(UpdateAsset asset) async {
    _set(UpdateStage.downloading, error: null);
    progress = 0;
    final dir =
        _workDir ?? Directory.systemTemp.createTempSync('easypos_update_');
    final target = File(
      '${dir.path}${Platform.pathSeparator}${asset.fileName}',
    );
    try {
      await _download(asset, target, (p) {
        progress = p;
        notifyListeners();
      }).timeout(const Duration(minutes: 20));
      final hash = (await sha256.bind(target.openRead()).first).toString();
      if (hash != asset.sha256) {
        await target.delete().catchError((_) => target);
        _fail('Bộ cài tải về bị lỗi (mã băm không khớp) — sẽ thử lại sau');
        return;
      }
    } catch (e) {
      _fail('Không tải được bản mới: $e');
      return;
    }
    file = target;
    progress = 1;
    _set(UpdateStage.ready, error: null);
    _maybeAutoInstall();
  }

  /// Máy rảnh thì cài; chưa rảnh thì hẹn hỏi lại sau 1 phút.
  void _maybeAutoInstall() {
    if (!autoInstall || stage != UpdateStage.ready || _disposed) return;
    final idle = _sinceLastJob?.call();
    final isIdle = idle == null || idle >= idleBeforeInstall;
    if (isIdle) {
      unawaited(install());
      return;
    }
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 1), _maybeAutoInstall);
  }

  /// Cài bản đã tải rồi thoát Agent (bộ cài mở lại Agent sau khi xong).
  Future<void> install() async {
    final f = file;
    if (stage != UpdateStage.ready || f == null) return;
    _set(UpdateStage.installing, error: null);
    final ok = await (_installer?.install(f) ?? Future.value(false));
    if (!ok) {
      manualInstall = true;
      _fail(
        _os == 'linux'
            ? 'Không cài tự động được. Cài tay: sudo apt install ${f.path}'
            : 'Không cài tự động được. Mở tệp ${f.path} để cài.',
      );
      stage = UpdateStage.ready;
      notifyListeners();
      return;
    }
    // Cho bộ cài kịp chạy rồi thoát: bộ cài thay file của chính Agent đang chạy.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _onExit();
  }

  void _fail(String message, {bool quiet = false}) {
    // Lỗi lúc hỏi nền (mất mạng...) không làm phiền khách: giữ im lặng, lần sau hỏi lại.
    _set(UpdateStage.error, error: quiet ? null : message);
    if (quiet) stage = UpdateStage.idle;
    notifyListeners();
  }

  void _set(UpdateStage s, {String? error}) {
    stage = s;
    this.error = error;
    notifyListeners();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }
}

Future<void> _systemOpen(Uri url) async {
  try {
    if (Platform.isMacOS) {
      await Process.run('open', [url.toString()]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', '', url.toString()]);
    } else {
      await Process.run('xdg-open', [url.toString()]);
    }
  } catch (_) {}
}

Future<String> _httpFetch(Uri url) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await c.getUrl(url);
    final res = await req.close();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: url);
    }
    return await res.transform(utf8.decoder).join();
  } finally {
    c.close(force: true);
  }
}

Future<void> _httpDownload(
  UpdateAsset asset,
  File target,
  void Function(double) onProgress,
) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await c.getUrl(asset.url);
    final res = await req.close();
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: asset.url);
    }
    final total = res.contentLength;
    var got = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in res) {
        got += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress(got / total);
      }
    } finally {
      await sink.close();
    }
  } finally {
    c.close(force: true);
  }
}
