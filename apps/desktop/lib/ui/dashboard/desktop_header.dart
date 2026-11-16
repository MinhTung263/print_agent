import 'dart:async';

import 'package:flutter/material.dart';
import '../widgets/agent_spinner.dart';
import 'package:print_agent/print_agent.dart';

import '../../agent/desktop_agent.dart';
import '../agent_theme.dart';

/// Bộ giao diện của app máy tính: như [MaterialAgentUiKit], riêng đầu trang
/// là [DesktopHeader] (logo, cửa hàng, trạng thái, đăng xuất).
class DesktopAgentUiKit extends MaterialAgentUiKit {
  const DesktopAgentUiKit(this.agent);

  final DesktopAgent agent;

  /// Vòng chờ kiểu Cupertino cho mọi bảng của module Agent chạy trên máy tính.
  @override
  Widget spinner({double size = 18, Color? color}) =>
      AgentSpinner(size: size, color: color);

  @override
  Widget page({required String title, required Widget body}) => Scaffold(
    backgroundColor: AgentColors.bg,
    appBar: DesktopHeader(agent: agent),
    body: body,
  );
}

/// Đầu trang gọn: logo + "Trạm in" + cửa hàng đang đăng nhập | trạng thái
/// nhận lệnh in | Đăng xuất (luôn có, kể cả khi chưa bật trạm in).
class DesktopHeader extends StatelessWidget implements PreferredSizeWidget {
  const DesktopHeader({super.key, required this.agent});

  final DesktopAgent agent;

  static const double height = 64;

  @override
  Size get preferredSize => const Size.fromHeight(height);

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: agent,
    builder: (context, _) {
      final c = agent.config;
      final store = [
        if (c.companyName.isNotEmpty) c.companyName,
        if (c.userName.isNotEmpty) c.userName,
      ].join(' · ');
      return Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: const BoxDecoration(
          color: AgentColors.card,
          border: Border(bottom: BorderSide(color: AgentColors.border)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/app/app_icon.png',
                width: 36,
                height: 36,
                filterQuality: FilterQuality.medium,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trạm in',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AgentColors.text,
                    ),
                  ),
                  if (store.isNotEmpty)
                    Text(
                      store,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AgentColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            _StatusPill(on: agent.isOn),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => unawaited(agent.logout()),
              style: TextButton.styleFrom(
                foregroundColor: AgentColors.textSecondary,
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Đăng xuất'),
            ),
          ],
        ),
      );
    },
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    final color = on ? AgentColors.success : AgentColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(
            on ? 'Đang nhận lệnh in' : 'Chưa bật trạm in',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: on ? AgentColors.success : AgentColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
