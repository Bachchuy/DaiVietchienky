# Project Guidelines: VietNamHistoryStrategy (Đại Việt Chiến Kỳ)

## Tech Stack & Target
- **Engine**: Godot 4.7
- **Primary Language**: GDScript (Typed GDScript 2.0)
- **Renderer**: GL Compatibility (`gl_compatibility`)
- **Target Platforms**: Web (HTML5/Wasm) + Android (phát triển & kiểm thử trên Windows Desktop)
- **Target Performance**: 60 FPS

## Development Rules
1. **Skill Loading**: Chỉ đọc `SKILL.md` khi bắt đầu làm một hệ thống Godot mới hoặc chưa quen thuộc; không đọc lại cùng một skill ở mọi prompt.
2. **GDD Reference**: Toàn bộ GDD v3.5 được chia nhỏ dạng cây tại `docs/gdd/README.md`. Chỉ đọc đúng file module cần dùng. **Cấm đọc/grep tệp hợp nhất 443 KB `docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md`**, và không tự động chạy `docs/build_master_gdd.py` trừ khi người dùng yêu cầu xuất bản tổng hợp.
3. **Deterministic & Platform Safety**:
   - Mọi logic mô phỏng chiến đấu/AI sử dụng `RandomNumberGenerator` có `seed` tách biệt với hiệu ứng hình ảnh để bảo toàn Replay tất định.
   - Chú ý phân biệt chữ hoa/thường trong đường dẫn `res://` (`res://Assets/...`, `res://data/...`, `res://scripts/...`) để không lỗi khi đóng gói `.pck` trên Web và Android.
4. **Verification & Evidence (Nhanh & Tối ưu Quota)**:
   - Trong lúc làm việc, chạy lọc suite liên quan để phản hồi nhanh: `.\godot.cmd --headless --script res://tests/run_tests.gd -- --suite=<tên>`.
   - Trước khi báo xong, chạy full fast suite: `.\godot.cmd --headless --script res://tests/run_tests.gd`. Chỉ thêm `--stress` (100 trận AI) khi sửa lớn tầng `sim/` hoặc chốt Cổng cuối.
   - **Không mặc định chụp hay mở đọc ảnh PNG** (tránh tốn vision quota & vòng gọi tool); người dùng sẽ tự bấm `F5` kiểm tra trực quan. Chỉ chụp ảnh khi người dùng yêu cầu rõ ràng.
   - Tuyệt đối không báo "xong" nếu chưa chạy test thực tế đạt 100%.
5. **Kiến trúc** (chỉ mở skill `project-architecture` khi cần tra mẫu/sơ đồ thư mục):
   - 4 tầng: Data (`.tres`) → Sim (`RefCounted` thuần, không Node) → `BattleSession` (Node duy nhất giữ Sim, phát signal) → Presentation (`.tscn`). Presentation chỉ đọc state qua signal và gửi Command; không sửa state trực tiếp.
   - Autoload chỉ cho dịch vụ toàn cục (Settings, Save, Audio, SceneRouter); không chứa state trận đấu.
   - Truyền phụ thuộc có kiểu qua `@export`; cấm service locator với biến `Node` không kiểu và `get_node("/root/...")`.
   - Mỗi script ≤ 400 dòng; vượt thì tách component/scene con.
6. **Editor-First**:
   - Scene (bản đồ, đơn vị, HUD, modal) dựng bằng node trong `.tscn`, nhìn thấy trong view 2D của editor; không dựng toàn bộ cây node bằng `Node.new()`. Bản đồ dùng `TileMapLayer`; phần sinh theo dữ liệu dùng `@tool` để preview trong editor.
   - Data thiết kế dùng custom `Resource` (`@export`, lưu `.tres`), chỉnh được trong Inspector. JSON chỉ cho save `user://` hoặc trao đổi ngoài. Style UI đặt trong `theme.tres`.
   - Nếu GDD/spec đi ngược nguyên tắc này: báo người dùng và đề xuất sửa GDD trước khi code, không âm thầm làm theo.
   - Mẫu tham chiếu: `D:\code\HexCrown` (`data/units/*.tres`, `scenes/base_unit.tscn`, `scenes/ui/gameplay_ui.tscn`) — chỉ đọc khi nhiệm vụ yêu cầu đối chiếu/kế thừa trực tiếp (như `R3`).
