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
| `res://data/settings/stage_settings.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Danh mục màn chơi chiến dịch (`stage_id: 10101` Bạch Đằng 1288). |
| `res://data/settings/tactic_settings.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Cấu hình kỹ năng / mưu lược (`10001` Hịch Tướng Sĩ). |
| `res://data/battles/battle_10101.json` | JSON tĩnh | Biên soạn mới 100% từ thông số GDD v3.4.1 | Độc quyền dự án (100% sạch) | Dữ liệu bản đồ, quân số & sự kiện kịch bản Slice-01 Đại Chiến Bạch Đằng 1288. |
| `res://assets_clean/shaders/hit_flash.gdshader` | Godot Shader (`canvas_item`) | Tự biên soạn mới 100% (`gl_compatibility` safe) | Độc quyền dự án (100% sạch) | Hiệu ứng chớp trắng 50ms khi trúng đòn (tự gỡ material về `null` bảo toàn 2D batching). |
| `res://assets_clean/shaders/water_flow.gdshader` | Godot Shader (`canvas_item`) | Tự biên soạn mới 100% (`gl_compatibility` safe) | Độc quyền dự án (100% sạch) | Hiệu ứng gợn sóng dòng chảy trên lớp `WaterAndTideLayer` (`z=4`). |
| `res://assets_clean/audio/sfx_sword_hit.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh va chạm binh khí cận chiến (`sword_hit`). |
| `res://assets_clean/audio/sfx_arrow_shot.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh bật dây cung/nỏ tầm xa (`arrow_shot`). |
| `res://assets_clean/audio/sfx_horn_charge.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Tiếng tù và / cồng chiêng phát lệnh xung phong & Mưu lược (`horn_charge`). |
| `res://assets_clean/audio/sfx_water_splash.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh sóng vỗ / chiến thuyền va cọc ngầm (`water_splash`). |
| `res://assets_clean/audio/sfx_fire_ignite.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh hỏa công bùng cháy trên sông (`fire_ignite`). |
| `res://assets_clean/audio/sfx_ui_click.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp toán học sóng âm sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Âm thanh chạm nút giao diện (`ui_click`). |
| `res://assets_clean/audio/bgm_bach_dang_ambient.wav` | Audio PCM 16-bit WAV (22050 Hz) | Tổng hợp âm giai ngũ cung sạch 100% (Python `wave`/`math`) | Độc quyền dự án (100% sạch) | Nhạc nền hào khí sông Bạch Đằng (`bgm_bach_dang`). |
