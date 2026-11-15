import 'package:flutter/material.dart';

import '../../agent_theme.dart';
import '../../../printers/printer_option.dart';

/// Thẻ một máy in: biểu tượng loại kết nối, tên, địa chỉ; viền xanh + dấu
/// tích khi đang chọn; nhãn "Đang dùng" với máy in hiện tại.
class PrinterOptionTile extends StatelessWidget {
  const PrinterOptionTile({
    super.key,
    required this.option,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final PrinterOption option;
  final bool selected;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final usb = option.kind == PrinterOptionKind.usb;
    final accent = usb ? AgentColors.agent : AgentColors.primary;
    return Material(
      color: selected
          ? AgentColors.primary.withValues(alpha: 0.06)
          : AgentColors.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? AgentColors.primary : AgentColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  usb ? Icons.usb_rounded : Icons.lan_rounded,
                  color: accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            option.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (current) ...[
                          const SizedBox(width: 8),
                          const _Badge('Đang dùng'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: option.needsSetup
                            ? AgentColors.warning
                            : AgentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? AgentColors.primary : AgentColors.muted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: AgentColors.success.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AgentColors.success,
      ),
    ),
  );
}
