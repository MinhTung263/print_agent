import 'package:flutter/material.dart';
import '../ds/ds.dart';

/// Một hàng chỉnh: tên + nút − / giá trị / nút +, nút lớn 44px để bấm dễ.
class CalibrationStepper extends StatelessWidget {
  const CalibrationStepper({
    super.key,
    required this.title,
    required this.hint,
    required this.valueText,
    required this.onMinus,
    required this.onPlus,
  });

  final String title;
  final String hint;
  final String valueText;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  Widget _btn(IconData icon, VoidCallback onTap) => SizedBox.square(
    dimension: 44,
    child: FilledButton.tonal(
      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
      onPressed: onTap,
      child: Icon(icon),
    ),
  );

  @override
  Widget build(BuildContext context) => AppRow(
    spacing: AppSpace.sm,
    children: [
      Expanded(
        child: AppColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(title),
            AppText(hint, variant: .caption, tone: .secondary),
          ],
        ),
      ),
      _btn(Icons.remove_rounded, onMinus),
      SizedBox(
        width: 84,
        child: Text(
          valueText,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      _btn(Icons.add_rounded, onPlus),
    ],
  );
}
