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

## assert_button_reachable (E2E)

```gdscript
func assert_button_reachable(btn: BaseButton, label: String) -> void:
	assert_not_null(btn, "%s exists" % label)
	if btn == null:
		return
	assert_true(btn.is_visible_in_tree(), "%s visible in tree" % label)
	var r: Rect2 = btn.get_global_rect()
	var vp: Rect2 = btn.get_viewport().get_visible_rect()
	assert_true(vp.encloses(r), "%s fully inside viewport" % label)
	var n: Node = btn.get_parent()
	while n != null:
		if n is Control and (n as Control).clip_contents:
			assert_true((n as Control).get_global_rect().encloses(r), "%s not clipped by %s" % [label, n.name])
		n = n.get_parent()
```

Sau đó click bằng `InputEventMouseButton` qua `get_viewport().push_input(ev)` (không gọi `pressed.emit()`).

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
