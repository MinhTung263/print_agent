import 'package:flutter/material.dart';

import '../../agent_theme.dart';

/// Đầu hộp chọn máy in: biểu tượng, tiêu đề, trạng thái dò, nút tìm lại.
class PrinterPickerHeader extends StatelessWidget {
  const PrinterPickerHeader({
    super.key,
    required this.scanning,
    required this.onRescan,
  });

  final bool scanning;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AgentColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.print_rounded, color: AgentColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn máy in',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              scanning
                  ? 'Đang tìm máy in trong mạng và cổng USB…'
                  : 'Máy bán hàng chọn "máy in của trạm in" sẽ in ra máy này',
              style: const TextStyle(
                fontSize: 13,
                color: AgentColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      scanning
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              tooltip: 'Tìm lại',
              onPressed: onRescan,
              icon: const Icon(Icons.refresh_rounded),
            ),
    ],
  );
}

/// Chưa thấy máy in nào (đang dò / hướng dẫn).
class PrinterPickerEmpty extends StatelessWidget {
  const PrinterPickerEmpty({super.key, required this.scanning});

  final bool scanning;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    decoration: BoxDecoration(
      color: AgentColors.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AgentColors.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          scanning ? Icons.radar_rounded : Icons.print_disabled_outlined,
          size: 36,
          color: AgentColors.muted,
        ),
        const SizedBox(height: 10),
        Text(
          scanning ? 'Đang tìm máy in…' : 'Chưa thấy máy in nào',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        if (!scanning) ...[
          const SizedBox(height: 4),
          const Text(
            'Bật máy in, cắm dây mạng (cùng mạng với máy này) hoặc cắm cáp '
            'USB rồi bấm tìm lại.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AgentColors.textSecondary),
          ),
        ],
      ],
    ),
  );
}
