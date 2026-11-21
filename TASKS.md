# Danh Sách Nhiệm Vụ Theo Cổng Duyệt (`TASKS.md`)

Lộ trình nhiệm vụ tuân thủ **GDD v3.5** (`docs/gdd/04_production_roadmap/implementation_plan.md`) và quy chuẩn **Kiến trúc 4 Tầng Editor-First** (`.agents/skills/project-architecture/SKILL.md`).  
**Quy tắc:** Nhảy thẳng vào thẻ `Đọc / Sửa / Test` của task (`Scope Lock`), chạy test theo **thang 3 bậc** (`--suite=` khi sửa -> `run_tests.gd` khi chốt task -> `--stress` + checklist `F5` khi chốt Cổng), không mặc định chụp PNG. Khi xong 1 Task: chỉ tick `[x]` và cập nhật `.ai/HANDOFF.md` (`<= 15` dòng); chỉ cập nhật `STATE.md` khi chốt Cổng.

---

## GIAI ĐOẠN 1 (`CP1–CP5` CŨ): `[LÕI SIM ĐẠT / BÁC BỎ LỚP VỎ UI-DATA-ĐỒ HỌA & COMBAT PREVIEW CŨ]`

> [!WARNING] **Kết luận Kiểm toán & Chơi thử Thực tế (21/11/2026 — `DEC-021..DEC-026`):**
> - **Phần Đạt (Giữ lại & di chuyển sang `res://sim/`):** Toàn bộ lõi mô phỏng thuần (`HexMath`, `BattleMapState`, `HexGridNavigator`, `CombatResolver`, `MoraleEngine`, `BattleCommands`, `BattleEconomy`, `ScenarioEventManager`, `AIDecisionMatrix`, `BattleSaveManager`) và `82/82` unit tests.
> - **Phần Bị Bác Bỏ (Đập đi xây lại ở `R1–R5`):**
>   1. Scene `battle_sandbox_cp1.tscn` chỉ có 1 node, View 2D trong Editor trống hoàn toàn, bản đồ vẽ đa giác bệt bằng `_draw()`.
>   2. Dữ liệu tĩnh dùng JSON nên không chỉnh được trực tiếp trong Godot Inspector.
>   3. HUD sinh node bằng code trong `battle_hud_controller.gd` (1.556 dòng), nút `BẮT ĐẦU TRẬN ĐÁNH` và nút modal `Pause` bị cắt khuất bởi kích thước cứng + `clip_contents`, lọt kiểm thử do `_input()` tự hit-test giả.
>   4. Cơ chế `CombatPreviewBox` + xác nhận đánh 2 bước (`AimingTarget`) bị loại bỏ hoàn toàn theo `DEC-026`, thay bằng `UnitInspector` chỉ hiện thông số đạo quân và thao tác **đánh ngay 1 chạm** như `HexCrown`.

- [x] *(Lõi Sim Đạt — Vỏ Cũ Bác Bỏ)* **C1-T1..C1-T6 (`CP1`):** Hệ tọa độ Hex, A*/ZoC/LOS (giữ `Sim`; bỏ `BattleMapView._draw()` & `BattleSandboxCP1`).
- [x] *(Lõi Sim Đạt)* **C2-T1..C2-T4 (`CP2`):** Vòng lặp 7 pha, Command/Undo 5 điều kiện/Replay tất định, Combat `Seeded RNG`, Sĩ khí 4 bậc.
- [x] *(Lõi Sim Đạt — Dữ liệu JSON chuyển sang `.tres`)* **C3-T1..C3-T3 (`CP3`):** AI 3 pha tuân thủ Fog of War, `ScenarioEventManager` (`MapPhase_TideFall` Vòng 4).
- [x] *(Vỏ UI/Preview Cũ Bác Bỏ — Giữ Shader/Audio/Save)* **C4-T1..C4-T3 (`CP4`):** Giữ `CombatJuiceHelper`, `BattleAudioManager`, `BattleSaveManager`; bác bỏ `battle_hud_controller.gd` (1.556 dòng) và `CombatPreviewBox`.
- [x] *(Lõi Sim Đạt — Dữ liệu JSON chuyển sang `.tres`)* **C5-T1..C5-T3 (`CP5`):** Giữ `BattleEconomy`, `AssetIpAuditor`, `export_presets.cfg`; tái cấu trúc UI/Data/Map ở `R1–R5`.

