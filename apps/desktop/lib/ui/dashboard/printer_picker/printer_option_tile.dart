import 'package:flutter/material.dart';

import '../../../agent/printer_type.dart';
import '../../../printers/paper_size_detector.dart';
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
    this.multi = false,
    this.onBeep,
    this.added = false,
  });

  final PrinterOption option;
  final bool selected;
  final bool current;

  /// Máy đã được thêm vào trạm in này rồi (không chọn lại): hiện nhãn "Đã thêm" + dấu V.
  final bool added;
  final VoidCallback? onTap;

  /// Chọn nhiều máy: hộp tick vuông thay cho nút tròn.
  final bool multi;

  /// Bấm để máy in kêu bíp (nhận ra đó là máy nào); `null` = không có nút.
  final VoidCallback? onBeep;

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
                        if (option.type != null) ...[
                          const SizedBox(width: 8),
                          _TypePill(option.type!),
                        ],
                        if (option.type != PrinterType.label) ...[
                          const SizedBox(width: 6),
                          _PaperPill(PaperSizeDetector.guess(option.title)),
                        ],
                        if (current || added) ...[
                          const SizedBox(width: 8),
                          _Badge(current ? 'Đang dùng' : 'Đã thêm'),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.warning ?? option.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: option.needsSetup || option.blocked
                            ? AgentColors.warning
                            : AgentColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onBeep != null)
                IconButton(
                  tooltip: 'Kêu bíp để nhận ra máy in này',
                  visualDensity: VisualDensity.compact,
                  onPressed: onBeep,
                  icon: const Icon(Icons.volume_up_rounded, size: 22),
                  color: AgentColors.primary,
                ),
              const SizedBox(width: 4),
              Icon(
                current || added
                    ? Icons.check_circle_rounded
                    : multi
                    ? (selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded)
                    : (selected
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded),
                color: current || added
                    ? AgentColors.success
                    : onTap == null
                    ? AgentColors.border
                    : (selected ? AgentColors.primary : AgentColors.muted),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nhãn loại máy in đã nhận ra: "Máy in tem" (tím) / "Máy in hoá đơn" (xanh).
class _TypePill extends StatelessWidget {
  const _TypePill(this.type);

  final PrinterType type;

  @override
  Widget build(BuildContext context) {
    final label = type == PrinterType.label;
    final color = label ? AgentColors.agent : AgentColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type.title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
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

/// Khổ giấy: "80mm" (đoán được từ tên máy) hoặc "80mm · gợi ý" (mặc định, mờ hơn).
class _PaperPill extends StatelessWidget {
  const _PaperPill(this.guess);

  final PaperSizeGuess guess;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(
        color: guess.detected ? AgentColors.primary : AgentColors.border,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      guess.pill,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: guess.detected ? AgentColors.primary : AgentColors.textSecondary,
      ),
    ),
  );
}
