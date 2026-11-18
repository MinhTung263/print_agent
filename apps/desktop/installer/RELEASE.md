# Phát hành Agent cho khách

## Quy trình mỗi lần ra bản mới
1. Sửa `version:` trong `apps/desktop/pubspec.yaml` (ví dụ `0.2.0+3`; số sau dấu `+` là số build, tăng mỗi lần).
2. Commit và đẩy lên `main`, chờ CI xanh.
3. Gắn tag đúng bằng `v` + số phiên bản và đẩy lên:
   ```bash
   git tag v0.2.0 && git push origin v0.2.0
   ```
4. CI (`.github/workflows/ci.yml`, job **Phát hành**) tự:
   - build Windows + Linux + macOS, đóng dấu phiên bản vào app (`--dart-define=APP_VERSION`);
   - tạo **GitHub Release** `v0.2.0` với: `TramInEasyPOS-Setup-0.2.0.exe`, `easypos-print-agent_0.2.0+3_amd64.deb`,
     `TramInEasyPOS-0.2.0.dmg` (macOS), bản tên cố định `TramInEasyPOS-Setup.exe` /
     `easypos-print-agent_amd64.deb` / `TramInEasyPOS.dmg` (cho link "mới nhất") và
     `update.json` (Agent hỏi file này để tự cập nhật).
   - Tag không khớp `version:` trong pubspec thì job dừng, không phát hành sai.

## Khách cài lần đầu
Gửi link trang tải: `https://minhtung263.github.io/print_agent/download.html` (tự nhận Windows / Linux).

## Agent tự cập nhật
- Mở app 45 giây thì hỏi `releases/latest/download/update.json`, sau đó mỗi 6 giờ.
- Có bản mới: tải ngầm, kiểm tra SHA-256, rồi **cài khi máy không in lệnh nào trong 10 phút** (khách cũng có thể bấm
  "Cập nhật ngay"; công tắc "Tự cập nhật khi máy rảnh" tắt được).
- Chỉ tải từ `https://github.com/MinhTung263/print_agent/releases/download/...` (địa chỉ lạ trong `update.json` bị loại).
- Windows: chạy bộ cài ngầm (`/VERYSILENT /RESTART=1`), Windows hỏi quyền quản trị (UAC) một lần, bộ cài mở lại Agent.
- Linux: `pkexec apt-get install -y <.deb>` (hộp thoại mật khẩu của hệ thống), rồi mở lại Agent. Máy không có `pkexec`
  thì Agent hiện lệnh `sudo apt install ...` cho khách tự chạy.
- macOS: không tự cài (bản chưa ký Developer ID). Agent chỉ báo "Có bản mới" kèm nút **Tải về** mở tệp `.dmg`; khách kéo
  vào Applications thay bản cũ.
- Bản chạy từ mã nguồn (không có `APP_VERSION`): tắt tự cập nhật.

## Chưa có
- Ký số bộ cài Windows (không ký thì Windows hiện "Unknown publisher") — cần mua chứng chỉ code signing.
- Ký Developer ID + notarize cho macOS (hiện khách phải chuột phải → Open lần đầu) — cần tài khoản Apple Developer.
- Android: Agent trên Android nằm trong app EasyPOS (kho `easy_pos`), cập nhật qua Google Play; repo này chưa có app Android riêng.
- Kho `apt` cho Linux (hiện tải `.deb` về cài / Agent tự cài qua pkexec).
