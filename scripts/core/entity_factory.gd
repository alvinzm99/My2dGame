class_name EntityFactory
extends RefCounted

static func make_survivor(pos: Vector2, texture: Texture2D) -> Dictionary:
	return {
		"pos": pos,
		"target": pos,
		"hp": 100.0,
		"task": "idle",
		"resource": -1,
		"attack": -1,
		"carry_type": "",
		"carry": 0,
		"work_timer": 0.0,
		"weapon": "bow",
		"command_lock": 0.0,
		"texture": texture,
		"repair": -1,
	}

static func make_building(kind: String, pos: Vector2, base_max_hp: float) -> Dictionary:
	if kind == "core":
		return {
			"kind": "core",
			"pos": pos,
			"hp": base_max_hp,
			"max_hp": base_max_hp,
			"size": Vector2(86, 86),
			"cooldown": 0.0,
			"angle": 0.0,
		}

	var def: Dictionary = GameConfig.BUILDINGS[kind]
	return {
		"kind": kind,
		"pos": pos,
		"hp": float(def["hp"]),
		"max_hp": float(def["hp"]),
		"size": def["size"],
		"cooldown": 0.0,
		"angle": 0.0,
	}

static func make_zombie(pos: Vector2, hp: float, damage: float, roaming: bool, from_wave: bool, texture: Texture2D, wander_target: Vector2) -> Dictionary:
	return {
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"damage": damage,
		"attack_timer": 0.0,
		"state": "roam" if roaming else "attack",
		"wander_target": wander_target,
		"from_wave": from_wave,
		"texture": texture,
	}

static func starting_wall_positions() -> Array[Vector2]:
	return [
		Vector2(-240, -240), Vector2(-192, -240), Vector2(-144, -240), Vector2(-96, -240), Vector2(-48, -240),
		Vector2(48, -240), Vector2(96, -240), Vector2(144, -240), Vector2(192, -240), Vector2(240, -240),
		Vector2(-240, 240), Vector2(-192, 240), Vector2(-144, 240), Vector2(-96, 240), Vector2(-48, 240),
		Vector2(48, 240), Vector2(96, 240), Vector2(144, 240), Vector2(192, 240), Vector2(240, 240),
		Vector2(-240, -192), Vector2(-240, -144), Vector2(-240, -96), Vector2(-240, -48), Vector2(-240, 0),
		Vector2(-240, 48), Vector2(-240, 96), Vector2(-240, 144), Vector2(-240, 192),
		Vector2(240, -192), Vector2(240, -144), Vector2(240, -96), Vector2(240, -48), Vector2(240, 0),
		Vector2(240, 48), Vector2(240, 96), Vector2(240, 144), Vector2(240, 192),
	]
