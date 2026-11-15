import 'package:flutter/material.dart';
import 'package:print_agent/src/presentation/kit/kit.dart';

/// Bố cục màn Máy Agent:
/// - Điện thoại / màn hẹp: một cột cuộn (sơ đồ ở trên, cài đặt bên dưới).
/// - Tablet đủ rộng: 2 cột cuộn riêng, tỉ lệ 5 : 6 như Master–Detail
///   (ADAPTIVE_LAYOUT_GUIDELINES) — sơ đồ bên trái luôn trong tầm mắt, số liệu /
///   nhật ký lệnh in bên phải.
///
/// [top] (công tắc "Dùng máy này làm Agent") luôn ở ĐẦU vùng cuộn — điện thoại:
/// trên cả sơ đồ; tablet: đầu cột phải — để không bị các thẻ khác (Agent khác,
/// nhật ký...) đẩy xuống khuất.
class AgentLayout extends StatelessWidget {
  const AgentLayout({
    super.key,
    required this.top,
    required this.map,
    required this.side,
  });

  final Widget top;
  final Widget map;
  final List<Widget> side;

  /// Bề rộng tối thiểu để chia 2 cột (tablet dọc hẹp vẫn dùng 1 cột).
  static const double _twoPaneMinWidth = 720;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final insets = context.pageInsets;
        if (!AppConfig.isTabletDevice() ||
            constraints.maxWidth < _twoPaneMinWidth) {
          return SingleChildScrollView(
            padding: insets,
            child: AppColumn(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: ShareDimens.itemSpacing,
              children: [top, map, ...side],
            ),
          );
        }
        return AppRow(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: ShareDimens.itemSpacing,
          children: [
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: insets.copyWith(right: 0),
                child: map,
              ),
            ),
            Expanded(
              flex: 6,
              child: SingleChildScrollView(
                padding: insets.copyWith(left: 0),
                child: AppColumn(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: ShareDimens.itemSpacing,
                  children: [top, ...side],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
