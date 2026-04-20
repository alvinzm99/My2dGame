class_name EffectsSystem
extends RefCounted

var floating_texts: Array[Dictionary] = []
var attack_tracers: Array[Dictionary] = []
var command_flashes: Array[Dictionary] = []

func update(delta: float) -> void:
	_update_floating_texts(delta)
	_update_attack_tracers(delta)
	_update_command_flashes(delta)

func add_float_text(text: String, pos: Vector2, color: Color) -> void:
	floating_texts.append({"text": text, "pos": pos, "color": color, "life": 1.1})

func add_attack_tracer(from: Vector2, to: Vector2, life: float, kind := "tower") -> void:
	attack_tracers.append({"from": from, "to": to, "life": life, "kind": kind})

func add_command_flash(pos: Vector2, color: Color, radius: float, text: String) -> void:
	command_flashes.append({"pos": pos, "color": color, "radius": radius, "text": text, "life": 0.55})

func _update_floating_texts(delta: float) -> void:
	for i in range(floating_texts.size() - 1, -1, -1):
		floating_texts[i]["life"] = float(floating_texts[i]["life"]) - delta
		floating_texts[i]["pos"] = floating_texts[i]["pos"] + Vector2(0, -24.0 * delta)
		if float(floating_texts[i]["life"]) <= 0.0:
			floating_texts.remove_at(i)

func _update_attack_tracers(delta: float) -> void:
	for i in range(attack_tracers.size() - 1, -1, -1):
		attack_tracers[i]["life"] = float(attack_tracers[i]["life"]) - delta
		if float(attack_tracers[i]["life"]) <= 0.0:
			attack_tracers.remove_at(i)

func _update_command_flashes(delta: float) -> void:
	for i in range(command_flashes.size() - 1, -1, -1):
		command_flashes[i]["life"] = float(command_flashes[i]["life"]) - delta
		command_flashes[i]["radius"] = float(command_flashes[i]["radius"]) + 34.0 * delta
		if float(command_flashes[i]["life"]) <= 0.0:
			command_flashes.remove_at(i)
