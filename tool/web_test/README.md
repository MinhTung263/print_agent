# Trang thử in web qua Trạm in

Trang một file, không cần cài gì thêm. Chạy trên máy tính cùng Wi-Fi với thiết bị
bật Trạm in:

```
python3 -m http.server 8080 --directory tool/web_test
```

Mở `http://localhost:8080`, nhập IP thiết bị (VD máy T4s), bấm *Kiểm tra kết nối*
rồi *In thử*. Bản debug của app EasyPOS nhận trang `http://` trong mạng nội bộ;
bản thật chỉ nhận `https://*.easypos.vn`.
