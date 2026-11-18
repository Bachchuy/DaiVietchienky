# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **CỔNG 1 (`CP1`) — Hệ Tọa Độ Hex, Định Tuyến A*/ZoC/LOS, 16 Lớp Kết Xuất & Camera 60 FPS**.
- **Nhiệm vụ đang thực hiện:** `C1-T6` (Scene tương tác Sa bàn `CP1` `12×10` & Stress-Test `30×30` 44+ đơn vị 60 FPS + Screenshot kiểm chứng).
- **Tiến độ Cổng 1:** `5 / 6` nhiệm vụ hoàn thành.
- **Trạng thái bộ test (`tests/run_tests.gd`):** `20/20 passed | 0 failed | 5043 assertions`.

---

## Lịch sử hoàn thành gần nhất
- `C1-T5`: Hoàn thành `BattleCameraController` (Exponential Smoothing độc lập FPS, kẹp biên theo zoom, `StrategicZoom` `< 0.65`, `Trauma Shake` `_fx_rng` riêng) và `tests/test_battle_camera.gd` (`20/20` tests pass).
- `C1-T4`: Hoàn thành `BattleMapView` (16 lớp kết xuất) & tài nguyên sạch trong `ASSETS.md`.
- `C1-T3`: Hoàn thành `HexGridNavigator`.
- `C1-T2`: Hoàn thành `BattleMapState`, `BattleUnit`, `UnitCombatState`, `StaticDataLoader`.
- `C1-T1`: Hoàn thành `HexMath`.

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