---

## GIAI ĐOẠN 2 — LỘ TRÌNH TÁI KIẾN TRÚC EDITOR-FIRST & NÂNG CẤP ĐỒ HỌA (`R1–R5` / `CP6–CP10`)

### CỔNG `R1` (`CP6`): Cấu Trúc 4 Tầng (`sim/`, `data/`, `game/battle/`, `ui/`), FSM 7 Trạng Thái (Đánh Ngay 1 Chạm) & UI `.tscn` + `theme.tres`
- [x] **R1-T1:** Di chuyển sạch tầng Lõi (`scripts/core/`, `scripts/ai/`) sang `res://sim/` (`sim/state/`, `sim/commands/`, `sim/rules/`, `sim/ai/`), tạo `BattleSession` (`res://game/battle/battle_session.gd` giữ `BattleGameController` và phát `signal` có kiểu), rút gọn `BattleInputFSM` từ 8 xuống **7 trạng thái** (`IDLE`, `UNIT_SELECTED`, `MOVING`, `POST_MOVE_ACTION`, `ATTACKING`, `SKILL_TARGETING`, `EXECUTE_SKILL` — bỏ `AIMING_TARGET`, chạm 1 lần vào địch trong tầm đỏ là đánh ngay, chạm vào đơn vị ngoài tầm hoặc chuột phải chỉ mở thông số trên `UnitInspector`), tách gọn các script vượt 400 dòng (`BattleEconomyCommands`, `AIEvaluators`, `BattleInputRules`), giữ `85/85` unit tests xanh (`6816` assertions).
- [x] **R1-T2:** Tạo `res://ui/common/theme.tres` và `res://ui/common/modal_frame.tscn` (`PanelContainer > MarginContainer > VBoxContainer`, nội dung dài trong `ScrollContainer`, hàng nút hành động `ButtonRow` cố định ở chân ngoài vùng cuộn, hỗ trợ `Enter`/`Esc`, cấm kích thước cứng kèm `clip_contents`).
- [x] **R1-T3:** Dựng các scene HUD/Modal độc lập trong `res://ui/battle_hud/` (`top_bar.tscn`, `unit_inspector.tscn` chỉ hiện thông số đạo quân không tính trước sát thương, `command_dock.tscn`, `briefing_modal.tscn`, `dialogue_modal.tscn`, `pause_modal.tscn`, `result_summary_modal.tscn`), mỗi script `<= 400` dòng kết nối qua `@export var session: BattleSession`; **xóa bỏ hoàn toàn** `CombatPreviewBox`, `battle_hud_controller.gd` (1.556 dòng) và hàm `_input()` tự hit-test nút.
- [x] **R1-T4:** Tinh gọn bộ kiểm thử (`--suite`/`--stress` trong `run_tests.gd`, thay `tests/e2e/` 6.267 dòng bằng `tests/test_battle_smoke_e2e.gd` gọn nhẹ với `assert_button_reachable()`, `Viewport.push_input` thật, 1-tap attack & `UnitInspector`), xóa script chụp ảnh & PNG cũ (`DEC-027`). *(Hoàn tất Cổng `R1` — chờ người dùng F5 + Codex review)*

### CỔNG `R2` (`CP7`): Chuyển Đổi Dữ Liệu Tĩnh Sang Custom `Resource` (`.tres`) & Biên Tập Trong Inspector
- [x] **R2-T1:** Định nghĩa các lớp `Resource` có `@export` đầy đủ (`TroopDef`, `GeneralDef`, `TacticDef`, `FacilityDef`, `CodexEntryDef`, `DataRegistry`) trong `res://data/defs/`.
  - `Đọc:` `data/settings/*.json`, `.agents/skills/project-architecture/references/templates.md` *(mẫu Resource)* | `Sửa:` `data/defs/*.gd`, `tests/test_data_resources.gd` *(mới)* | `Test:` `--suite=data_resources` → fast suite