7. **UI phải dùng được**:
   - Modal: `PanelContainer > MarginContainer > VBoxContainer`, nội dung dài trong `ScrollContainer`; không hard-code size kèm `clip_contents`.
   - Nút chính (Bắt đầu / Tiếp tục / Bỏ qua / Đóng) luôn ở chân modal, ngoài vùng cuộn, luôn nhìn thấy. Mọi màn chặn người chơi phải có lối thoát (nút + Enter/Esc).
   - Không tự viết lại hit-test nút trong `_input`; dùng hệ GUI của Godot.
8. **Kiểm chứng UI tự động & Hướng dẫn người dùng F5**:
   - Test UI khẳng định nút *bấm được* bằng assertion hình học (`assert_button_reachable()`: rect nằm trọn trong mọi tổ tiên `clip_contents` và viewport) kết hợp click thật qua `Viewport.push_input` — không phụ thuộc chụp ảnh.
   - Với thay đổi có giao diện/luồng chơi, cung cấp cho người dùng checklist `F5` ngắn gọn (2–3 bước) để tự kiểm tra thẩm mỹ trong Editor/Game.
   - Trước khi chốt một Cổng, kiểm tra bằng Editor/checklist để xác nhận View 2D, Inspector và luồng từ `main_menu.tscn` không lỗi.
9. **Cổng Thiết kế Asset & Bỏ Triết lý Biết Trước (`DEC-022`, `DEC-026`)**:
   - **Cấm tuyệt đối tự ý vẽ hay sinh asset đồ họa mới:** Khi đến bất kỳ nhiệm vụ nào cần thiết kế/tạo asset mới (Chiến thuyền, Bãi cọc Bạch Đằng, Tileset mới, hoặc dựng 2 mẫu so sánh `Pixel Art` vs `2D Cách điệu kiểu EasyTech` ở Cổng `R4`), agent **BẮT BUỘC dừng lại hỏi người dùng** để người dùng lên phương án và chọn công cụ thiết kế.
   - **Không biết trước sát thương (`DEC-026`):** Cấm hiển thị `CombatPreviewBox` tính hộ dải sát thương dự kiến hay xác nhận đánh 2 bước `AimingTarget`; chỉ dùng `UnitInspector` (`res://ui/battle_hud/unit_inspector.tscn`) hiển thị thông số thô của đạo quân để người chơi tự tính toán, và chạm 1 lần vào địch trong tầm đỏ là tấn công ngay như `HexCrown` (hệ thống tự tính + quay `Seeded RNG` khi va chạm).
10. **Đọc Tối Thiểu & Khóa Phạm Vi Sửa File (`Scope Lock`)**:
   - **Đọc tối thiểu:** Khởi đầu tác vụ chỉ đọc đúng các file cần sửa và interface/test liên quan trực tiếp (ưu tiên tìm đúng hàm/đoạn dòng thay vì đọc trọn file lớn). Không đọc lan sang `DECISIONS.md`, `docs/gdd/README.md` (19 KB), `.ai/HANDOFF.md` hay `D:\code\HexCrown` nếu prompt đã nêu rõ yêu cầu.
   - **Khóa phạm vi sửa file (`Scope Lock`):** Chỉ sửa đúng các file thuộc nhiệm vụ được giao. Cấm "tiện tay" refactor, format lại hoặc sửa bug phụ ở file ngoài phạm vi; nếu phát hiện vấn đề ở file khác, chỉ ghi chú 1 dòng cuối câu trả lời để người dùng quyết định.
   - **Giảm chạm file hành chính:** Chỉ cập nhật `STATE.md`/`TASKS.md` khi hoàn tất một Task/Cổng trong lộ trình; chỉ thêm mục vào `DECISIONS.md` khi có quyết định kiến trúc/thiết kế mới thật sự quan trọng; giữ `.ai/HANDOFF.md` ngắn gọn (`≤ 25` dòng) khi bàn giao task/feature.