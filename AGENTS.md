# Project Guidelines: VietNamHistoryStrategy (Đại Việt Chiến Kỳ)

## Tech Stack & Target
- **Engine**: Godot 4.7
- **Primary Language**: GDScript (Typed GDScript 2.0)
- **Renderer**: GL Compatibility (`gl_compatibility`)
- **Target Platforms**: Web (HTML5/Wasm) + Android (phát triển & kiểm thử trên Windows Desktop)
- **Target Performance**: 60 FPS

## Development Rules
1. **Skill Loading**: Trước khi triển khai hoặc code bất kỳ hệ thống Godot nào, bắt buộc phải đọc `SKILL.md` của skill tương ứng khớp với hệ thống đó (ví dụ: `godot-shaders`, `camera-systems`, `game-feel` trong `.agents/skills/`, cùng các skill Godot 2D/UI/State Machine/GDScript/Testing/Web-Export có sẵn).
2. **GDD Reference**: Toàn bộ Game Design Document (GDD v3.4 — Bản Đồng Bộ Hóa) được chia nhỏ dạng cây tại `docs/gdd/README.md`. Khi cần quy tắc, chỉ số hoặc bối cảnh nào, chỉ đọc đúng file module tương ứng để tiết kiệm context window. Sau khi chỉnh sửa các file trong `docs/gdd/` hoặc `docs/assets/`, chạy `python docs/build_master_gdd.py` để cập nhật bản hợp nhất `docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md`.
3. **Deterministic & Platform Safety**:
   - Mọi logic mô phỏng chiến đấu/AI sử dụng `RandomNumberGenerator` có `seed` tách biệt với hiệu ứng hình ảnh để bảo toàn Replay tất định.
   - Chú ý phân biệt chữ hoa/thường trong đường dẫn `res://` (`res://Assets/...`, `res://data/...`, `res://scripts/...`) để không lỗi khi đóng gói `.pck` trên Web và Android.
4. **Verification & Evidence**: Sau khi sửa hoặc thêm code:
   - Phải chạy headless test để xác minh logic và biên dịch script/shader không có lỗi.
   - Chụp screenshot kiểm chứng (qua Godot MCP nếu đã bật trong `.agents/mcp_config.json`, hoặc qua headless/windowed test runner).
   - Tuyệt đối không báo "xong" hoặc hoàn thành nếu chưa có bằng chứng thực tế (test output/screenshot).
