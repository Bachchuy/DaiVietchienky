---
name: project-architecture
description: >-
  Kiến trúc chuẩn của Đại Việt Chiến Kỳ: 4 tầng Data(.tres) / Sim(RefCounted) /
  BattleSession / Presentation(.tscn), sơ đồ thư mục theo tính năng, quy tắc phụ
  thuộc và checklist thêm tính năng. Dùng trước khi tạo file, scene, data hoặc hệ
  thống mới, khi refactor/tách file lớn, hoặc khi chuyển JSON sang Resource.
---

# Project Architecture — "Lõi thuần + Vỏ dựng trong editor"

Kết hợp điểm mạnh của HexCrown (`D:\code\HexCrown`: scene ghép trong editor, `.tres`,
unit ghép component) với lõi mô phỏng tất định có test của dự án này.

## 1. Bốn tầng và chiều phụ thuộc

```text
Data (.tres Resource) ──► Sim (RefCounted thuần) ──► BattleSession (Node) ──signals──► Presentation (.tscn)
                                                        ▲                                   │
                                                        └──────── submit(Command) ──────────┘
```

| Tầng | Được phép | Cấm |
|---|---|---|
| Data `data/` | `class_name XxxDef extends Resource`, `@export`, tham chiếu `Texture2D`/Def khác | Logic gameplay, state runtime |
| Sim `sim/` | Đọc Def (read-only), `SeededRng`, trả kết quả/sự kiện | `Node`, `get_tree()`, `load()` scene, `randf()` toàn cục, UI |
| Session `game/battle/battle_session.gd` | Giữ `BattleState`, nhận Command, phát signal có kiểu | Vẽ, tạo UI |
| Presentation `game/`, `ui/` | Node/scene, tween, VFX, đọc state qua signal + getter | Sửa state Sim trực tiếp; tự hit-test nút trong `_input` |

Autoload (`autoload/`) chỉ: `Settings`, `SaveService`, `Audio`, `SceneRouter`. Không state trận.

## 2. Sơ đồ thư mục theo tính năng

```text
res://
├── autoload/                 # dịch vụ toàn cục, không state gameplay
├── data/
│   ├── defs/troops/*.tres    # TroopDef
│   ├── defs/generals/*.tres  # GeneralDef
│   ├── defs/terrain/*.tres   # TerrainDef (+ id khớp TileSet custom data)
│   ├── defs/tactics/*.tres   # TacticDef
│   ├── stages/<id>_<slug>/   # stage.tres (StageDef) + map.tscn (TileMapLayer vẽ tay)
│   └── registry.tres         # DataRegistry: Array[TroopDef], Array[StageDef]...
├── sim/state|commands|rules|ai/   # code scripts/core + scripts/ai hiện có chuyển vào đây
├── game/battle/              # battle.tscn, battle_session.gd, map/, units/unit_view.tscn, fx/
├── ui/common/                # modal_frame.tscn, theme.tres, button_row.tscn
├── ui/battle_hud/            # top_bar.tscn, unit_inspector.tscn, command_dock.tscn, briefing_modal.tscn, pause_modal.tscn
├── ui/menus/                 # main_menu.tscn, campaign, codex
└── tests/
```

Tên thư mục/tệp `snake_case` chữ thường 100% (an toàn `.pck` Web/Android).

## 3. Quy tắc bắt buộc

- Script ≤ 400 dòng. Scene con thay vì `_build_xxx()` dựng node bằng code.
- Phụ thuộc có kiểu qua `@export var session: BattleSession` (gán trong editor) hoặc `setup(session)` từ cha. Cấm `ServiceRegistry` kiểu `var grid: Node`, cấm `get_node("/root/...")`.
- Signal theo phạm vi trận (trên `BattleSession`), không dùng EventBus toàn cục cho sự kiện trận.
- Style UI trong `ui/common/theme.tres`; chỉ override cục bộ khi thật cần.
- Data mới luôn là `.tres`. GDD yêu cầu JSON → báo người dùng, đề xuất sửa GDD trước.
- **Không làm `CombatPreviewBox` tính trước sát thương / xác nhận đánh 2 bước:** HUD chỉ dùng `UnitInspector` (`unit_inspector.tscn`) hiện thông số từng đạo quân; chạm vào địch trong tầm đỏ là ra đòn 1 chạm ngay (`BattleInputFSM` 7 trạng thái, bỏ `AIMING_TARGET`).
- **Cổng dừng Asset (`R4`):** Cấm tự ý sinh/vẽ asset đồ họa mới — phải dừng lại hỏi người dùng lên phương án và công cụ trước khi tạo.

## 4. Checklist thêm một tính năng

1. Def: tạo/điều chỉnh `XxxDef` + `.tres` mẫu; đăng ký vào `registry.tres`.
2. Sim: luật trong `sim/` + unit test headless (`tests/run_tests.gd`), giữ tất định.
3. Session: thêm signal có kiểu / Command mới.
4. View: scene `.tscn` (mở được trong editor, view 2D có nội dung), nối signal, dùng theme.
5. Test: thêm/chạy test lọc (`--suite=...`) gồm `assert_button_reachable()` + `push_click_control()` cho nút UI mới, rồi chạy full fast suite `tests/run_tests.gd` (không mặc định chụp ảnh PNG).
6. Cung cấp checklist `F5` ngắn (2–3 bước) để người dùng tự kiểm tra View 2D/Inspector và luồng chơi trong Editor.
7. Khi chốt Task/Cổng: cập nhật gọn `STATE.md`/`TASKS.md` và `.ai/HANDOFF.md` (`<= 25` dòng).

## 5. Lấy gì / tránh gì từ HexCrown

- **Lấy:** `UnitResource` + `UnitDatabase.tres`; `base_unit.tscn` ghép component (`StatsComponent`, `HealthBar`, `Animator`...); `main.tscn` ghép `level.tscn` + `gameplay_ui.tscn`; Command có trạng thái hoàn tất async cho animation.
- **Tránh:** 20+ autoload giữ state (`GridManager`, `CombatManager`...); `ServiceRegistry` biến `Node` không kiểu; không có test; file 800–1200 dòng.

## 6. Mẫu code

Xem [references/templates.md](references/templates.md): `TroopDef`, `DataRegistry`, `BattleSession`,
cấu trúc `modal.tscn`, helper `assert_button_reachable`, script chuyển JSON → `.tres`.
