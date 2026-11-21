# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** **GDD v3.5 (Editor-First 4-Tier Architecture)** (`docs/gdd/`), quy chuẩn [AGENTS.md](AGENTS.md), kỹ năng `.agents/skills/project-architecture/SKILL.md`.
- **Cổng hiện tại:** **CỔNG `R2` (`1/3`) — ĐANG THỰC HIỆN (`R2-T1` xong, chờ Codex Review trước `R2-T2`)** (Đã commit Cổng `R1` `4/4` tại `8024d89`; đã hoàn tất `R2-T1` với 6 lớp Custom `Resource` có `@export` trong `res://data/defs/`).
- **Nhiệm vụ kế tiếp:** **`R2-T2`** (Định nghĩa `StageDef` và các Sub-Resource kịch bản/màn chơi trong `res://data/defs/`).
- **Tiến độ lộ trình Tái kiến trúc (`R1–R5`):** `5 / 15` nhiệm vụ (R1: `4/4`, R2: `1/3`, R3: `0/4`, R4: `0/2` 🛑 Cổng dừng hỏi người dùng, R5: `0/2`).
- **Trạng thái Giai đoạn 1 (`CP1–CP5` cũ):** **Lõi Sim Đạt / Vỏ UI-Data-Đồ họa & CombatPreview Cũ Bị Bác Bỏ (`DEC-025`)** — Đã chuyển xong lõi sang `res://sim/` (`R1-T1`) và thay xong toàn bộ HUD sang `.tscn` + `theme.tres` (`R1-T2`, `R1-T3`); dữ liệu tĩnh JSON (`data/settings/*.json`) và bản đồ `_draw()` (`battle_map_view.gd`) sẽ tiếp tục thay thế ở `R2–R3`.

---

## Tóm tắt Quyết định & Kiểm toán Tái kiến trúc (21/11/2026)
- **`DEC-021` (Vertical Slice First):** Làm chuẩn chỉnh màn `10101` Bạch Đằng 1288 đạt/vượt chất lượng `HexCrown` (`R1–R4`) rồi mới nhân rộng ra `10102–10106` (`R5`).
- **`DEC-022` (Đồ họa & Cổng Dừng Bắt Buộc `R4`):** Kế thừa asset sạch từ `D:\code\HexCrown\assets` ở `R3`; **BẮT BUỘC DỪNG HỎI NGƯỜI DÙNG** ở `R4` trước khi tạo asset mới (Chiến thuyền, Bãi cọc, 2 mẫu so sánh `Pixel Art` vs `2D Cách điệu kiểu EasyTech`).
- **`DEC-023` (Dữ liệu `.tres` + `@tool` Scene):** Chuyển toàn bộ dữ liệu tĩnh sang Custom `Resource` (`.tres`) chỉnh trong Inspector; bản đồ địa hình/đặt quân dựng bằng `TileMapLayer` + `@tool` trong `stage_<id>_map.tscn`; JSON chỉ dùng cho `user://saves/` và Replay.
- **`DEC-024` (Kiến trúc 4 Tầng `<= 400 dòng/script`):** `data/` -> `sim/` (`RefCounted`) -> `BattleSession` (`Node` giữ state, phát `signal`) -> `game/battle/` & `ui/` (`.tscn` + `theme.tres`); xóa bỏ `battle_hud_controller.gd` (1.556 dòng), `battle_map_view.gd` (880 dòng), `battle_sandbox_cp1.gd` (806 dòng).
- **`DEC-026` (Bỏ Triết lý Biết Trước):** Xóa hoàn toàn `CombatPreviewBox` và `AimingTarget`; thay bằng `UnitInspector` chỉ hiển thị thông số thô của từng đạo quân và cơ chế **đánh ngay 1 chạm** như `HexCrown` (người chơi tự tính, hệ thống tung `Seeded RNG` khi va chạm).
- **`DEC-027` (Tinh gọn Kiểm thử & Quy trình):** Xóa `tests/e2e/` (6.267 dòng), các script/ảnh chụp cũ và skill 3D thừa; thay bằng `test_battle_smoke_e2e.gd` + `--suite`/`--stress` trong `run_tests.gd` (chạy fast suite < 10s) và bỏ quy trình AI chụp/đọc ảnh mặc định.

---

## Bị kẹt / Giới hạn & Cổng Dừng Bắt Buộc
1. **🛑 Cổng Dừng Bắt Buộc `R4` (Chờ quyết định người dùng khi đến Cổng 4):** Tuyệt đối không tự ý vẽ hay sinh asset mới ở `R4`; phải dừng lại hỏi người dùng lên phương án và chọn công cụ cho 2 mẫu so sánh (`Pixel Art` vs `2D Cách điệu EasyTech`) và Chiến thuyền/Bãi cọc Bạch Đằng.
2. **Giới hạn công cụ Export Binary cục bộ (giữ nguyên từ `C5-T3`):** Máy Windows hiện tại chưa cài gói Godot 4.7.2 Export Templates (`.tpz`) tại `%APPDATA%\Godot\export_templates\4.7.2.stable\` và chưa cấu hình `ANDROID_HOME`. Cấu hình `export_presets.cfg` vẫn được giữ và kiểm tra lại ở `R5-T2`.
