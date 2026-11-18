# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **CỔNG 2 (`CP2` / Gate `P1`) — Vòng Lặp 7 Pha, Command/Undo/Replay, Combat Seeded RNG & Sĩ Khí 4 Bậc**.
- **Nhiệm vụ đang thực hiện:** `C2-T4` (`BattleGameController` — Vòng lặp 7 pha & kiểm thử phát lại 50 lượt không lệch 1 điểm HP).
- **Tiến độ Cổng 2:** `3 / 4` nhiệm vụ hoàn thành (Cổng 1: `6 / 6`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `33/33 passed | 0 failed | 5231 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C2-T3`: Hoàn thành `BattleContext`, `BattleCommands` (`March`, `Attack`, `CastSkill`, `Wait`, `EndTurn`), kiểm định đủ 5 điều kiện Undo 1 lần/lượt và `CommandHistory` ghi/phát lại Replay JSON tất định 100% (`33/33` tests pass).
- `C2-T2`: Hoàn thành `MoraleEngine`.
- `C2-T1`: Hoàn thành `SeededRng` & `CombatResolver`.

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
