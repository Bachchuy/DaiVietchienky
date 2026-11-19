class_name AIDifficultyProfile
extends Resource

@export var difficulty_id: StringName = &"normal"
@export_range(0.0, 1.0, 0.01) var w_atk: float = 0.35
@export_range(0.0, 1.0, 0.01) var w_pos: float = 0.25
@export_range(0.0, 1.0, 0.01) var w_obj: float = 0.25
@export_range(0.0, 1.0, 0.01) var w_skill: float = 0.15
@export_range(0.0, 50.0, 0.5) var noise_amp: float = 6.0


static func create_preset(preset_id: StringName) -> AIDifficultyProfile:
	var p := AIDifficultyProfile.new()
	p.difficulty_id = preset_id
	match preset_id:
		&"easy":
			p.w_atk = 0.50
			p.w_pos = 0.15
			p.w_obj = 0.20
			p.w_skill = 0.15
			p.noise_amp = 18.0
		&"normal":
			p.w_atk = 0.35
			p.w_pos = 0.25
			p.w_obj = 0.25
			p.w_skill = 0.15
			p.noise_amp = 6.0
		&"hard":
			p.w_atk = 0.30
			p.w_pos = 0.25
			p.w_obj = 0.25
			p.w_skill = 0.20
			p.noise_amp = 1.5
		&"challenge":
			p.w_atk = 0.28
			p.w_pos = 0.27
			p.w_obj = 0.25
			p.w_skill = 0.20
			p.noise_amp = 0.5
		_:
			push_warning("AIDifficultyProfile: Unknown preset '%s', using normal." % preset_id)
			p.difficulty_id = &"normal"
	return p
