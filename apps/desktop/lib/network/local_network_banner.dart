import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../ui/widgets/agent_spinner.dart';

import '../ui/agent_theme.dart';
import 'local_network_check.dart';

/// Cảnh báo "macOS đang chặn quyền Mạng cục bộ": hiện khi Agent không nối được
/// máy trong mạng nội bộ dù Internet vẫn vào được — kèm nút mở thẳng trang cài
/// đặt và nút kiểm tra lại. Chỉ chạy trên macOS; ổn thì không hiện gì.
class LocalNetworkBanner extends StatefulWidget {
  const LocalNetworkBanner({super.key, this.check});

  /// Thay bộ kiểm tra khi test; mặc định kiểm tra thật (chỉ macOS).
  final LocalNetworkCheck? check;

  /// Trang cài đặt "Mạng cục bộ" của macOS.
  static const settingsUrl =
      'x-apple.systempreferences:com.apple.preference.security?Privacy_LocalNetwork';

  @override
  State<LocalNetworkBanner> createState() => _LocalNetworkBannerState();
}

class _LocalNetworkBannerState extends State<LocalNetworkBanner>
    with WidgetsBindingObserver {
  LocalNetworkAccess _access = LocalNetworkAccess.ok;
  bool _checking = false;

  bool get _enabled => widget.check != null || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_enabled) unawaited(_run());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Quay lại app (vừa bật quyền trong Cài đặt hệ thống) thì kiểm tra lại.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _access == LocalNetworkAccess.blocked) {
      unawaited(_run());
    }
  }

  Future<void> _run() async {
    if (_checking) return;
    setState(() => _checking = true);
    final access = await (widget.check ?? LocalNetworkCheck()).check();
    if (!mounted) return;
    setState(() {
      _access = access;
      _checking = false;
    });
  }

  Future<void> _openSettings() async {
    try {
      await Process.run('open', [LocalNetworkBanner.settingsUrl]);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled || _access != LocalNetworkAccess.blocked) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AgentColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AgentColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline_rounded, color: AgentColors.warning),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chưa cho phép Agent truy cập mạng nội bộ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'macOS đang chặn nên Agent không tìm thấy và không in '
                      'được ra máy in LAN. Mở Cài đặt → Quyền riêng tư & Bảo '
                      'mật → Mạng cục bộ, bật cho Agent, rồi thoát và mở lại '
                      'Agent.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AgentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _checking ? null : () => unawaited(_run()),
                  child: _checking
                      ? AgentSpinner(size: 18)
                      : const Text('Kiểm tra lại'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => unawaited(_openSettings()),
                  child: const Text('Mở cài đặt'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
