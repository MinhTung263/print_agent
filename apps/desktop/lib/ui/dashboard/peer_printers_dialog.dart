import 'package:flutter/material.dart';

import '../../agent/print_agent.dart';
import '../agent_map/agent_device_avatar.dart';
import '../ds/ds.dart';
import 'agent_map_card.dart';

/// Máy in của một máy Agent khác (giống bảng "Máy in của máy Agent" trên app).
Future<void> showPeerPrintersDialog(
  BuildContext context,
  Map<Object?, Object?> station, {
  PrintAgent? agent,
}) {
  final printers = station['printers'];
  final names = [
    if (printers is Map && printers['names'] is List)
      for (final p in printers['names'] as List)
        if (p is Map) p,
  ];
  final device = [
    station['model']?.toString() ?? '',
  ].where((e) => e.isNotEmpty).join(' · ');
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: AppRow(
        spacing: AppSpace.sm,
        children: [
          const AgentDeviceAvatar(online: true),
          Expanded(
            child: AppColumn(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AppText.raw(peerLabel(station), variant: .title, maxLines: 2),
                if (device.isNotEmpty)
                  AppText.raw(device, variant: .caption, tone: .secondary),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: names.isEmpty
            ? const AppText(
                'Máy Agent này chưa báo máy in nào',
                tone: .secondary,
              )
            : AppColumn(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpace.sm,
                children: [for (final p in names) _PrinterRow(printer: p)],
              ),
      ),
      actions: [
        // Không có máy in nào: cho xoá (tắt chế độ Agent trên máy đó từ xa).
        if (agent != null && PrintAgent.hasNoPrinters(station))
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.errorRed),
            onPressed: () => _remove(context, agent, station),
            child: const Text('Xoá Agent này'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}

class _PrinterRow extends StatelessWidget {
  const _PrinterRow({required this.printer});

  final Map<Object?, Object?> printer;

  @override
  Widget build(BuildContext context) {
    final ok = printer['ok'] == true;
    final off = printer['on'] == false;
    final kind = printer['kind'];
    final addr = printer['addr']?.toString() ?? '';
    final color = off
        ? AppColors.dsGray5
        : (ok ? AppColors.successGreen : AppColors.errorRed);
    return AppRow(
      spacing: AppSpace.sm,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: AppColors.backgroundPrimary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            switch (kind) {
              'usb' => Icons.usb_rounded,
              'builtin' => Icons.point_of_sale_rounded,
              _ => Icons.print_rounded,
            },
            size: 20,
            color: AppColors.dsGray2,
          ),
        ),
        Expanded(
          child: AppColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText.raw(
                printer['name']?.toString() ?? '',
                variant: .title,
                maxLines: 1,
              ),
              AppText.raw(
                [
                  switch (kind) {
                    'usb' => 'USB',
                    'builtin' => 'Máy in tích hợp',
                    _ => 'LAN',
                  },
                  if (addr.isNotEmpty) addr,
                ].join(' · '),
                variant: .caption,
                tone: .secondary,
              ),
            ],
          ),
        ),
        AppText.raw(
          off ? 'Đã tắt' : (ok ? 'Đang kết nối' : 'Mất kết nối'),
          variant: .caption,
          textColor: color,
        ),
      ],
    );
  }
}

Future<void> _remove(
  BuildContext context,
  PrintAgent agent,
  Map<Object?, Object?> station,
) async {
  final name = peerLabel(station);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Xoá Agent này'),
      content: Text(
        'Tắt chế độ Agent trên $name? Máy đó không có máy in nào; máy đó sẽ tự '
        'kiểm tra lại, có máy in thì không tắt.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.errorRed),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Xoá'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final sent = await agent.removePeer(station);
  if (!context.mounted) return;
  Navigator.pop(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        sent
            ? 'Đã gửi lệnh tắt $name'
            : 'Không gửi được lệnh — Agent đang tắt hoặc mất kết nối',
      ),
    ),
  );
}
