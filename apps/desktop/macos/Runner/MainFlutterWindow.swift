import Cocoa
import FlutterMacOS
import window_manager

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Agent đang bật: tắt App Nap. Cửa sổ ẩn / bị che thì macOS làm chậm timer và đóng băng
    // socket nhận lệnh in hàng chục giây (`caffeinate` chỉ chặn máy ngủ, không chặn App Nap).
    let power = FlutterMethodChannel(
      name: "vn.softdreams.easypos.agent/power",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    power.setMethodCallHandler { [weak self] call, result in
      guard call.method == "preventAppNap" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.setAppNapPrevented(call.arguments as? Bool ?? false)
      result(true)
    }

    super.awakeFromNib()
  }

  private var activity: NSObjectProtocol?

  /// Giữ / thả "hoạt động người dùng khởi tạo" — chỉ chặn App Nap, vẫn cho máy tự ngủ khi rảnh
  /// (chặn ngủ do `caffeinate` lo khi Agent bật).
  private func setAppNapPrevented(_ on: Bool) {
    if on {
      guard activity == nil else { return }
      activity = ProcessInfo.processInfo.beginActivity(
        options: [.userInitiatedAllowingIdleSystemSleep],
        reason: "EasyPOS Print Agent đang nhận lệnh in")
    } else if let a = activity {
      ProcessInfo.processInfo.endActivity(a)
      activity = nil
    }
  }

  // Không tự hiện cửa sổ: phía Dart (window_manager) quyết định hiện / chạy ẩn.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
