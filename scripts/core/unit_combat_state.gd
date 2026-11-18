class_name UnitCombatState
extends RefCounted

enum MoraleLevel {
	CHAOS = 0,
	LOW = 1,
	NORMAL = 2,
	HIGH = 3,
}

var current_hp: int = 160
var max_hp: int = 160
var current_mp: int = 6
var morale: MoraleLevel = MoraleLevel.NORMAL
var is_morale_locked: bool = false

var chaos_turns: int = 0
var march_disabled_turns: int = 0
var attack_disabled_turns: int = 0
var skill_disabled_turns: int = 0

var is_transported: bool = false
var is_invisible: bool = false
var is_taunting: bool = false
var has_retaliated_this_round: bool = false
var has_acted: bool = false
var has_used_undo_this_turn: bool = false
var skill_cooldown: int = 0


func is_alive() -> bool:
	return current_hp > 0


func can_move() -> bool:
	return is_alive() and morale != MoraleLevel.CHAOS and chaos_turns <= 0 and march_disabled_turns <= 0


func can_attack() -> bool:
	return is_alive() and morale != MoraleLevel.CHAOS and chaos_turns <= 0 and attack_disabled_turns <= 0


func can_use_skill() -> bool:
	return (
		is_alive()
		and morale != MoraleLevel.CHAOS
		and chaos_turns <= 0
		and skill_disabled_turns <= 0
		and skill_cooldown <= 0
	)


func can_retaliate() -> bool:
	return can_attack() and not has_retaliated_this_round


func emits_zoc() -> bool:
	return is_alive() and morale != MoraleLevel.CHAOS and chaos_turns <= 0


func shift_morale(delta: int, min_floor: MoraleLevel = MoraleLevel.CHAOS) -> void:
	if delta == 0 or not is_alive():
		return
	if delta < 0 and is_morale_locked:
		return
	if morale == MoraleLevel.CHAOS and delta > 0:
		return
	var next_val: int = clampi(int(morale) + delta, int(min_floor), int(MoraleLevel.HIGH))
	morale = next_val as MoraleLevel
	if morale == MoraleLevel.CHAOS:
		chaos_turns = maxi(chaos_turns, 1)


func apply_starvation_morale_penalty() -> void:
	if morale == MoraleLevel.CHAOS:
		return
	shift_morale(-1, MoraleLevel.LOW)


func apply_chaos(turns: int = 1) -> void:
	if is_morale_locked or not is_alive():
		return
	morale = MoraleLevel.CHAOS
	chaos_turns = maxi(chaos_turns, maxi(1, turns))


func clear_chaos(restore_to: MoraleLevel = MoraleLevel.LOW) -> void:
	chaos_turns = 0
	if morale == MoraleLevel.CHAOS:
		morale = restore_to


func on_faction_turn_start(max_mobility: int = -1) -> void:
	has_acted = false
	has_retaliated_this_round = false
	has_used_undo_this_turn = false
	if skill_cooldown > 0:
		skill_cooldown -= 1
	if max_mobility >= 0:
		current_mp = max_mobility


func on_faction_turn_end(current_trapped_level: int = 0) -> void:
	if current_trapped_level == 1:
		shift_morale(-1)
	elif current_trapped_level >= 2:
		apply_chaos(1)

	if chaos_turns > 0 and current_trapped_level < 3:
		chaos_turns -= 1
		if chaos_turns == 0 and morale == MoraleLevel.CHAOS:
			morale = MoraleLevel.LOW

	if attack_disabled_turns > 0:
		attack_disabled_turns -= 1
	if march_disabled_turns > 0:
		march_disabled_turns -= 1
	if skill_disabled_turns > 0:
		skill_disabled_turns -= 1
