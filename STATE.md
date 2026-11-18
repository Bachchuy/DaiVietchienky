# Trạng Thái Dự Án Hiện Tại (`STATE.md`)

- **Dự án:** Đại Việt Chiến Kỳ (`VietNamHistoryStrategy`) — Godot 4.7.2, Thuần GDScript 2.0 (`gl_compatibility`).
- **Tài liệu chuẩn:** GDD v3.4.1 (`docs/gdd/`).
- **Cổng hiện tại:** **HOÀN TẤT CỔNG 1 (`CP1`) — Đang dừng chờ duyệt Cổng 1 trước khi sang CỔNG 2 (`CP2`)**.
- **Nhiệm vụ tiếp theo (sau khi duyệt cổng):** `C2-T1` (`SeededRng` & `CombatResolver`).
- **Tiến độ Cổng 1:** `6 / 6` nhiệm vụ hoàn thành (`100%`).
- **Trạng thái bộ test (`tests/run_tests.gd`):** `22/22 passed | 0 failed | 5079 assertions`.
- **Hiệu năng đo thực tế (`gl_compatibility` `30×30` + `44` đơn vị):** `3.70 ms/frame` (~`270.4 FPS`), `66 Draw Calls` (đạt vượt chuẩn cứng `<= 16.67 ms/frame` / `60 FPS`).

---

## Lịch sử hoàn thành Cổng 1 (`CP1`)
- `C1-T6`: Hoàn thành scene `scenes/battle/battle_sandbox_cp1.tscn`, `scripts/presentation/battle_sandbox_cp1.gd`, tối ưu batching `RenderingServer.canvas_item_add_triangle_array` + `draw_multiline` (giảm draw calls từ `2847 -> 66`), kiểm thử tích hợp & hiệu năng `tests/test_cp1_integration_and_perf.gd` và chụp 3 ảnh kiểm chứng thực tế.
- `C1-T5`: Hoàn thành `BattleCameraController` & `tests/test_battle_camera.gd`.
- `C1-T4`: Hoàn thành `BattleMapView` (16 lớp kết xuất) + bộ tài nguyên sạch 100% trong `ASSETS.md` & `tests/test_battle_map_view.gd`.
- `C1-T3`: Hoàn thành `HexGridNavigator` (A*, Dial's bucket Dijkstra, `fond_terrain`, `CoC * 2`, `ZoC`, `Start-in-ZoC Withdrawal`, `ignore_zoc`, `devoid_zoc`, `LOS`) & `tests/test_hex_navigator.gd`.
- `C1-T2`: Hoàn thành `UnitCombatState`, `BattleUnit`, `BattleMapState`, `StaticDataLoader`, `data/settings/troop_settings.json` & `tests/test_battle_map_state.gd`.
- `C1-T1`: Hoàn thành `HexMath` & `tests/test_hex_math.gd`.

---

## Bị kẹt
*(Không có nhiệm vụ nào bị kẹt)*
