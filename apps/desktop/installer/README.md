# Bộ cài Agent

CI (`.github/workflows/ci.yml`) tự build cả hai bộ cài, tải ở mục **Artifacts**
của lần chạy: `easypos-print-agent-windows-setup` (Setup .exe) và
`easypos-print-agent-linux-deb` (.deb). Phần dưới là cách build tại máy.

Phiên bản lấy từ `version:` trong `apps/desktop/pubspec.yaml` (`0.1.0+1` →
Windows `0.1.0` build `1`, deb `0.1.0+1`).

Tự chạy khi bật máy do **app tự quản** (bật sẵn ở lần chạy đầu, tắt được trong
Cài đặt / menu khay). Bộ cài không tạo thêm mục tự chạy nên không bị chạy hai lần.

## Windows (Setup .exe)

Cần: Flutter (fvm), [Inno Setup 6.3+](https://jrsoftware.org/isdl.php).

```bat
cd apps\desktop
fvm flutter build windows --release
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" /DMyAppVersion=0.1.0 /DMyAppBuild=1 installer\windows\easypos_print_agent.iss
```

Ra file `build\installer\TramInEasyPOS-Setup-<phiên bản>.exe`. Bộ cài:

- Cài cho cả máy vào `C:\Program Files\EasyPOS\Tram in EasyPOS` (cần quyền admin).
- Lối tắt Start Menu, tuỳ chọn lối tắt Desktop, tuỳ chọn mở app ngay sau khi cài.
- Mở tường lửa Windows chiều vào TCP 9101 (nhận phiếu qua LAN), chỉ cho đúng
  file `easypos_print_agent.exe`; gỡ app thì xoá rule.
- Tắt app đang chạy (kể cả đang ẩn dưới khay) trước khi cài đè / gỡ.
- Tiếng Việt nếu bản Inno trên máy có `Languages\Vietnamese.isl`, không thì tiếng Anh.
- Gỡ app giữ lại dữ liệu đăng nhập/cấu hình của người dùng.
- File `.iss` phải giữ mã **UTF-8 có BOM**.
- Máy khách chưa có Visual C++ Redistributable: CI chép sẵn `msvcp140.dll`,
  `vcruntime140.dll`, `vcruntime140_1.dll` vào thư mục Release. Build tại máy thì
  tự chép mấy file đó từ `C:\Windows\System32` vào `build\windows\x64\runner\Release`
  trước khi chạy ISCC.

## Linux (.deb, Ubuntu/Debian amd64)

Cần: Flutter, `clang cmake ninja-build pkg-config libgtk-3-dev
libayatana-appindicator3-dev`, `dpkg-deb`.

```bash
cd apps/desktop
fvm flutter build linux --release
bash installer/linux/build_deb.sh
sudo apt install ./build/installer/easypos-print-agent_*_amd64.deb
```

Gói cài:

| Đường dẫn | Nội dung |
|---|---|
| `/opt/easypos-print-agent/` | Bản build Flutter |
| `/usr/bin/easypos-print-agent` | Symlink chạy từ terminal |
| `/usr/share/applications/vn.softdreams.easypos.easypos_print_agent.desktop` | Lối tắt menu |
| `/usr/share/icons/hicolor/256x256/apps/easypos-print-agent.png` | Icon |
| `/etc/udev/rules.d/60-easypos-printer.rules` | Quyền ghi máy in USB |
| `/etc/modules-load.d/easypos-print-agent.conf` | Nạp module `usblp` |

**Máy in USB**: app ghi thẳng `/dev/usb/lp*` (module `usblp`), mặc định chỉ root
và nhóm `lp` ghi được. Quy tắc udev dùng `TAG+="uaccess"`: người đang đăng nhập
tại máy được quyền ghi, đăng xuất là hết quyền, an toàn hơn `MODE="0666"` (mọi
tài khoản đều ghi được). Nếu app chạy không có phiên đăng nhập (SSH, dịch vụ),
thêm người dùng vào nhóm `lp`: `sudo usermod -aG lp <tên>` rồi đăng nhập lại.
Cắm lại máy in sau khi cài nếu chưa thấy máy in.

Bản build trên Ubuntu 24.04 (máy CI) cần glibc của 24.04, nên **không chạy được
trên Ubuntu 22.04 trở xuống**. Cần hỗ trợ bản cũ thì build trên máy/CI Ubuntu cũ.

Biến môi trường của `build_deb.sh`: `BUNDLE_DIR`, `OUT_DIR`, `VERSION`, `MAINTAINER`.
