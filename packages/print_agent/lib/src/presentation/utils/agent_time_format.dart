import 'package:intl/intl.dart';

/// Giờ hiển thị trên màn Máy Agent: luôn theo giờ Việt Nam (GMT+7), không theo
/// múi giờ cài trên máy — máy POS (VD Sunmi T1 G) hay để múi giờ GMT, hiện giờ
/// máy sẽ lệch 7 tiếng. Mốc thời gian lưu là thời điểm tuyệt đối nên đổi đúng.
String formatAgentTime(DateTime time, {String pattern = 'HH:mm:ss dd/MM'}) =>
    DateFormat(pattern).format(time.toUtc().add(const Duration(hours: 7)));
