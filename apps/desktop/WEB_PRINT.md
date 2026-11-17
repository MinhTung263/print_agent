# In từ web EasyPOS qua Trạm in (không cần driver)

Thiết bị nào bật Trạm in (máy tính, Android, iOS) cũng có cổng web này (mở khi
Trạm in BẬT). Trang `https://app.easypos.vn` chạy trên **máy đó** gọi
`http://127.0.0.1:9102`; chạy trên **thiết bị khác trong mạng quán** thì gọi
`http://<IP thiết bị>:9102` (trùng cổng thì `19102`). Yêu cầu từ thiết bị khác
bắt buộc có `Origin` của trang EasyPOS. Thử nhanh: `docs/lan.html` (qua IP) và `docs/index.html` (qua cloud)
(xem `docs/README.md`). Trạm in in ảnh phiếu ra máy in đã chọn (LAN / USB) hoặc ra máy in LAN
trong quán. Máy tính không phải cài driver máy in.

```
Trình duyệt (app.easypos.vn) ──HTTP 127.0.0.1:9102──► Trạm in ──ESC/POS──► Máy in LAN / USB
```

Phiếu web đi chung hàng đợi với phiếu của app bán hàng:
- Gửi lại cùng `jobId` trong vòng 15 phút thì không in lần hai.
- Phiếu ra đúng thứ tự trên từng máy in.
- Máy in hết giấy hoặc mở nắp thì trạm in giữ phiếu, tự in khi máy in sẵn
  sàng lại.
- Phiếu có trong nhật ký của trạm in.

## API

### `GET /v1/info`

```json
{
  "app": "easypos-print-agent", "api": 1,
  "ready": true,            // đã đăng nhập cửa hàng
  "on": true,               // đang nhận lệnh in
  "companyId": 123, "companyName": "Quán A",
  "name": "Quầy thu ngân", "paper": "size80",
  "stationId": "44a9486bd7a0d1e9",   // mã Agent = `id` của trạm trên hàng đợi cloud (xem "Chọn đường in")
  "printers": [
    {"id": "builtin", "name": "Máy in của trạm in", "ready": true},
    {"id": "lan:192.168.1.50", "name": "Bếp"}
  ]
}
```

`printers` liệt kê:
- `builtin`: máy in đã chọn ở trạm in.
- Các máy in LAN trạm in đã in giúp. Phần này chỉ có khi bật "In hộ máy in LAN".

Trang web có thể gửi `printer: "lan:<ip>[:cổng]"` tới bất kỳ IP nào trong mạng
nội bộ (10.x, 172.16–31.x, 192.168.x).

### `POST /v1/print` (JSON)

| Trường | Bắt buộc | Ý nghĩa |
|---|---|---|
| `jobId` | ✔ | Mã lệnh, 1–80 ký tự `A-Z a-z 0-9 _ . : -`. Gửi lại cùng mã thì không in đúp. Nên đặt `<mã HĐ>-<lần in>`. |
| `image` | ✔ | Ảnh phiếu PNG hoặc JPEG, dạng base64 hoặc data URL. |
| `printer` | | `builtin` (mặc định) hoặc `lan:192.168.1.50`. |
| `paper` | | `size80` (576 điểm) hoặc `size58` (384 điểm). Mặc định là khổ đã chọn ở trạm in. |
| `copies` | | 1–10, mặc định 1. |
| `openDrawer` | | Mở két tiền. Chỉ dùng cho phiếu thanh toán tại quầy. |
| `beep` | | Kêu còi, dùng cho phiếu báo chế biến và huỷ món. |
| `companyId` | | Nếu có, trạm in đang đăng nhập cửa hàng khác thì từ chối. |
| `sender` | | Tên máy hoặc nhân viên, hiện trong nhật ký trạm in. |

Về ảnh: trạm in tự thu ảnh về đúng khổ giấy và tự đổi nền trong suốt thành trắng.
Nên chụp phiếu ở bề rộng 576px (80mm) hoặc 384px (58mm) để chữ sắc nét.

Kết quả luôn trả HTTP 200 kèm trường `status`:

| `status` | Trang web làm gì |
|---|---|
| `done` | Đã in. |
| `held` | Máy in hết giấy hoặc mở nắp. Trạm in **sẽ tự in**, trang web **không gửi lại**. |
| `failed` | Máy in tắt hoặc mất kết nối. Hiện `message` và cho bấm in lại. In lại cùng `jobId` vẫn an toàn. |
| `off` | Trạm in chưa đăng nhập hoặc đang tắt. |
| `noPrinter` | Trạm in chưa chọn máy in. |
| `wrongCompany` | Trạm in đang đăng nhập cửa hàng khác. |

Các mã lỗi khác:
- `400`: lệnh sai, xem `error` và `message`.
- `403 {"error":"origin"}`: trang web không được phép gọi.
- `413`: ảnh quá 16 MB.

## Mã mẫu phía web

