import 'dart:async';

import 'package:flutter/material.dart';
import 'package:print_agent/print_agent.dart' show AgentSwitch;

import '../../update/agent_updater.dart';
import '../ds/ds.dart';

/// Phiên bản Agent + tự cập nhật: tải bản mới ngầm, cài khi máy rảnh; khách có thể bấm "Cập nhật ngay".
/// Bản chạy từ mã nguồn (không có phiên bản) không hiện gì.
class UpdateCard extends StatelessWidget {
  const UpdateCard({super.key, required this.updater});

  final AgentUpdater updater;

  @override
  Widget build(BuildContext context) {
    if (!updater.enabled) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: updater,
      builder: (context, _) {
        final u = updater;
        final stage = u.stage;
        final next = u.available?.version;
        final (title, caption) = switch (stage) {
          UpdateStage.downloading => (
            'Đang tải bản $next',
            '${(u.progress * 100).round()}%',
          ),
          UpdateStage.ready => (
            'Có bản mới $next',
            u.autoInstall
                ? 'Agent sẽ tự cập nhật khi máy không in trong ít phút. Hoặc bấm "Cập nhật ngay".'
                : 'Bấm "Cập nhật ngay" để cài.',
          ),
          UpdateStage.installing => (
            'Đang cài bản $next',
            'Agent sẽ tự mở lại sau vài giây.',
          ),
          UpdateStage.checking => ('Đang kiểm tra bản mới…', ''),
          UpdateStage.error => ('Chưa cập nhật được', u.error ?? ''),
          UpdateStage.idle => (
            'Phiên bản ${u.current}',
            u.upToDate ? 'Đã là bản mới nhất.' : '',
          ),
        };
        return BaseCard.section(
          child: AppColumn(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpace.sm,
            children: [
              AppText(title, variant: .title),
              if (caption.isNotEmpty)
                AppText(
                  caption,
                  variant: .caption,
                  tone: .secondary,
                  maxLines: 4,
                ),
              if (stage == UpdateStage.downloading)
                LinearProgressIndicator(
                  value: u.progress == 0 ? null : u.progress,
                ),
              if (stage == UpdateStage.ready)
                FilledButton(
                  onPressed: () => unawaited(u.install()),
                  child: const Text('Cập nhật ngay'),
                ),
              if (stage == UpdateStage.error || stage == UpdateStage.idle)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => unawaited(u.check(manual: true)),
                    child: Text(
                      stage == UpdateStage.error
                          ? 'Thử lại'
                          : 'Kiểm tra cập nhật',
                    ),
                  ),
                ),
              AppRow(
                spacing: AppSpace.sm,
                children: [
                  const Expanded(child: AppText('Tự cập nhật khi máy rảnh')),
                  AgentSwitch(
                    value: u.autoInstall,
                    onChanged: u.setAutoInstall,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
