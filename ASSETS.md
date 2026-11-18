# Sổ Tay Tài Nguyên & Thư Viện Sạch (`ASSETS.md`)

Mọi tệp đồ họa, âm thanh, shader hoặc thư viện dùng trong dự án **bắt buộc** phải ghi nhận tại đây trước khi nạp vào mã nguồn. Tuyệt đối không nạp bất kỳ tệp nào trong thư mục `Assets/` cũ (đã chặn bằng `.gitignore` và `Assets/.gdignore`).

---

## 1. Thư viện ngoài (External Libraries / Addons)

| Tên thư viện | Phiên bản | Nguồn / Giấy phép | Trạng thái | Mục đích |
|---|---|---|---|---|
| *(Không dùng thư viện ngoài)* | — | Thuần Godot 4.7 Standard API + GDScript 2.0 | Đang áp dụng | Toàn bộ mô phỏng, hiển thị, camera và bộ chạy test `tests/run_tests.gd` tự viết 100% không phụ thuộc addon. |

---

## 2. Tài nguyên Đồ họa, Shader & Dữ liệu Sạch (`res://`)

| Đường dẫn `res://` | Loại | Nguồn gốc / Phương thức tạo | Bản quyền | Mục đích sử dụng |
|---|---|---|---|---|
| `res://icon.svg` | Vector SVG | Khởi tạo mặc định từ Godot Engine 4.7 | MIT / Public Domain | Biểu tượng ứng dụng mặc định trong `project.godot`. |
| `res://data/settings/troop_settings.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Cấu hình binh chủng chuẩn cho Cổng 1 (`CP1`) và các cổng kế tiếp. |