- [ ] **R2-T2:** Định nghĩa `StageDef` và các Sub-Resource (`ScenarioEventDef`, `DialogueLineDef`, `VictoryConditionDef`, `DefeatConditionDef`, `StarConditionDef`, `UnitPlacementDef`, `NamedAreaDef`) chỉnh được hoàn toàn trong Godot Inspector.
  - `Đọc:` `data/battles/battle_10101.json`, `sim/state/scenario_loader.gd` | `Sửa:` `data/defs/stage_def.gd` + sub-resource defs, `tests/test_data_resources.gd` | `Test:` `--suite=data_resources` → fast suite
- [ ] **R2-T3:** Viết công cụ chuyển đổi một lần & sinh toàn bộ tệp `.tres` trong `res://data/defs/`, `res://data/stages/10101_bach_dang/stage_10101.tres` và `res://data/registry.tres`; cập nhật tầng `sim/` đọc trực tiếp từ `Resource` (`DataRegistry` & `StageDef`), chạy unit test đối chiếu 100% thông số với JSON cũ rồi loại bỏ `res://data/settings/*.json`.
  - `Đọc:` `data/defs/*.gd`, `sim/state/static_data_loader.gd`, `sim/state/scenario_loader.gd` | `Sửa:` `data/defs/**/*.tres`, `data/stages/10101_bach_dang/stage_10101.tres`, `data/registry.tres`, `static_data_loader.gd`, `scenario_loader.gd`, xóa `data/settings/*.json` | `Test:` `--suite=data_resources,map_state,scenario,tran_campaign` → `--stress` *(Chốt Cổng R2)*

### CỔNG `R3` (`CP8`): Bản Đồ `TileMapLayer`, `UnitView.tscn` Ghép Component & Kế Thừa Bộ Asset Sạch Từ `HexCrown` Cho Màn `10101` Bạch Đằng
- [ ] **R3-T1:** Tích hợp bộ asset sạch từ `D:\code\HexCrown\assets` (`TileSet` lục giác, công trình Đỏ/Xanh, 12 sprite sheet lính `32×32`, shader `FactionTint` / `pulse_highlight` / `territory_border`, bộ SFX `.ogg/.mp3`) vào `res://assets_clean/hexcrown/` và đăng ký đầy đủ trong `ASSETS.md`.
  - `Đọc:` `ASSETS.md`, `D:\code\HexCrown\assets` | `Sửa:` `assets_clean/hexcrown/**`, `ASSETS.md` | `Test:` `--suite=tran_campaign`
- [ ] **R3-T2:** Dựng `res://game/battle/units/unit_view.tscn` theo kiến trúc Component của `HexCrown` (`Sprite2D` + `AnimationPlayer` + `UnitAnimatorComponent` + `HealthBarComponent` + `StatusBadgeComponent` + `FactionTint.gdshader`, mỗi script `<= 400` dòng).
  - `Đọc:` `D:\code\HexCrown\scenes\base_unit.tscn`, `sim/state/battle_unit.gd`, `game/battle/battle_session.gd` | `Sửa:` `game/battle/units/*`, `tests/test_unit_view.gd` *(mới)* | `Test:` `--suite=unit_view` → fast suite
- [ ] **R3-T3:** Dựng `res://game/battle/map/battle_map.tscn` và `res://data/stages/10101_bach_dang/stage_10101_map.tscn` dùng `TileMapLayer` + script `@tool` đồng bộ hai chiều với `stage_10101.tres` (vẽ địa hình trực tiếp trên `TileMapLayer` và kéo-thả điểm đặt quân trong View 2D của Editor).
  - `Đọc:` `data/stages/10101_bach_dang/stage_10101.tres`, `sim/rules/hex_math.gd`, `sim/state/battle_map_state.gd` | `Sửa:` `game/battle/map/*`, `data/stages/10101_bach_dang/stage_10101_map.tscn`, `tests/test_battle_map_view.gd` | `Test:` `--suite=map_view,hex` → fast suite
