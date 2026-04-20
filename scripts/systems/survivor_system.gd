class_name SurvivorSystem
extends RefCounted

func update(
	survivors: Array[Dictionary],
	resources: Array[Dictionary],
	zombies: Array[Dictionary],
	buildings: Array[Dictionary],
	stock: Dictionary,
	effects: EffectsSystem,
	phase: String,
	selected_survivor: int,
	delta: float
) -> int:
	for i in range(survivors.size() - 1, -1, -1):
		var s: Dictionary = survivors[i]
		if s["hp"] <= 0.0:
			if selected_survivor == i:
				selected_survivor = -1
			survivors.remove_at(i)
			continue
		s["command_lock"] = max(0.0, float(s.get("command_lock", 0.0)) - delta)

		if s["task"] == "gather" and phase == "day":
			_process_gather_task(s, resources, stock, effects, delta)
		elif s["task"] == "attack":
			_process_attack_task(s, zombies, effects, delta)
		elif s["task"] == "attack_move":
			_process_attack_move_task(s, zombies, effects, delta)
		elif s["task"] == "repair":
			_process_repair_task(s, zombies, buildings, effects, delta)
		else:
			_move_survivor_toward(s, s["target"], delta)
			if s["task"] == "idle":
				if not _auto_attack_nearest_zombie(s, zombies, effects, delta):
					_auto_repair_damaged_building(s, buildings)
			elif phase == "night" and float(s["command_lock"]) <= 0.0:
				_auto_attack_nearest_zombie(s, zombies, effects, delta)

		survivors[i] = s
	return selected_survivor

func _process_gather_task(s: Dictionary, resources: Array[Dictionary], stock: Dictionary, effects: EffectsSystem, delta: float) -> void:
	var resource_index: int = int(s["resource"])
	if resource_index < 0 or resource_index >= resources.size():
		s["task"] = "idle"
		s["command_lock"] = 0.0
		return
	var r: Dictionary = resources[resource_index]
	_move_survivor_toward(s, r["pos"], delta)
	if s["pos"].distance_to(r["pos"]) <= GameConfig.INTERACT_RANGE:
		s["work_timer"] = float(s["work_timer"]) + delta
		if s["work_timer"] >= 0.45:
			s["work_timer"] = 0.0
			var amount: int = min(3, int(r["amount"]))
			r["amount"] = int(r["amount"]) - amount
			stock[r["type"]] = int(stock[r["type"]]) + amount
			effects.add_float_text("+%d %s" % [amount, r["type"]], r["pos"], GameConfig.RESOURCE_COLORS[r["type"]])
			resources[resource_index] = r
			if int(r["amount"]) <= 0:
				resources.remove_at(resource_index)
				s["task"] = "idle"
				s["resource"] = -1
				s["command_lock"] = 0.0

func _process_attack_task(s: Dictionary, zombies: Array[Dictionary], effects: EffectsSystem, delta: float) -> void:
	var enemy_index: int = int(s["attack"])
	if enemy_index < 0 or enemy_index >= zombies.size():
		s["task"] = "idle"
		s["command_lock"] = 0.0
		return
	var z: Dictionary = zombies[enemy_index]
	var distance: float = s["pos"].distance_to(z["pos"])
	if distance < GameConfig.SURVIVOR_MELEE_RANGE * 1.35 and zombies.size() > 1:
		_kite_away_from_zombie(s, z["pos"], delta)
		_fire_at_zombie_without_chasing(s, zombies, enemy_index, effects, delta)
		return
	if distance > GameConfig.SURVIVOR_RANGED_RANGE:
		_move_survivor_toward(s, z["pos"], delta)
		_fire_at_nearby_zombie(s, zombies, effects, delta)
		s["weapon"] = "bow"
		return
	s["work_timer"] = float(s["work_timer"]) + delta
	if distance <= GameConfig.SURVIVOR_MELEE_RANGE:
		s["weapon"] = "sword"
		if s["work_timer"] >= GameConfig.SURVIVOR_MELEE_COOLDOWN:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - GameConfig.SURVIVOR_MELEE_DAMAGE
			zombies[enemy_index] = z
			effects.add_attack_tracer(s["pos"], z["pos"], 0.12, "melee")
	else:
		s["weapon"] = "bow"
		if s["work_timer"] >= GameConfig.SURVIVOR_BOW_COOLDOWN:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - GameConfig.SURVIVOR_BOW_DAMAGE
			zombies[enemy_index] = z
			effects.add_attack_tracer(s["pos"], z["pos"], 0.18, "arrow")

func _process_attack_move_task(s: Dictionary, zombies: Array[Dictionary], effects: EffectsSystem, delta: float) -> void:
	_move_survivor_toward(s, s["target"], delta)
	var enemy_index: int = int(s.get("attack", -1))
	if enemy_index == -1 or enemy_index >= zombies.size() or s["pos"].distance_to(zombies[enemy_index]["pos"]) > GameConfig.SURVIVOR_RANGED_RANGE:
		enemy_index = SpatialQueries.nearest_zombie(zombies, s["pos"], GameConfig.SURVIVOR_RANGED_RANGE)
		s["attack"] = enemy_index
	if enemy_index != -1:
		_fire_while_moving(s, zombies, enemy_index, effects, delta)
	if s["pos"].distance_to(s["target"]) <= 7.0:
		s["task"] = "idle"
		s["command_lock"] = 0.0

