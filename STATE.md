# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **CỔNG 2 (`CP2` / Gate `P1`) — Vòng Lặp 7 Pha, Command/Undo/Replay, Combat Seeded RNG & Sĩ Khí 4 Bậc**.
- **Nhiệm vụ đang thực hiện:** `C2-T3` (`BattleCommand`, `MarchCommand` Undo 5 điều kiện & `ReplayRecorder`).
- **Tiến độ Cổng 2:** `2 / 4` nhiệm vụ hoàn thành (Cổng 1: `6 / 6`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `30/30 passed | 0 failed | 5182 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C2-T2`: Hoàn thành `MoraleEngine` (`scripts/core/morale_engine.gd` — 4 bậc Enum, `TrappedLevel 0..3`, lan truyền đồng đội tử trận `NeighboringDeadMates` + miễn nhiễm hào quang Tướng Cam/Đỏ, sốc tâm lý Chủ soái 3 hex & tự hồi `CHAOS -> LOW`) và `tests/test_morale_engine.gd` (`30/30` tests pass).
- `C2-T1`: Hoàn thành `SeededRng` & `CombatResolver`.

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
