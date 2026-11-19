# Danh Sách Nhiệm Vụ Theo Cổng Duyệt (`TASKS.md`)

Lộ trình nhiệm vụ bám sát đặc tả **GDD v3.4.1** (`docs/gdd/04_production_roadmap/implementation_plan.md` — Checkpoints `CP1–CP5`).  
**Quy tắc:** Làm tuần tự từng nhiệm vụ trong Cổng hiện tại theo đúng vòng lặp TDD (`Viết test trước -> Viết code -> Chạy godot --headless --script tests/run_tests.gd -> Commit Git`). Khi hoàn tất toàn bộ nhiệm vụ của một Cổng, dừng lại và lập **BÁO CÁO CỔNG**.

---

## CỔNG 1 (`CP1`): Hệ Tọa Độ Hex, Định Tuyến A*/ZoC/LOS, 16 Lớp Kết Xuất & Camera 60 FPS

- [x] **C1-T1:** Triển khai `HexMath` (`scripts/core/hex_math.gd`) — hệ tọa độ `Pointy-topped Axial (q, r)` ↔ `Offset odd-r (col, row)`, `hex_distance`, 6 hướng `AXIAL_DIRECTIONS` (xét đối diện $180^\circ$), nội suy đường ngắm `hex_linedraw` (`LOS_NUDGE`) và quy đổi pixel `axial_to_world` ↔ `world_to_axial` (`tests/test_hex_math.gd`).
- [x] **C1-T2:** Triển khai mô hình lõi độc lập `SceneTree` (`scripts/core/unit_combat_state.gd`, `scripts/core/battle_unit.gd`, `scripts/core/battle_map_state.gd`, `scripts/core/static_data_loader.gd`) & cấu hình `data/settings/troop_settings.json` — 9 loại địa hình `TerrainType`, bảng MP nguyên `int` theo nhánh binh chủng, hệ số thủ địa hình, vùng thành `CoC`, kiểm tra bản đồ `12×10` & `30×30` (`tests/test_battle_map_state.gd`).
- [x] **C1-T3:** Triển khai bộ định tuyến chiến thuật `HexGridNavigator` (`scripts/core/hex_grid_navigator.gd`) — kiểm tra `has_line_of_sight` (cao điểm `HILLS`/`FORT` nhìn xuyên `FOREST`), `is_in_active_enemy_zoc`, `fond_terrain (-1 MP)`, phạt `CoC * 2`, ghìm chân `ZoC`, rút lui đầu lượt `Start-in-ZoC Withdrawal`, `ignore_zoc` / `ignore_coc` / `devoid_zoc`, tính tập ô di chuyển xanh `get_reachable_hexes`, đường đi A* `find_path` và vùng mục tiêu tầm bắn đỏ `get_attackable_hexes` (`tests/test_hex_navigator.gd`).
- [x] **C1-T4:** Tạo bộ huy hiệu đồ họa sạch 100% (`assets_clean/`, cập nhật `ASSETS.md`) và dựng `BattleMapView` (`scripts/presentation/battle_map_view.gd`) — đủ **16 lớp kết xuất chuẩn** (`GroundLayer z=0` .. `WorldSpaceUnitHudAndTextLayer z=55` + `ScreenHudCanvasLayer layer=10`), batch-draw địa hình, vùng đi xanh (`ReachableAreaLayer`), vùng bắn đỏ (`AttackableAreaLayer`), đường dẫn A* và chuyển đổi tự động `UnitModelLayer` ↔ `StrategicTokenLayer` (`tests/test_battle_map_view.gd`).
- [x] **C1-T5:** Triển khai `BattleCameraController` (`scripts/presentation/battle_camera_controller.gd`) — nội suy hàm mũ `1.0 - exp(-speed * delta)` độc lập FPS cho vị trí & zoom (`0.5x..1.2x`), kẹp biên bản đồ theo mức zoom, kéo pan chuột/cảm ứng, phát tín hiệu `strategic_lod_changed` tại ngưỡng `< 0.65`, và `Trauma Shake` dùng `_fx_rng` tách biệt hoàn toàn khỏi RNG mô phỏng (`tests/test_battle_camera.gd`).
- [x] **C1-T6:** Dựng Scene tương tác Sa bàn `CP1` (`scenes/battle/battle_sandbox_cp1.tscn`, `scripts/presentation/battle_sandbox_cp1.gd`, cấu hình `main_scene` trong `project.godot`) — hỗ trợ chọn đơn vị hiện vùng xanh/vùng đỏ/đường đi A* trên bản đồ Bạch Đằng `12×10`, phím chuyển nhanh chế độ Stress-Test `30×30` với `44+` đơn vị hoạt động đồng thời, kiểm chứng headless `<= 16.67 ms/frame` (60 FPS) và trích xuất ảnh chụp màn hình thực tế (`tests/test_cp1_integration_and_perf.gd`).

