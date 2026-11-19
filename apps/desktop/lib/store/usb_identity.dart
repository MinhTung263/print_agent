/// Nhận dạng máy in USB: hãng (VID), dòng máy (PID) và số serial (nếu máy có).
///
/// Máy in USB trong cửa hàng lưu mã do app điện thoại đọc (`USB:v1155_p22336_sABC`, số THẬP
/// PHÂN), còn Agent máy tính đọc địa chỉ riêng của hệ điều hành (Linux `usb:0483:5740:serial`,
/// Windows `usbp:\\?\usb#vid_0483&pid_5740#serial#...`, số THẬP LỤC PHÂN). Cả hai quy về cùng
/// một [UsbIdentity] để biết "máy USB này chính là máy kia".
class UsbIdentity {
  const UsbIdentity(this.vid, this.pid, [this.serial = '']);

  final int vid;
  final int pid;

  /// Rỗng khi máy không có serial (hoặc Windows tự đặt mã theo cổng).
  final String serial;

  bool get hasSerial => serial.isNotEmpty;

  /// Cùng hãng + dòng máy.
  bool sameModel(UsbIdentity o) => vid == o.vid && pid == o.pid;

  /// Chắc chắn cùng một máy: cùng model và cùng serial (cả hai đều có).
  bool sameDevice(UsbIdentity o) =>
      sameModel(o) && hasSerial && o.hasSerial && serial == o.serial;

  /// Mã của cửa hàng (app điện thoại): `USB:v{vid}_p{pid}[_s{serial}]`, số thập phân.
  static UsbIdentity? fromStore(String? raw) {
    final m = RegExp(
      r'^(?:USB:)?v(\d+)_p(\d+)(?:_s(.*))?$',
      caseSensitive: false,
    ).firstMatch((raw ?? '').trim());
    if (m == null) return null;
    return UsbIdentity(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      _serial(m.group(3)),
    );
  }

  /// Địa chỉ máy in USB trên máy tính (Linux, Windows); macOS/hàng in không có VID/PID → `null`.
  static UsbIdentity? fromLocal(String? address) {
    final a = (address ?? '').trim();
    final linux = RegExp(
      r'^usb:([0-9a-f]{4}):([0-9a-f]{4})(?::(.*))?$',
      caseSensitive: false,
    ).firstMatch(a);
    if (linux != null) {
      return UsbIdentity(
        int.parse(linux.group(1)!, radix: 16),
        int.parse(linux.group(2)!, radix: 16),
        _serial(linux.group(3)),
      );
    }
    final win = RegExp(
      r'usb#vid_([0-9a-f]{4})&pid_([0-9a-f]{4})#([^#]*)#',
      caseSensitive: false,
    ).firstMatch(a);
    if (win != null) {
      return UsbIdentity(
        int.parse(win.group(1)!, radix: 16),
        int.parse(win.group(2)!, radix: 16),
        _serial(win.group(3)),
      );
    }
    return null;
  }

  // Windows đặt mã dạng `5&2a1b3c&0&1` khi máy không có serial: đó là mã theo cổng, không dùng.
  static String _serial(String? s) {
    final v = (s ?? '').trim();
    return v.contains('&') ? '' : v;
  }

  @override
  String toString() => 'UsbIdentity($vid:$pid:$serial)';
}
