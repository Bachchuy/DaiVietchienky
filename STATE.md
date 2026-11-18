# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **CỔNG 1 (`CP1`) — Hệ Tọa Độ Hex, Định Tuyến A*/ZoC/LOS, 16 Lớp Kết Xuất & Camera 60 FPS**.
- **Nhiệm vụ đang thực hiện:** `C1-T5` (`BattleCameraController` — Exponential Smoothing, Bounds Clamping, StrategicZoom & Trauma Shake).
- **Tiến độ Cổng 1:** `4 / 6` nhiệm vụ hoàn thành.
- **Trạng thái bộ test (`tests/run_tests.gd`):** `17/17 passed | 0 failed | 5024 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C1-T4`: Hoàn thành `BattleMapView` đủ 16 lớp kết xuất chuẩn + bộ icon/huy hiệu sạch 100% tại `res://assets_clean/` (ghi rõ trong `ASSETS.md`) và `tests/test_battle_map_view.gd` (`17/17` tests pass).
- `C1-T3`: Hoàn thành `HexGridNavigator` & `tests/test_hex_navigator.gd`.
- `C1-T2`: Hoàn thành `BattleMapState`, `BattleUnit`, `UnitCombatState`, `StaticDataLoader`.
- `C1-T1`: Hoàn thành `HexMath`.

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
