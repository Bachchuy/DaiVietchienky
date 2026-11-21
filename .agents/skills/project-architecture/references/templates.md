# Templates — project-architecture

Mẫu tham khảo, điều chỉnh tên trường theo GDD (`docs/gdd/architecture/data_and_save_system.md`).

## TroopDef (Data)

```gdscript
class_name TroopDef
extends Resource

@export var troop_id: int = 0
@export var display_name: String = ""
@export_enum("Land", "Naval") var domain: int = 0
@export_enum("Infantry", "Archer", "Cavalry", "Siege", "NavalLight", "NavalHeavy") var branch: int = 0
@export_range(1, 9999) var max_hp: int = 160
@export_range(0, 999) var attack: int = 40
@export_range(0, 999) var defense: int = 20
@export_range(1, 12) var move_points: int = 4
@export_range(1, 6) var attack_range: int = 1
@export_range(1, 3) var max_stack: int = 1
@export var icon: Texture2D
@export_multiline var codex_note: String = ""
```

## DataRegistry

```gdscript
class_name DataRegistry
extends Resource

@export var troops: Array[TroopDef] = []
@export var stages: Array[StageDef] = []

func get_troop(id: int) -> TroopDef:
	for t: TroopDef in troops:
		if t.troop_id == id:
			return t
	return null
```

Sim nhận `DataRegistry` qua tham số (không `load()` bên trong Sim) để test có thể truyền registry giả.

## BattleSession (Node duy nhất giữ Sim)

```gdscript
class_name BattleSession
extends Node

signal unit_moved(unit_id: int, from_hex: Vector2i, to_hex: Vector2i)
signal combat_resolved(attacker_id: int, defender_id: int, damage: int)
signal turn_started(faction_id: int, round_index: int)
signal battle_ended(outcome: int)

@export var registry: DataRegistry
@export var stage: StageDef

var _controller: BattleGameController

func start() -> void:
	_controller = BattleGameController.new()
	# ... khởi tạo từ stage + registry, nối sự kiện Sim -> emit signal ...

func submit(command: RefCounted) -> bool:
	return _controller.submit_command(command)
```

View nhận session bằng `@export var session: BattleSession` và chỉ `connect` signal + gọi `submit()`.

## modal.tscn (nút luôn ở chân, không bị cắt)

```text
Modal (Control, anchors full rect, mouse_filter STOP)      # nền mờ chặn click
└── CenterContainer (full rect)
    └── Panel (PanelContainer, custom_minimum_size.x = 520, theme type "ModalPanel")
        └── Margin (MarginContainer, margins 16)
            └── VBox (VBoxContainer, separation 10)
                ├── Title (Label)
                ├── Body (ScrollContainer, size_flags_vertical EXPAND_FILL,
                │         custom_minimum_size.y = 120, giới hạn max qua script theo viewport)
                │   └── BodyLabel (RichTextLabel fit_content, autowrap)
                └── ButtonRow (HBoxContainer, alignment END)        # NGOÀI ScrollContainer
                    ├── SkipButton ("BỎ QUA")
                    └── PrimaryButton ("BẮT ĐẦU")  # grab_focus() khi mở; ui_accept/ui_cancel
```

Không đặt `size` cứng, không `clip_contents` trên Panel. Chiều cao tối đa: `minf(content, viewport.y * 0.8)`.

## assert_button_reachable (dùng sẵn trong `GdTestCase`)

`tests/test_case.gd` đã cung cấp sẵn `assert_button_reachable(btn, vp_size, label)` (kiểm tra `is_visible_in_tree()`, `!disabled`, kích thước `>= 20x20`, nằm trọn trong viewport & mọi tổ tiên `clip_contents`) và `push_click_control(ctrl)` (gửi `InputEventMouseButton` thật qua `_scene_tree.root.push_input()`). Không cần viết lại trong từng file test; khi kiểm tra chân modal, khẳng định thêm nút không nằm trong `ScrollContainer`.

## Chuyển JSON → .tres (một lần, chạy headless)

