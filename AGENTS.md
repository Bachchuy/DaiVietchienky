# Project Guidelines: Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`)

**Stack:** Godot 4.7 | Typed GDScript 2.0 | `gl_compatibility` | Web (HTML5/Wasm) + Android | 60 FPS

## Bảng Định Tuyến Nhanh (0 Tool-Call)
| Miền | Thư mục / File chính | Spec Code GDD (`docs/gdd/...`) | `--suite=` |
|---|---|---|---|
| `data` | `data/defs/` *(R2)*, `data/stages/` *(R2)*, `data/settings/`, `sim/state/static_data_loader.gd`, `scenario_loader.gd` | `architecture/data_and_save_system.md` | `map_state,tran_campaign` |
| `hex` | `sim/rules/hex_math.gd`, `hex_grid_navigator.gd`, `sim/state/battle_map_state.gd` | `mechanics/hex_grid_pathfinding.md` | `hex,map_state` |
| `combat` | `sim/rules/combat_resolver.gd`, `morale_engine.gd`, `seeded_rng.gd`, `sim/state/battle_unit.gd` | `mechanics/combat_formulas.md`, `morale_and_status.md` | `combat,morale` |
| `loop` | `sim/state/battle_game_controller.gd`, `battle_context.gd`, `sim/commands/` | `architecture/data_and_save_system.md` | `commands,controller,session` |
| `ai` | `sim/ai/`, `sim/state/ai_visible_map_view.gd`, `scenario_director.gd` | `ai/ai_decision_matrix.md` | `ai,slice01` |
| `scenario` | `sim/rules/scenario_event_manager.gd`, `scenario_victory_evaluator.gd`, `data/battles/` | `level_design/scenario_scripting_and_events.md` | `scenario,slice01` |
| `economy` | `sim/rules/battle_economy.gd`, `sim/commands/battle_economy_commands.gd` | `mechanics/battlefield_economy.md` | `economy` |
| `fsm` | `game/battle/battle_session.gd`, `battle_input_fsm.gd`, `battle_input_rules.gd` | `ui_ux/battle_ui_and_rendering.md` | `fsm,session` |
| `hud` | `ui/common/` (`theme.tres`, `modal_frame.*`), `ui/battle_hud/` | `ui_ux/battle_ui_and_rendering.md` | `hud,smoke` |
| `map/fx` | `game/battle/map/` *(R3)*, `game/battle/units/` *(R3)*, `scripts/presentation/` *(vỏ cũ xóa R3)* | `vfx_sfx/vfx_sfx_and_polish.md` | `camera,juice,map_view` |
| `save/meta` | `sim/state/battle_save_manager.gd`, `scenes/main_menu.tscn`, `scripts/presentation/campaign_menu_controller.gd` | `architecture/data_and_save_system.md` | `juice,tran_campaign` |
| `export` | `export_presets.cfg`, `sim/rules/asset_ip_auditor.gd`, `ASSETS.md` | *(không cần GDD)* | `release_export,tran_campaign` |

## Kiến Trúc & Cấm Cứng
1. **4 tầng (`≤ 400` dòng/script):** `Data (.tres)` → `Sim (RefCounted, không Node, SeededRng tách VFX)` → `BattleSession (Node giữ Sim, signal)` → `Presentation (.tscn)`. Phụ thuộc có kiểu qua `@export`; cấm `get_node("/root/...")`; Autoload chỉ dịch vụ toàn cục (không state trận); phân biệt hoa/thường `res://`.
2. **Editor-First & UI dùng được:** Scene dựng bằng `.tscn` + `TileMapLayer` + `@tool` + `.tres` + `theme.tres` (JSON chỉ cho `user://` save & replay). Modal: `PanelContainer > MarginContainer > VBoxContainer`, nội dung dài trong `ScrollContainer`, nút chính ngoài vùng cuộn, hỗ trợ `Enter`/`Esc`, cấm size cứng kèm `clip_contents`, dùng GUI Godot (không tự hit-test `_input`).
3. **Cấm thiết kế (`DEC-022`, `DEC-026`):**
   - **Cổng dừng Asset (`R4`):** Cấm tuyệt đối tự vẽ hay sinh asset đồ họa mới — bắt buộc dừng hỏi người dùng chọn phương án & công cụ.
   - **Không biết trước sát thương:** Cấm `CombatPreviewBox` & `AimingTarget`; chỉ dùng `UnitInspector` thô + đánh ngay 1 chạm.
4. **Đọc Spec & Skill có chọn lọc (Chống đốt quota):**
   - Chỉ đọc đúng Spec Code GDD thuộc miền ở bảng trên; **bỏ qua hoàn toàn** `docs/gdd/00..04/`, `appendices/`, `docs/gdd/README.md`, `docs/assets/ASSET_CATALOG.md`, và **cấm đọc/grep/auto-build** `docs/TONG_HOP_KE_HOACH_THIET_KE_GDD_3_4.md` (443 KB).
   - Skill Godot: tận dụng `GodotPrompter` khi gặp hệ thống chưa quen + tra [templates.md](.agents/skills/project-architecture/references/templates.md) cho mẫu Godot 4.7; chỉ đọc `D:\code\HexCrown` khi task yêu cầu trực tiếp (như `R3`).
   - **Không mặc định chụp hay mở ảnh PNG** trừ khi người dùng yêu cầu rõ ràng.

## Quy Trình Thực Thi Gọn (`Scope Lock` + Thang Test 3 Bậc)
1. **Gọi việc ngắn:** `Làm <Mã Task>` (vd `Làm R2-T1`) hoặc `Fix <miền>: <mô tả>`.
2. **Đọc tối thiểu (`≤ 3–5` file):** Nhảy thẳng vào thẻ `[Đọc]` của task ở `TASKS.md` hoặc đúng hàng bảng định tuyến; đọc đúng hàm/đoạn dòng cần sửa.
3. **Khóa phạm vi (`Scope Lock`):** Tự làm thẳng trong `[Sửa]` / miền được giao; **dừng hỏi** nếu buộc sửa ngoài Scope, đổi kiến trúc hoặc tạo asset (`R4`). Cấm "tiện tay" refactor file khác (lỗi ngoài miền chỉ ghi chú 1 dòng cuối câu trả lời). Trước khi báo xong, đối chiếu danh sách file đã sửa để chắc chắn 0 file lọt Scope.
4. **Thang kiểm thử 3 bậc:**
   - **Bậc 1 (Sửa cục bộ / Fix nhỏ):** `.\godot.cmd --headless --script res://tests/run_tests.gd -- --suite=<miền>`
   - **Bậc 2 (Chốt Task lộ trình):** `.\godot.cmd --headless --script res://tests/run_tests.gd` (UI dùng `assert_button_reachable()` + `push_click_control()`)
   - **Bậc 3 (Chốt Cổng / Sửa lớn `sim/`):** Thêm `--stress` + checklist `F5` (2–3 bước) cho người dùng tự kiểm tra.
5. **Tối giản `.md`:** Fix nhỏ → **không sửa file `.md` nào**; xong 1 Task → chỉ tick `[x]` 1 dòng ở `TASKS.md` + cập nhật `.ai/HANDOFF.md` (`≤ 15` dòng, `READY_FOR_CODEX_REVIEW`); chỉ cập nhật `STATE.md`/`DECISIONS.md` khi chốt cả 1 Cổng hoặc có quyết định thiết kế lớn.
