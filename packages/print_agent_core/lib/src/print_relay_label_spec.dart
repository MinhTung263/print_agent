/// Kích thước THẬT của một hàng tem trong lệnh in tem (mm) — để Agent máy tính in
/// đúng cả khổ app chưa có tên (`labelSize`). App bản cũ bỏ qua trường này.
class PrintRelayLabelSpec {
  const PrintRelayLabelSpec({
    required this.widthMm,
    required this.heightMm,
    this.gapMm = 2,
    this.count = 1,
    this.shiftXDots,
  });

  /// Bề rộng cả hàng tem (mm).
  final int widthMm;

  /// Chiều cao tem (mm).
  final int heightMm;

  /// Khe giữa hai tem theo chiều dọc (mm).
  final int gapMm;

  /// Số tem trên một hàng.
  final int count;

  /// Dịch ảnh theo chiều ngang (chấm, 8 chấm = 1mm); `null` = mặc định của app
  /// (-8, bù lề widget tem). Ảnh vẽ sẵn đúng lề (VD từ trang web) gửi `0`.
  final int? shiftXDots;

  Map<String, Object?> toMap() => {
    'w': widthMm,
    'h': heightMm,
    'gap': gapMm,
    'count': count,
    'shiftX': ?shiftXDots,
  };

  /// Đọc từ lệnh; `null` khi thiếu / sai kích thước.
  static PrintRelayLabelSpec? fromMap(Object? raw) {
    if (raw is! Map) return null;
    int? n(Object? v) => v is num ? v.round() : null;
    final w = n(raw['w']);
    final h = n(raw['h']);
    if (w == null || h == null || w < 5 || h < 5 || w > 300 || h > 300) {
      return null;
    }
    final gap = n(raw['gap']);
    final count = n(raw['count']);
    return PrintRelayLabelSpec(
      widthMm: w,
      heightMm: h,
      gapMm: gap == null || gap < 0 || gap > 20 ? 2 : gap,
      count: count == null || count < 1 || count > 8 ? 1 : count,
      shiftXDots: n(raw['shiftX']),
    );
  }
}