func _fire_while_moving(s: Dictionary, zombies: Array[Dictionary], enemy_index: int, effects: EffectsSystem, delta: float) -> void:
	if enemy_index < 0 or enemy_index >= zombies.size():
		return
	var z: Dictionary = zombies[enemy_index]
	var distance: float = s["pos"].distance_to(z["pos"])
	if distance > GameConfig.SURVIVOR_RANGED_RANGE:
		return
	s["move_fire_timer"] = float(s.get("move_fire_timer", GameConfig.SURVIVOR_BOW_COOLDOWN))
	s["move_fire_timer"] += delta
	if distance <= GameConfig.SURVIVOR_MELEE_RANGE:
		s["weapon"] = "sword"
		if float(s["move_fire_timer"]) >= GameConfig.SURVIVOR_MELEE_COOLDOWN:
			s["move_fire_timer"] = 0.0
			z["hp"] = float(z["hp"]) - GameConfig.SURVIVOR_MELEE_DAMAGE
			zombies[enemy_index] = z
			effects.add_attack_tracer(s["pos"], z["pos"], 0.12, "melee")
	else:
		s["weapon"] = "bow"
		if float(s["move_fire_timer"]) >= GameConfig.SURVIVOR_BOW_COOLDOWN:
			s["move_fire_timer"] = 0.0
			z["hp"] = float(z["hp"]) - GameConfig.SURVIVOR_BOW_DAMAGE
			zombies[enemy_index] = z
			effects.add_attack_tracer(s["pos"], z["pos"], 0.18, "arrow")

func _process_repair_task(s: Dictionary, zombies: Array[Dictionary], buildings: Array[Dictionary], effects: EffectsSystem, delta: float) -> void:
	var building_index: int = int(s.get("repair", -1))
	if building_index < 0 or building_index >= buildings.size() or float(buildings[building_index]["hp"]) >= float(buildings[building_index]["max_hp"]):
		s["task"] = "idle"
		s["repair"] = -1
		return
	if _auto_attack_nearest_zombie(s, zombies, effects, delta):
		return
	var b: Dictionary = buildings[building_index]
	_move_survivor_toward(s, b["pos"], delta)
	if s["pos"].distance_to(b["pos"]) <= GameConfig.SURVIVOR_REPAIR_RANGE:
		s["work_timer"] = float(s["work_timer"]) + delta
		if s["work_timer"] >= 0.55:
			s["work_timer"] = 0.0
			b["hp"] = min(float(b["max_hp"]), float(b["hp"]) + GameConfig.SURVIVOR_REPAIR_AMOUNT)
			buildings[building_index] = b
			effects.add_float_text("+repair", b["pos"] + Vector2(0, -42), Color("#81c784"))

func _kite_away_from_zombie(s: Dictionary, threat_pos: Vector2, delta: float) -> void:
	var away: Vector2 = s["pos"] - threat_pos
	if away.length() > 1.0:
		var target: Vector2 = s["pos"] + away.normalized() * 120.0
		_move_survivor_toward(s, target, delta)

func _fire_at_nearby_zombie(s: Dictionary, zombies: Array[Dictionary], effects: EffectsSystem, delta: float) -> bool:
	var enemy_index: int = SpatialQueries.nearest_zombie(zombies, s["pos"], GameConfig.SURVIVOR_RANGED_RANGE)
	if enemy_index == -1:
		return false
	_fire_at_zombie_without_chasing(s, zombies, enemy_index, effects, delta)
	return true

func _fire_at_zombie_without_chasing(s: Dictionary, zombies: Array[Dictionary], enemy_index: int, effects: EffectsSystem, delta: float) -> void:
	if enemy_index < 0 or enemy_index >= zombies.size():
		return
	var z: Dictionary = zombies[enemy_index]
	var distance: float = s["pos"].distance_to(z["pos"])
	s["work_timer"] = float(s["work_timer"]) + delta
	if distance <= GameConfig.SURVIVOR_MELEE_RANGE:
		s["weapon"] = "sword"
		if s["work_timer"] >= GameConfig.SURVIVOR_MELEE_COOLDOWN:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - GameConfig.SURVIVOR_MELEE_DAMAGE
			zombies[enemy_index] = z
			effects.add_attack_tracer(s["pos"], z["pos"], 0.12, "melee")
	elif distance <= GameConfig.SURVIVOR_RANGED_RANGE:
		s["weapon"] = "bow"
		if s["work_timer"] >= GameConfig.SURVIVOR_BOW_COOLDOWN:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - GameConfig.SURVIVOR_BOW_DAMAGE
			zombies[enemy_index] = z
			effects.add_attack_tracer(s["pos"], z["pos"], 0.18, "arrow")

func _auto_attack_nearest_zombie(s: Dictionary, zombies: Array[Dictionary], effects: EffectsSystem, delta: float) -> bool:
	var enemy_index: int = SpatialQueries.nearest_zombie(zombies, s["pos"], GameConfig.SURVIVOR_RANGED_RANGE)
	if enemy_index == -1:
		return false
	s["task"] = "attack"
	s["attack"] = enemy_index
	_process_attack_task(s, zombies, effects, delta)
	return true

func _auto_repair_damaged_building(s: Dictionary, buildings: Array[Dictionary]) -> bool:
	var building_index: int = SpatialQueries.nearest_damaged_building(buildings, s["pos"], 520.0)
	if building_index == -1:
		return false
	s["task"] = "repair"
	s["repair"] = building_index
	s["work_timer"] = 0.0
	return true

func _move_survivor_toward(s: Dictionary, target: Vector2, delta: float) -> void:
	var offset: Vector2 = target - s["pos"]
	if offset.length() > 5.0:
		s["pos"] += offset.normalized() * GameConfig.SURVIVOR_SPEED * delta