---

## CỔNG 2 (`CP2` / Gate `P1`): Vòng Lặp 7 Pha, Command/Undo/Replay, Combat Seeded RNG & Sĩ Khí 4 Bậc

- [x] **C2-T1:** Triển khai `SeededRng` & `CombatResolver` (`80%–100%` + Crit, giáp `100/(100+EffectiveDef)`, `RoundHalfUp`, `TroopStack` 1x–3x, `Flank`, phản kích tối đa 1 lần/lượt, dự báo `[Min, Max]` cho Combat Preview).
- [x] **C2-T2:** Triển khai `MoraleEngine` 4 bậc Enum (`HIGH`, `NORMAL`, `LOW`, `CHAOS`), bao vây `TrappedLevel`, lan truyền đồng đội tử trận & tự hồi `CHAOS -> LOW`.
- [x] **C2-T3:** Triển khai `BattleCommand` (`March`, `Attack`, `CastSkill`, `Wait`, `EndTurn`), luật Undo 1 lần/lượt cho `MarchCommand` (đủ 5 điều kiện an toàn) và bộ ghi/phát lại Replay tất định 100%.
- [x] **C2-T4:** Triển khai `BattleGameController` điều phối Vòng lặp Chiến trường 7 pha & kiểm thử phát lại 50 lượt không lệch 1 điểm HP.

---

## CỔNG 3 (`CP3`): Bộ Não AI 3 Pha & Kịch Bản Sự Kiện Bạch Đằng 1288 (`stage_id: 10101`)

- [x] **C3-T1:** Triển khai hệ thống AI 3 pha (`Generators -> Evaluators -> Utility Scoring`) tuân thủ Fog of War, hoàn tất tính toán `< 1.5s/lượt`.
- [x] **C3-T2:** Triển khai `ScenarioEventManager` hướng dữ liệu (`Trigger – Condition – Action`) và điều kiện Thắng/Thua/3 Sao.
- [ ] **C3-T3:** Biên tập trọn vẹn dữ liệu `data/settings/stage_settings.json` & `data/battles/battle_10101.json` (Bạch Đằng 1288, sự kiện `MapPhase_TideFall` đầu Vòng 4 lộ bãi cọc `StakedWater`, phục binh xuất kích, hạ Ô Mã Nhi khi giữ `SignalDock (2, 8)`), mô phỏng AI-vs-AI 100 trận không treo lượt.

---

## CỔNG 4 (`CP4` / Gate `P2`): Giao Diện Chiến Trường Map-First, Combat Preview 2 Bước & Polish Va Chạm

- [ ] **C4-T1:** Triển khai `BattleInputFSM` 8 trạng thái khép kín (gồm `PostMoveAction` & xác nhận đòn đánh 2 bước).
- [ ] **C4-T2:** Hoàn thiện HUD Map-First (`>= 80%` diện tích bản đồ), `CombatPreviewBox`, Top Bar (`enable_economy = false`), Briefing, Hội thoại kịch bản & màn Tổng kết 3 Sao.
- [ ] **C4-T3:** Tích hợp Game Feel / Juice sạch 100% (shader `hit_flash.gdshader`, `water_flow.gdshader`, Hit-stop, `CPUParticles2D`, âm thanh tổng hợp sạch khai báo trong `ASSETS.md`) & Save/Load phiên trận đánh 2 tầng.

---

## CỔNG 5 (`CP5` / Gates `P3–P5`): Kinh Tế Chiến Trường, Gói Chiến Dịch Thời Trần & Tối Ưu Web/Android

- [ ] **C5-T1:** Triển khai module Kinh tế chiến trường (`Coin`, `Food`, `Tech`, `Mana`, `MealFood`, `Starvation`) khi `enable_economy = true`.
- [ ] **C5-T2:** Hoàn thiện Gói Chiến dịch Thời Trần, Tutorial ngữ cảnh, Codex lịch sử & rà soát Asset IP Gate sạch 100%.
- [ ] **C5-T3:** Cấu hình xuất bản Web (HTML5/Wasm) & Android, kiểm thử hiệu năng 60 FPS và hồi quy toàn diện.
