# Trang thử in qua Trạm in

Trang web để thử in qua các Trạm in (Agent) trên mọi nền tảng — điện thoại, máy
POS, máy tính — **không cần IP, không cần cùng Wi-Fi**:

- `index.html` — đi qua kênh MQTT của cửa hàng (cùng kênh app EasyPOS dùng). Nhập
  môi trường + mã công ty + mã chủ (hoặc để trang tự nhận từ Trạm in desktop chạy
  trên chính máy này), chọn một Trạm in đang bật rồi in thử.
- `lan.html` — gọi thẳng cổng web của một thiết bị theo IP (cùng mạng quán).
- `relay.js` — giao thức hàng đợi cho trình duyệt (giống `MqttPrintRelayTransport`);
  `test/relay.test.js` kiểm tra khớp với bản Dart: `node --test docs/test/relay.test.js`.

## Địa chỉ

Sau khi bật GitHub Pages (Settings → Pages → Source: *GitHub Actions*), workflow
`.github/workflows/pages.yml` đưa thư mục `docs/` lên:
`https://minhtung263.github.io/print_agent/`

Chạy thử trên máy: `python3 -m http.server 8080 --directory docs`.

## Tự nhận cửa hàng

Trang gọi `http://127.0.0.1:9102/v1/info` của Trạm in trên chính máy đó để lấy mã
cửa hàng (`shopKey`). Trạm in chỉ trả lời trang nằm trong danh sách cho phép: với
Agent desktop, thêm `https://minhtung263.github.io` vào cấu hình `webOrigins`;
bản debug của app EasyPOS tự nhận trang `http://localhost`. Không nhận được thì
nhập tay mã công ty + mã chủ.

## Đăng nhập

Trang có ô đăng nhập tài khoản EasyPOS (máy chủ thật): lấy danh sách công ty, chọn
công ty rồi tự nối kênh in. Mật khẩu chỉ dùng một lần, không lưu.

Máy chủ `api.easypos.vn` chỉ cho trang `https://*.easypos.vn` gọi (CORS), nên đăng
nhập chỉ chạy khi trang được đặt dưới tên miền easypos.vn, VD
`https://trainin.easypos.vn`: thêm bản ghi DNS `CNAME <tên> → minhtung263.github.io`
rồi đặt tên miền đó ở Settings → Pages (tạo file `docs/CNAME`). Ở địa chỉ
`github.io` ô đăng nhập báo lỗi và trang dùng cách nhập tay mã cửa hàng.

`login.js` có test: `node --test docs/test/login.test.js`.
