extends SceneTree

## Visual evidence for C5-T3 fixes (DEC-020):
## 1) Rapid double-click on PauseButton keeps PauseSettingsModal open (idempotent open).
## 2) 3-banner unit at 320/480 HP (66.7%) shows 3 active banners.
## Run windowed (not headless): godot --script res://tests/capture_c5_t3_screenshots.gd

const SANDBOX_SCENE := preload("res://scenes/battle/battle_sandbox_cp1.tscn")

var _frame: int = 0
var _sandbox: Node2D = null
var _out_dir: String = "res://tests/artifacts"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out_dir))
	_sandbox = SANDBOX_SCENE.instantiate() as Node2D
	root.add_child(_sandbox)


func _process(_delta: float) -> bool:
	_frame += 1
	var ctrl: BattleGameController = _sandbox.call("get_controller") as BattleGameController
	var mv: BattleMapView = _sandbox.call("get_map_view") as BattleMapView
	var hud: BattleHudController = _sandbox.get_node_or_null("BattleHudController") as BattleHudController

	if _frame == 4:
		if hud != null:
			hud.dismiss_all_modals()
		var u101: BattleUnit = ctrl.context.get_unit(101)
		if u101 != null:
			u101.state.current_hp = 320
			print("[CHECK] u101 hp=320/%d active_banners=%d" % [u101.state.max_hp, u101.get_active_banners()])
		mv.refresh_units()
	elif _frame == 7:
		_save_viewport_png("c5_t3_banners_3of3_at_66_7pct.png")
		var pause_btn: BaseButton = _find_named(_sandbox, "PauseButton") as BaseButton
		if pause_btn != null:
			pause_btn.pressed.emit()
			pause_btn.pressed.emit()
	elif _frame == 10:
		var modal: Control = _find_named(_sandbox, "PauseSettingsModal") as Control
		print("[CHECK] PauseSettingsModal visible after double-click = %s" % str(modal != null and modal.visible))
		_save_viewport_png("c5_t3_pause_double_click_stays_open.png")
		quit(0)
		return true
	return false


func _find_named(node: Node, target: String) -> Node:
	if node.name == target:
		return node
	for child: Node in node.get_children():
		var hit: Node = _find_named(child, target)
		if hit != null:
			return hit
	return null


func _save_viewport_png(filename: String) -> void:
	var img: Image = root.get_texture().get_image()
	var full_path: String = ProjectSettings.globalize_path(_out_dir.path_join(filename))
	var err: Error = img.save_png(full_path)
	print("[SCREENSHOT] %s -> err=%d (%dx%d)" % [full_path, int(err), img.get_width(), img.get_height()])