```gdscript
extends SceneTree
# godot --headless --script res://tools/convert_troops_to_tres.gd

func _initialize() -> void:
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/settings/troop_settings.json"))
	DirAccess.make_dir_recursive_absolute("res://data/defs/troops")
	for entry: Dictionary in (raw as Dictionary).get("troops", []):
		var def := TroopDef.new()
		def.troop_id = int(entry.get("troop_id", 0))
		def.display_name = str(entry.get("name", ""))
		# ... map các trường còn lại ...
		ResourceSaver.save(def, "res://data/defs/troops/%d.tres" % def.troop_id)
	quit(0)
```

Kiểm chứng: số `.tres` = số mục JSON; unit test so sánh chỉ số Def với JSON gốc trước khi xóa JSON.

---

## Mẫu Godot 4.7 đặc thù cho `R2–R3`

### 1. `StageDef` & Sub-Resource (`R2-T2`)
```gdscript
class_name StageDef
extends Resource

@export var stage_id: int = 10101
@export var stage_name: String = ""
@export var max_rounds: int = 10
@export var enable_economy: bool = false
@export var placements: Array[UnitPlacementDef] = []
@export var events: Array[ScenarioEventDef] = []
@export var dialogues: Array[DialogueLineDef] = []
```
- Mọi sub-resource phải đặt `class_name` và `extends Resource` để Inspector tạo trực tiếp bằng nút `+` trong mảng `@export`.

### 2. `TileMapLayer` + `TileSet` Custom Data (`R3-T3`)
```gdscript
# Trên TileSet: tạo Custom Data Layer 0 tên "terrain_type" (int khớp BattleMapState.TerrainType)
func sync_terrain_from_tilemap(tile_layer: TileMapLayer, map_state: BattleMapState) -> void:
	for cell: Vector2i in tile_layer.get_used_cells():
		var td: TileData = tile_layer.get_cell_tile_data(cell)
		if td == null:
			continue
		var axial: Vector2i = HexMath.odd_r_to_axial(cell)
		map_state.set_terrain(axial, int(td.get_custom_data("terrain_type")))
```
- Luôn dùng `TileMapLayer` (không dùng `TileMap` cũ của Godot 4.0–4.2); tọa độ cell của `TileMapLayer` (`odd_r`) quy đổi qua `HexMath.odd_r_to_axial(cell)`.

### 3. `@tool` An Toàn Trong Editor (`R3-T3`)
```gdscript
@tool
extends Node2D

func _ready() -> void:
	if Engine.is_editor_hint():
		_rebuild_editor_preview()
		return
	_start_runtime_battle()
```
- Trong nhánh `Engine.is_editor_hint()`: tuyệt đối không khởi tạo `BattleSession`, AI, hay ghi `user://`; trước khi sinh node preview tạm, dọn node preview cũ hoặc đặt `owner = null` để không lưu rác vào `.tscn`.

### 4. `UnitView.tscn` Ghép Component (`R3-T2`)
```text
UnitView (Node2D — unit_view.gd, <= 200 dòng)
├── Sprite2D               # ShaderMaterial FactionTint.gdshader
├── AnimationPlayer        # idle / move / attack / hit
├── HealthBarComponent     # thanh HP chia vạch theo max_stack
└── StatusBadgeComponent   # biểu tượng sĩ khí / trói / buff
```
- `UnitView` chỉ nhận dữ liệu/tín hiệu từ `BattleSession` hoặc `BattleMap`; không giữ logic tính sát thương hay tự sửa `BattleUnit`.

### 5. Checklist bẫy Godot 4.7 & `gl_compatibility`
- **Typed Dictionary (`Godot 4.4+`):** Dùng `Dictionary[int, TroopDef]` cho dữ liệu tĩnh; khi parse JSON cần ép kiểu rõ (`var d: Dictionary = raw as Dictionary`), tránh gán `Dictionary` không kiểu vào biến typed.
- **Renderer `gl_compatibility`:** Không dùng `GPUParticles2D` phụ thuộc compute/WebGL1; ưu tiên `CPUParticles2D` có pool; shader 2D giữ đơn giản (`canvas_item`, không `hint_screen_texture` nặng nếu không cần).
- **Web/Android `.pck`:** Mọi đường dẫn `res://` phải khớp chính xác chữ hoa/thường (100% `snake_case` chữ thường).
- **Test runner:** Không dùng `OS.execute` gọi lồng `godot` trong test; chạy lọc bằng `--suite=<tên>`.
