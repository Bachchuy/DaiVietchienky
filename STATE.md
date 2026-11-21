# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** **GDD v3.5 (Editor-First 4-Tier Architecture)** (`docs/gdd/`), quy chuẩn [AGENTS.md](AGENTS.md), kỹ năng `.agents/skills/project-architecture/SKILL.md`.
- **Cổng hiện tại:** **CỔNG `R3` (`4/4`) — HOÀN TẤT (chờ Codex Review & F5 kiểm tra trước 🛑 `R4-T1`)** (Đã dựng `res://game/battle/battle.tscn` + `battle.gd` (`396` dòng) + `battle_fx_bridge.gd` (`194` dòng) nối trọn vẹn `BattleSession`, `BattleMap`, `BattleCamera2D`, `BattleInputFSM`, `CombatJuiceHelper`, `BattleAudioManager`, `BattleHud`; cập nhật `main_menu.tscn` làm `run/main_scene` chuyển vào `battle.tscn`; xóa hoàn toàn `battle_map_view.gd`, `battle_sandbox_cp1.gd`, `battle_sandbox_cp1.tscn`, `hud_sandbox_bridge.gd`).
- **Nhiệm vụ kế tiếp:** **🛑 `R4-T1` (CỔNG DỪNG BẮT BUỘC HỎI NGƯỜI DÙNG — `DEC-022`):** Dừng lại hoàn toàn trước khi tạo/vẽ bất kỳ asset mới nào; báo cáo người dùng chọn phương án & công cụ cho 2 mẫu đối chiếu (`Pixel Art` vs `2D Cách điệu EasyTech`) và asset Chiến thuyền / Bãi cọc Bạch Đằng.
- **Tiến độ lộ trình Tái kiến trúc (`R1–R5`):** `11 / 15` nhiệm vụ (R1: `4/4`, R2: `3/3`, R3: `4/4`, R4: `0/2` 🛑 Cổng dừng hỏi người dùng, R5: `0/2`).
- **Trạng thái Giai đoạn 1 (`CP1–CP5` cũ):** **Hoàn Tất Tái Kiến Trúc Editor-First 4 Tầng (`R1–R3`)** — Toàn bộ `Sim`, `Data (.tres)`, `HUD (.tscn)`, `UnitView`, `TileMapLayer (Pointy-Top odd_r)`, và `battle.tscn` hoạt động thông suốt ở 60 FPS và không còn phụ thuộc `BattleMapView`/`BattleSandboxCP1` cũ.

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
