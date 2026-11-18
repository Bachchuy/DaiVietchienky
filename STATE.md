# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **CỔNG 1 (`CP1`) — Hệ Tọa Độ Hex, Định Tuyến A*/ZoC/LOS, 16 Lớp Kết Xuất & Camera 60 FPS**.
- **Nhiệm vụ đang thực hiện:** `C1-T4` (`BattleMapView` — 16 lớp kết xuất & tài nguyên đồ họa sạch).
- **Tiến độ Cổng 1:** `3 / 6` nhiệm vụ hoàn thành.
- **Trạng thái bộ test (`tests/run_tests.gd`):** `14/14 passed | 0 failed | 4926 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C1-T3`: Hoàn thành `HexGridNavigator` (A*, Dial's bucket Dijkstra, `fond_terrain`, `CoC * 2`, `ZoC`, `Start-in-ZoC Withdrawal`, `ignore_zoc`, `devoid_zoc`, `LOS`, `get_attackable_hexes`) và `tests/test_hex_navigator.gd` (`14/14` tests pass).
- `C1-T2`: Hoàn thành `UnitCombatState`, `BattleUnit`, `BattleMapState`, `StaticDataLoader` & `troop_settings.json`.
- `C1-T1`: Hoàn thành `HexMath`.

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
