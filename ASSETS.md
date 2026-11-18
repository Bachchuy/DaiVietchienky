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
| `res://assets_clean/icons/token_infantry.svg` | Vector SVG | Tự biên soạn mã SVG hình học sạch 100% | Độc quyền dự án (100% sạch) | Biểu tượng nhánh Bộ binh cho `UnitModelLayer` & `StrategicTokenLayer`. |
| `res://assets_clean/icons/token_archer.svg` | Vector SVG | Tự biên soạn mã SVG hình học sạch 100% | Độc quyền dự án (100% sạch) | Biểu tượng nhánh Cung/Nỏ cho `UnitModelLayer` & `StrategicTokenLayer`. |
| `res://assets_clean/icons/token_cavalry.svg` | Vector SVG | Tự biên soạn mã SVG hình học sạch 100% | Độc quyền dự án (100% sạch) | Biểu tượng nhánh Kỵ/Tượng binh cho `UnitModelLayer` & `StrategicTokenLayer`. |
| `res://assets_clean/icons/token_naval.svg` | Vector SVG | Tự biên soạn mã SVG hình học sạch 100% | Độc quyền dự án (100% sạch) | Biểu tượng nhánh Thủy quân chiến thuyền cho `UnitModelLayer` & `StrategicTokenLayer`. |
| `res://assets_clean/emblems/dai_viet_emblem.png` | Raster PNG `128×128` | Sinh mới bằng AI (`image-generator`) — họa tiết trống đồng Đông Sơn & rồng mây thời Trần trên nền sơn son | Độc quyền dự án (100% sạch) | Huy hiệu phe Đại Việt trên HUD & cờ chỉ huy. |
| `res://assets_clean/emblems/dai_nguyen_emblem.png` | Raster PNG `128×128` | Sinh mới bằng AI (`image-generator`) — khiên sắt & mũ trụ sừng thảo nguyên kết hợp sóng nước | Độc quyền dự án (100% sạch) | Huy hiệu phe Đại Nguyên trên HUD & cờ chỉ huy. |