```js
const AGENT_PORTS = [9102, 19102];
let agentBase = null;

async function findAgent() {
  for (const port of AGENT_PORTS) {
    const base = `http://127.0.0.1:${port}`;
    try {
      const r = await fetch(`${base}/v1/info`, {
        signal: AbortSignal.timeout(1500),
        targetAddressSpace: 'loopback', // Chrome 142+: Local Network Access
      });
      const info = await r.json();
      if (info.app === 'easypos-print-agent') { agentBase = base; return info; }
    } catch (_) {}
  }
  return null; // Chưa cài / chưa mở Trạm in → hướng dẫn tải bộ cài
}

// element: khối HTML của phiếu (bề rộng 576px với khổ 80mm).
async function printViaAgent(element, { jobId, printer = 'builtin', ...opts }) {
  const canvas = await html2canvas(element, { scale: 1, backgroundColor: '#fff' });
  const r = await fetch(`${agentBase}/v1/print`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    targetAddressSpace: 'loopback',
    body: JSON.stringify({ jobId, printer, image: canvas.toDataURL('image/png'), ...opts }),
  });
  return r.json(); // { status, message? }
}
```

## Chọn đường in để nhanh nhất

Có ba đường đưa phiếu từ trang web tới máy in. Số đo thật (phiếu hoá đơn 80mm, máy in LAN, mạng văn phòng;
"xong" = Agent đã đẩy dữ liệu sang máy in):

| Đường | Khi nào dùng | Tốc độ gửi → xong |
|---|---|---|
| **1. Cổng web của Agent cùng máy** `http://127.0.0.1:9102/v1/print` | Trình duyệt chạy **trên cùng máy** với Agent | **~0,2–0,4s** |
| 2. Hàng đợi cloud (MQTT, `broker.emqx.io`) | Agent ở **máy khác** / không có Agent cùng máy | ~1–2s, có lúc 4s |
| 3. TCP nội bộ `:9101` | Chỉ app bán hàng native (cần mã `lan` từ hàng đợi) — trình duyệt **không** gọi được | ~0,03–0,06s |

**Quy tắc cho trang web: đi đường 1 khi được, không được thì đi đường 2.**

1. Khi mở trang và mỗi ~20 giây: `GET http://127.0.0.1:9102/v1/info` (rồi `19102`). Thất bại / 403 → không có Agent
   cùng máy (hoặc Agent không cho trang này, xem `webOrigins`) → chỉ dùng đường 2.
2. Muốn in vào **trạm X** (người dùng đã chọn trạm trong danh sách trạm trên hàng đợi): nếu `info.stationId === X.id`
   và `info.ready && info.on` thì trạm X **chính là Agent cùng máy** → gọi `POST /v1/print` (đường 1).
   Agent bản cũ không báo `stationId` → coi như không phải máy này (đi đường 2).
3. `printer` gửi theo máy in đã chọn: `builtin` hoặc `lan:<địa chỉ>` (`<địa chỉ>` là IP máy in LAN, hoặc địa chỉ máy USB
   của Agent). Kết quả:
   - `done` / `held` / `failed`: **xong, dùng kết quả này** — KHÔNG gửi lại qua cloud (tránh in đúp; `failed` nghĩa là
     chưa in, cho người dùng bấm in lại).
   - `off` / `noPrinter` / `wrongCompany` / `error`, hoặc lỗi mạng / CORS / 403: **chuyển sang đường 2** với cùng nội dung.
4. Lệnh **in tem** (`kind: label`) hiện chưa có trên cổng web — luôn đi đường 2.
5. Gửi `jobId` ổn định cho mỗi phiếu (`<mã HĐ>-<lần in>`): Agent bỏ lệnh trùng trong 15 phút, nên an toàn khi bấm
   in lại.

Để đường 2 cũng nhanh: đăng ký nhận trạng thái **một lần** `status/+` khi nối kênh (không đăng ký từng lệnh), và gửi
phiếu dạng **PNG 1 bit** (đen trắng thật) — nhỏ hơn PNG màu 5–10 lần. Ví dụ đủ chạy: `docs/index.html` của repo
(hàm `printLocal`, `findLocalAgent`, `isLocalStation`, `monoPng1Base64`).

## Lưu ý trình duyệt
- **Chrome / Edge 142 trở lên** hỏi một lần: "app.easypos.vn muốn truy cập các
  thiết bị trên mạng cục bộ". Người dùng bấm **Cho phép**. Nếu lỡ chặn thì mở
  lại trong biểu tượng ổ khoá trên thanh địa chỉ → Quyền trang web.
- `http://127.0.0.1` được trình duyệt coi là địa chỉ an toàn, nên trang https
  gọi tới không bị chặn vì lẫn nội dung http (mixed content). Dùng `127.0.0.1`
  thay cho `localhost`.
- Cổng web chỉ mở trên chính máy đó. Máy khác trong quán (không cài Trạm in)
  không gọi được. Muốn in từ máy đó thì phải gửi lệnh qua Internet tới trạm in
  (chưa làm).

## Trang thử nghiệm / chạy trên máy dev
Mặc định trạm in chỉ nhận `https://easypos.vn` và tên miền con. Muốn thêm trang
khác, ghi khoá `webOrigins` trong file cấu hình của trạm in (`AgentStore`), các
địa chỉ cách nhau bằng dấu phẩy, ví dụ `"http://localhost:4200, https://staging.example"`.
