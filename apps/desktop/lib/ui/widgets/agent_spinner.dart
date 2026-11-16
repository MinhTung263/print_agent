import 'package:flutter/cupertino.dart';

/// Vòng chờ (loading) kiểu Cupertino của Agent. Màu mặc định theo chữ / biểu tượng
/// xung quanh (nút nền xanh thì vòng trắng, nút viền thì vòng xanh).
class AgentSpinner extends StatelessWidget {
  const AgentSpinner({super.key, this.size = 18, this.color});

  /// Đường kính (px).
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone =
        color ??
        IconTheme.of(context).color ??
        DefaultTextStyle.of(context).style.color;
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: CupertinoActivityIndicator(radius: size / 2.2, color: tone),
      ),
    );
  }
}
