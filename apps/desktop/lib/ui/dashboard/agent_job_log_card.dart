import 'dart:async';

import 'package:flutter/material.dart';

import '../../agent/print_agent.dart';
import '../ds/ds.dart';

/// Lệnh in gần đây (giống app): số thành công / lỗi + 3 lệnh mới nhất, "Xem tất
/// cả" mở danh sách đầy đủ.
class AgentJobLogCard extends StatelessWidget {
  const AgentJobLogCard({super.key, required this.agent});

  final PrintAgent agent;
  static const int _preview = 3;

  @override
  Widget build(BuildContext context) {
    final all = agent.log;
    final failed = agent.failed;
    final preview = all.take(_preview).toList();
    return BaseCard.section(
      child: AppColumn(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        spacing: AppSpace.sm,
        children: [
          AppRow(
            spacing: AppSpace.sm,
            children: [
              const Expanded(
                child: AppText('Lệnh in gần đây', variant: .title),
              ),
              if (all.isNotEmpty)
                AppText(
                  '${all.length - failed} thành công · $failed lỗi',
                  variant: .caption,
                  tone: .secondary,
                  textColor: failed > 0 ? AppColors.errorRed : null,
                ),
            ],
          ),
          if (all.isEmpty)
            const AppText(
              'Chưa có lệnh in nào được gửi tới máy này',
              variant: .caption,
              tone: .secondary,
            )
          else
            for (var i = 0; i < preview.length; i++) ...[
              if (i > 0) const AppDivider(),
              AgentJobRow(entry: preview[i]),
            ],
          if (all.length > _preview)
            BaseTap(
              onTap: () => unawaited(_showAll(context)),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: AppText(
                  'Xem tất cả (${all.length})',
                  variant: .title,
                  textColor: AppColors.primaryBlueBase,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAll(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Lệnh in gần đây'),
      content: SizedBox(
        width: 420,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: agent.log.length,
          separatorBuilder: (_, _) => const AppDivider(),
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AgentJobRow(entry: agent.log[i]),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

/// Một lệnh in hộ (giống dòng nhật ký trên app).
class AgentJobRow extends StatelessWidget {
  const AgentJobRow({super.key, required this.entry});

  final AgentJobEntry entry;

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')} '
      '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final color = e.ok ? AppColors.successGreen : AppColors.errorRed;
    return AppRow(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpace.sm,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.receipt_long_rounded, color: color, size: 20),
        ),
        Expanded(
          child: AppColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              AppText.raw(
                ['Hoá đơn', if (e.copies > 1) '${e.copies} bản'].join(' · '),
                variant: .title,
                maxLines: 1,
              ),
              _IconLine(icon: Icons.print_rounded, text: 'Máy in mặc định'),
              // Máy gửi + giờ chung một dòng (gọn trên điện thoại).
              _IconLine(
                icon: Icons.devices_rounded,
                text: 'Từ ${e.sender ?? 'máy không rõ'} · ${_time(e.at)}',
              ),
              if (e.error != null)
                _IconLine(
                  icon: Icons.error_outline_rounded,
                  text: e.error!,
                  color: AppColors.errorRed,
                ),
            ],
          ),
        ),
        Icon(
          e.ok ? Icons.check_circle_rounded : Icons.error_rounded,
          color: color,
          size: 20,
        ),
      ],
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AppRow(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 14, color: color ?? AppColors.dsGray2),
        ),
        Expanded(
          child: AppText.raw(
            text,
            variant: .caption,
            tone: .secondary,
            textColor: color,
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}
