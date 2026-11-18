# Trang thử in qua Trạm in

Trang nội bộ để thử in qua các Trạm in (Agent) trên điện thoại, máy POS và máy
tính của một cửa hàng.

- `index.html` — chọn một Trạm in đang bật trong cửa hàng rồi in thử.
- `lan.html` — thử in trực tiếp qua mạng quán.

Chạy thử trên máy: `python3 -m http.server 8080 --directory docs`.

Kiểm tra: `node --test docs/test/*.test.js`. Triển khai tự động bằng
`.github/workflows/pages.yml`.

Trang tải bộ cài cho khách: `download.html` (nút Windows / Linux trỏ tới bản phát hành mới nhất trên GitHub).
