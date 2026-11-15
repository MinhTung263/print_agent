# EasyPOS Print Agent (Windows / Linux / macOS)

Máy Agent chạy trên máy tính: nhận lệnh in hoá đơn của công ty (cùng hàng đợi
MQTT với app EasyPOS) rồi gửi lệnh **ESC/POS thẳng tới máy in LAN** (cổng RAW
9100). Máy tính **không phải cài driver máy in**.

- App bán hàng thấy Agent này như một máy Agent bình thường. Bật "Máy in tích
  hợp của máy Agent" ở app là lệnh in sẽ ra **máy in của Agent** (chọn ở Cài đặt →
  Máy in của Agent: quét LAN hoặc nhập IP).
- Bật **"In hộ máy in LAN của cửa hàng"**: Agent nhận cả lệnh gửi tới máy in LAN
  khác (giành lệnh như Agent Android). Agent kiểm tra kết nối được tới máy in đó
  rồi mới giành, nên Agent ở mạng khác không giành mất lệnh.
- Ảnh hoá đơn được chuyển sang raster `GS v 0` **khớp từng byte** với bản native
  Android (ngưỡng xám 200, dải 128 dòng), hỏi giấy bằng `DLE EOT` trước khi in
  (hết giấy / mở nắp thì báo lỗi, không gửi phiếu), có mở két và in nhiều bản.
- Chưa hỗ trợ: máy in USB, in tem (TSPL).

## Chạy nền

- Biểu tượng ở **khay hệ thống**, menu: Mở cửa sổ · Bật/Tắt Agent · Tự chạy khi
  bật máy · Thoát. Đóng cửa sổ chỉ ẩn xuống khay — Agent vẫn nhận lệnh.
- **Tự chạy khi bật máy** (Windows: `HKCU\...\Run`, Linux:
  `~/.config/autostart/`): bật sẵn ở lần chạy đầu, mở với `--background` → chạy
  ẩn dưới khay (chưa đăng nhập thì vẫn hiện cửa sổ). Tắt ở Cài đặt hoặc menu khay.
- Mỗi máy một Agent: mở thêm lần nữa thì bản đang chạy hiện cửa sổ lên.
- Ubuntu GNOME cần extension AppIndicator để thấy biểu tượng khay (Ubuntu đã có
  sẵn `ubuntu-appindicators`).

## Cấu trúc

| Thư mục | Nội dung |
|---|---|
| `lib/escpos/` | Lõi Dart thuần (không import Flutter): mã hoá raster, lệnh ESC/POS, cổng TCP 9100, quét LAN |
| `lib/desktop/` | Khay hệ thống, ẩn cửa sổ, tự chạy khi bật máy, một bản duy nhất |
| `lib/agent/` | Agent: cấu hình (file JSON), nhận lệnh, chọn máy in, nhật ký |
| `lib/relay/` | MQTT (WebSocket bảo mật) + mã hoá — cùng định dạng với app |
| `lib/ui/` | Giao diện (giống màn Máy Agent của app) |

Cấu hình lưu ở: Windows `%APPDATA%\EasyPOS\PrintAgent\config.json`, Linux
`~/.config/easypos-print-agent/config.json`, macOS
`~/Library/Application Support/EasyPOS/PrintAgent/config.json`. Mỗi máy chỉ chạy
một Agent (khoá `agent.lock` cùng thư mục).

## Phát triển

```
fvm dart analyze lib test
fvm flutter test
fvm flutter run -d macos                 # hoặc -d windows / -d linux
fvm flutter run -d macos -a --preview    # xem trước giao diện bằng dữ liệu mẫu
fvm flutter build windows --release      # build trên máy Windows; linux trên Ubuntu
fvm dart run tool/gen_tray_icon.dart     # sinh lại biểu tượng khay (assets/tray/)
```

Build Linux cần: `sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libayatana-appindicator3-dev`.

## Bảo mật

Khoá hàng đợi suy ra từ `env/companyId/ownerId` (giống app). Trước khi phát hành
rộng nên để backend cấp khoá / token theo công ty, và chuyển khỏi broker công
khai `broker.emqx.io`.
