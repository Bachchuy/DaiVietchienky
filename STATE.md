# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **CỔNG 2 (`CP2` / Gate `P1`) — Vòng Lặp 7 Pha, Command/Undo/Replay, Combat Seeded RNG & Sĩ Khí 4 Bậc**.
- **Nhiệm vụ đang thực hiện:** `C2-T2` (`MoraleEngine` — 4 bậc Sĩ khí, `TrappedLevel 0..3`, lan truyền tâm lý & tự hồi `CHAOS -> LOW`).
- **Tiến độ Cổng 2:** `1 / 4` nhiệm vụ hoàn thành (Cổng 1: `6 / 6`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `26/26 passed | 0 failed | 5160 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C2-T1`: Hoàn thành `SeededRng` (`scripts/core/seeded_rng.gd`), `CombatResolver` (`scripts/core/combat_resolver.gd` — ma trận khắc chế `6×5`, giáp `100/(100+EffectiveDef)`, `RoundHalfUp`, `TroopStack` không vách đá sát thương, `Flank`, `Crit`, Phản kích 1 lần/vòng kèm LOS & `CombatPreview`) và `tests/test_combat_resolver.gd` (`26/26` tests pass).

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
