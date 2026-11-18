class_name UnitCombatState
extends RefCounted

enum MoraleLevel {
	HIGH = 0,
	NORMAL = 1,
	LOW = 2,
	CHAOS = 3,
}

var current_hp: int = 160
var max_hp: int = 160
var current_mp: int = 6
var morale: MoraleLevel = MoraleLevel.NORMAL
var chaos_turns: int = 0
var march_disabled_turns: int = 0
var attack_disabled_turns: int = 0
var is_transported: bool = false
var is_invisible: bool = false
var has_acted: bool = false
var has_used_undo_this_turn: bool = false


func is_alive() -> bool:
	return current_hp > 0


func emits_zoc() -> bool:
	return is_alive() and morale != MoraleLevel.CHAOS and chaos_turns <= 0
