# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **ĐANG THỰC HIỆN CỔNG 4 (`CP4` / Gate `P2`)** — Hoàn thành `C4-T1` (`BattleInputFSM` 8 trạng thái khép kín).
- **Nhiệm vụ vừa xong:** `C4-T1` (`BattleInputFSM`, `PostMoveAction` 4 nhánh, xác nhận đòn đánh 2 bước, `SkillAreaLayer z=16`, ngưỡng kéo camera `> 6px` vs chuột phải hủy `<= 6px`).
- **Tiến độ Cổng 4:** `1 / 3` nhiệm vụ hoàn thành (Cổng 1: `6 / 6`, Cổng 2: `4 / 4`, Cổng 3: `3 / 3`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `56/56 passed | 0 failed | 6159 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C4-T1`: Triển khai `BattleInputFSM` (`scripts/presentation/battle_input_fsm.gd`) 8 trạng thái khép kín (`IDLE`, `UNIT_SELECTED`, `MOVING`, `POST_MOVE_ACTION`, `AIMING_TARGET`, `ATTACKING`, `SKILL_TARGETING`, `EXECUTE_SKILL`), mở khóa vẽ `SkillAreaLayer` (`z=16`) & aim reticle trên `SelectionAndAimLayer` (`z=18`) kèm làm tối token đã hành động trong `BattleMapView`, bổ sung ngưỡng kéo `DRAG_THRESHOLD_PX = 6.0` trên `BattleCameraController` tách biệt pan và chuột phải hủy, nối vào `BattleSandboxCP1`, thêm 9 test TDD tại `tests/test_battle_input_fsm.gd` (`56/56` pass) cùng 5 ảnh chụp màn hình `gl_compatibility`.
- `C3-T3`: Hoàn thành bộ JSON Slice-01 (`data/settings/stage_settings.json`, `data/settings/tactic_settings.json`, `data/battles/battle_10101.json`, mở rộng `data/settings/troop_settings.json` thêm `40202`/`40902`), `ScenarioLoader` + `StaticDataLoader.load_stage_settings`, tách RNG quyết định AI (`DEC-011`), màu phe đối địch động trong `BattleMapView`, tích hợp Slice-01 + AI + Replay vào `BattleSandboxCP1`, xác minh 100 trận AI-vs-AI liên tiếp 0 treo lượt & `< 1.5s/lượt`, cùng 3 ảnh chụp `gl_compatibility` (`47/47` tests pass).
- `C3-T2`: Hoàn thành `ScenarioEventManager` (`Trigger – Condition AND/OR – Action`, `AlterTerrain`, `ApplyAreaEffect`, `SpawnReinforcements` BFS `find_nearest_free_hex`, `once` & restore), `ScenarioVictoryEvaluator` (2 nhánh Thắng, 4 nhánh Thua, chấm 3 Sao) và nối vào vòng lặp 7 pha `BattleGameController` (`44/44` tests pass).
- `C3-T1`: Hoàn thành hệ thống AI 3 pha (`ScenarioDirector`, `AIVisibleMapView`, `AIDifficultyProfile`, `AIActionCandidate`, `AIDecisionMatrix`).

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
