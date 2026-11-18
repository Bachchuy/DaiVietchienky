# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **HOÀN TẤT CỔNG 2 (`CP2` / Gate `P1`) — Đang dừng chờ duyệt Cổng 2 trước khi sang CỔNG 3 (`CP3`)**.
- **Nhiệm vụ tiếp theo (sau khi duyệt cổng):** `C3-T1` (Hệ thống AI 3 pha `Generators -> Evaluators -> Utility Scoring`).
- **Tiến độ Cổng 2:** `4 / 4` nhiệm vụ hoàn thành (`100%`) | Tổng tích lũy: `10 / 10` nhiệm vụ (`Cổng 1 + Cổng 2`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `36/36 passed | 0 failed | 5421 assertions`.

---

## Lịch sử hoàn thành Cổng 2 (`CP2` / Gate `P1`)
- `C2-T4`: Hoàn thành `BattleGameController` (`scripts/core/battle_game_controller.gd` — Vòng lặp 7 pha, kiểm tra tách biệt 100% `scripts/core/` khỏi `SceneTree`, kiểm thử phát lại `>= 50` lượt khớp 100% HP/tọa độ/Sĩ khí/RNG trong `tests/test_battle_game_controller.gd`) và tích hợp điều khiển trực tiếp vào sa bàn chính kèm 3 ảnh chụp kiểm chứng.
- `C2-T3`: Hoàn thành `BattleContext`, `BattleCommands` (`March`, `Attack`, `CastSkill`, `Wait`, `EndTurn`), luật Undo 1 lần/lượt đủ 5 điều kiện và `CommandHistory` ghi/phát lại JSON Replay (`tests/test_battle_commands_and_replay.gd`).
- `C2-T2`: Hoàn thành `MoraleEngine` 4 bậc Enum (`CHAOS / LOW / NORMAL / HIGH`), `TrappedLevel 0..3`, `NeighboringDeadMates`, sốc tâm lý Chủ soái 3 hex & tự hồi `CHAOS -> LOW` (`tests/test_morale_engine.gd`).
- `C2-T1`: Hoàn thành `SeededRng` & `CombatResolver` (`80%–100%` + Crit, giáp `100/(100+EffectiveDef)`, `RoundHalfUp`, ma trận `6×5`, `TroopStack` không vách đá sát thương, `Flank`, phản kích tối đa 1 lần/vòng có xét LOS & `CombatPreview` — `tests/test_combat_resolver.gd`).

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