- [ ] **R3-T4:** Dựng `res://game/battle/battle.tscn` ghép `BattleSession`, `Camera2D`, `BattleMap`, `BattleHud`; xóa bỏ `battle_map_view.gd` (880 dòng) và `battle_sandbox_cp1.gd` (806 dòng); mở Editor kiểm tra View 2D + Inspector có nội dung và chơi thông suốt màn `10101` từ `main_menu.tscn` ở 60 FPS.
  - `Đọc:` `game/battle/battle_session.gd`, `ui/battle_hud/battle_hud.gd`, `scripts/presentation/battle_sandbox_cp1.gd` *(wiring)* | `Sửa:` `game/battle/battle.tscn`, `battle.gd`, nối `ui/battle_hud/`, xóa `battle_map_view.gd`, `battle_sandbox_cp1.gd`, `hud_sandbox_bridge.gd`, cập nhật test sandbox | `Test:` `--suite=smoke,hud,fsm` → `--stress` *(Chốt Cổng R3)* + checklist `F5`

### CỔNG `R4` (`CP9` — 🛑 CỔNG DỪNG BẮT BUỘC HỎI NGƯỜI DÙNG): So Sánh 2 Mẫu Mỹ Thuật (`Pixel Art` vs `2D Cách Điệu EasyTech`) & Thiết Kế Asset Chiến Thuyền / Bãi Cọc Bạch Đằng
- [ ] **R4-T1 (🛑 DỪNG HỎI NGƯỜI DÙNG):** Dừng lại hoàn toàn trước khi tạo/vẽ bất kỳ asset mới nào; báo cáo người dùng để người dùng lên phương án và chỉ định công cụ thiết kế.
  - `Đọc:` `docs/gdd/03_content_presentation/audio_visual_narrative.md` *(chỉ khi tới R4)* | `Sửa:` **KHÓA — dừng hỏi người dùng trước khi tạo file asset** | `Test:` Không tự chạy
- [ ] **R4-T2:** Theo phương án người dùng chọn, dựng **2 mẫu nhỏ trên cùng cảnh Bạch Đằng** (**Mẫu A: Pixel Art** đồng bộ `HexCrown` kèm Chiến thuyền & Bãi cọc `StakedWater` vs **Mẫu B: 2D Cách điệu lịch sử kiểu EasyTech** thiết kế riêng) để người dùng đối chiếu trực quan và chốt phong cách đồ họa chính thức (tiến tới thay thế dần asset của `HexCrown`).
  - `Đọc:` Theo phương án người dùng chọn ở `R4-T1` | `Sửa:` Theo chỉ định người dùng | `Test:` Người dùng kiểm tra `F5` + `--suite=tran_campaign`

### CỔNG `R5` (`CP10`): Nhân Rộng Chuẩn Editor-First & Phong Cách Đồ Họa Đã Chốt Sang 5 Màn Thời Trần Còn Lại (`10102–10106`)
- [ ] **R5-T1:** Dựng `stage_<id>_map.tscn` (`TileMapLayer`) và `stage_<id>.tres` (`StageDef`) chỉnh được trong Editor cho 5 màn `10102` (Bình Than), `10103` (Hàm Tử), `10104` (Chương Dương), `10105` (Vân Đồn — có kinh tế), `10106` (Nội Bàng).
  - `Đọc:` `data/battles/battle_10102..10106.json`, `data/stages/10101_bach_dang/` | `Sửa:` `data/stages/10102..10106/*`, `data/registry.tres` | `Test:` `--suite=tran_campaign,economy,scenario` → fast suite
- [ ] **R5-T2:** Nâng cấp `main_menu.tscn` & `codex_panel.tscn` theo `ui/common/theme.tres` mới, chạy toàn bộ Unit + Smoke (`run_tests.gd --stress`) + kiểm tra View 2D/Inspector + chạy F5 luồng mở đầu, và kiểm thử tối ưu xuất bản Web/Android 60 FPS.
  - `Đọc:` `ui/common/theme.tres`, `scenes/main_menu.tscn`, `scenes/ui/codex_panel.tscn`, `export_presets.cfg` | `Sửa:` `scenes/main_menu.tscn`, `scenes/ui/codex_panel.tscn`, `campaign_menu_controller.gd`, `codex_panel.gd`, `tutorial_overlay.gd` | `Test:` `run_tests.gd --stress` + checklist `F5` từ `main_menu.tscn`
