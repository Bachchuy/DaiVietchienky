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
5. **Kiến trúc** (bắt buộc đọc skill `project-architecture` trước khi tạo file/scene/data/hệ thống mới hoặc refactor):
   - 4 tầng: Data (`.tres`) → Sim (`RefCounted` thuần, không Node) → `BattleSession` (Node duy nhất giữ Sim, phát signal) → Presentation (`.tscn`). Presentation chỉ đọc state qua signal và gửi Command; không sửa state trực tiếp.
   - Autoload chỉ cho dịch vụ toàn cục (Settings, Save, Audio, SceneRouter); không chứa state trận đấu.
   - Truyền phụ thuộc có kiểu qua `@export`; cấm service locator với biến `Node` không kiểu và `get_node("/root/...")`.
   - Mỗi script ≤ 400 dòng; vượt thì tách component/scene con.
6. **Editor-First**:
   - Scene (bản đồ, đơn vị, HUD, modal) dựng bằng node trong `.tscn`, nhìn thấy trong view 2D của editor; không dựng toàn bộ cây node bằng `Node.new()`. Bản đồ dùng `TileMapLayer`; phần sinh theo dữ liệu dùng `@tool` để preview trong editor.
   - Data thiết kế dùng custom `Resource` (`@export`, lưu `.tres`), chỉnh được trong Inspector. JSON chỉ cho save `user://` hoặc trao đổi ngoài. Style UI đặt trong `theme.tres`.
   - Nếu GDD/spec đi ngược nguyên tắc này: báo người dùng và đề xuất sửa GDD trước khi code, không âm thầm làm theo.
   - Mẫu tham chiếu: `D:\code\HexCrown` (`data/units/*.tres`, `scenes/base_unit.tscn`, `scenes/ui/gameplay_ui.tscn`).
7. **UI phải dùng được**:
   - Modal: `PanelContainer > MarginContainer > VBoxContainer`, nội dung dài trong `ScrollContainer`; không hard-code size kèm `clip_contents`.
   - Nút chính (Bắt đầu / Tiếp tục / Bỏ qua / Đóng) luôn ở chân modal, ngoài vùng cuộn, luôn nhìn thấy. Mọi màn chặn người chơi phải có lối thoát (nút + Enter/Esc).
   - Không tự viết lại hit-test nút trong `_input`; dùng hệ GUI của Godot.
8. **Kiểm chứng như người chơi** (bổ sung mục 4):
   - Test UI phải khẳng định nút *bấm được*: rect nằm trọn trong mọi tổ tiên `clip_contents` và viewport, click qua `Viewport.push_input` thật — không chỉ kiểm node tồn tại.
   - Phải mở xem từng screenshot với câu hỏi: "Người chơi có thấy nút đi tiếp không? Chữ có bị cắt/tràn không?". Thấy lỗi thì sửa hoặc báo CHƯA XONG.
   - Trước khi báo xong một cổng: mở editor kiểm tra view 2D và Inspector có nội dung, và chạy F5 từ `main_menu.tscn` qua hết luồng mở đầu.