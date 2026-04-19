extends Node2D

const MAP_HALF_SIZE := Vector2(1800.0, 1200.0)
const DAY_SECONDS := 55.0
const NIGHT_SECONDS := 45.0
const SURVIVOR_SPEED := 135.0
const ZOMBIE_SPEED := 72.0
const INTERACT_RANGE := 36.0
const BUILD_GRID := 48.0

const RESOURCE_COLORS := {
	"wood": Color("#5d8a45"),
	"scrap": Color("#8a9299"),
	"food": Color("#d6a03f"),
}

const BUILDINGS := {
	"wall": {
		"name": "Wall",
		"cost": {"wood": 12, "scrap": 4},
		"hp": 180,
		"size": Vector2(42, 42),
		"color": Color("#6b7075"),
	},
	"tower": {
		"name": "Watchtower",
		"cost": {"wood": 24, "scrap": 18},
		"hp": 140,
		"size": Vector2(46, 46),
		"color": Color("#a26d3d"),
		"range": 280.0,
		"damage": 18.0,
		"cooldown": 0.7,
	},
	"shelter": {
		"name": "Shelter",
		"cost": {"wood": 32, "food": 18},
		"hp": 220,
		"size": Vector2(66, 48),
		"color": Color("#546e7a"),
	},
}

const REGIONS := [
	{
		"name": "旧高速服务区",
		"resource_goal": {"wood": 120, "scrap": 70, "food": 55},
		"required_nights": 2,
		"required_buildings": {"wall": 4, "tower": 1, "shelter": 1},
		"threat": 1,
	},
	{
		"name": "废弃工业镇",
		"resource_goal": {"wood": 180, "scrap": 135, "food": 90},
		"required_nights": 3,
		"required_buildings": {"wall": 7, "tower": 2, "shelter": 2},
		"threat": 2,
	},
	{
		"name": "河岸隔离带",
		"resource_goal": {"wood": 260, "scrap": 210, "food": 135},
		"required_nights": 4,
		"required_buildings": {"wall": 10, "tower": 3, "shelter": 3},
		"threat": 3,
	},
]

var rng := RandomNumberGenerator.new()
var camera: Camera2D
var canvas_modulate: CanvasModulate
var hud_label: Label
var objective_label: Label
var selected_label: Label
var message_label: Label
var build_buttons: Array[Button] = []

var phase := "day"
var phase_time := DAY_SECONDS
var day_count := 1
var nights_survived_in_region := 0
var region_index := 0
var current_spawn_direction := "none"
var wave_spawned := 0
var wave_target := 0
var spawn_timer := 0.0
var message := "白天：选择幸存者，右键资源采集，数字键建造防线。"
var message_time := 5.0

var stock := {"wood": 80, "scrap": 55, "food": 45}
var base_max_hp := 900.0
var base_hp := base_max_hp
var build_mode := ""
var selected_survivor := -1

var survivors: Array[Dictionary] = []
var resources: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var zombies: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []

func _ready() -> void:
	rng.randomize()
	_setup_camera()
	_setup_ui()
	_start_region(0, 3)

func _setup_camera() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(0.85, 0.85)
	add_child(camera)
	camera.make_current()
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.color = Color(1.0, 1.0, 1.0)
	add_child(canvas_modulate)

func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := VBoxContainer.new()
	root.anchor_right = 1.0
	root.offset_left = 14.0
	root.offset_top = 12.0
	root.offset_right = -14.0
	root.add_theme_constant_override("separation", 6)
	layer.add_child(root)

	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 18)
	root.add_child(hud_label)

	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 15)
	root.add_child(objective_label)

	selected_label = Label.new()
	selected_label.add_theme_font_size_override("font_size", 15)
	root.add_child(selected_label)

	var build_bar := HBoxContainer.new()
	build_bar.add_theme_constant_override("separation", 8)
	root.add_child(build_bar)
	_add_build_button(build_bar, "1 墙", "wall")
	_add_build_button(build_bar, "2 塔", "tower")
	_add_build_button(build_bar, "3 避难所", "shelter")

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	root.add_child(message_label)

func _add_build_button(parent: HBoxContainer, text: String, kind: String) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 34)
	button.pressed.connect(func() -> void:
		_set_build_mode(kind)
	)
	parent.add_child(button)
	build_buttons.append(button)

func _start_region(index: int, survivor_count: int) -> void:
	region_index = clamp(index, 0, REGIONS.size() - 1)
	phase = "day"
	phase_time = DAY_SECONDS
	day_count = 1
	nights_survived_in_region = 0
	wave_spawned = 0
	wave_target = 0
	zombies.clear()
	buildings.clear()
	resources.clear()
	survivors.clear()
	base_hp = base_max_hp
	selected_survivor = -1
	build_mode = ""
	_spawn_initial_camp(survivor_count)
	_spawn_resources()
	_show_message("抵达%s。白天收集物资和建设，夜晚守住营地核心。" % REGIONS[region_index]["name"], 6.0)

func _spawn_initial_camp(survivor_count: int) -> void:
	buildings.append(_make_building("core", Vector2.ZERO))
	for i in survivor_count:
		var angle: float = TAU * float(i) / max(1.0, float(survivor_count))
		survivors.append({
			"pos": Vector2(cos(angle), sin(angle)) * 80.0,
			"target": Vector2(cos(angle), sin(angle)) * 80.0,
			"hp": 100.0,
			"task": "idle",
			"resource": -1,
			"attack": -1,
			"carry_type": "",
			"carry": 0,
			"work_timer": 0.0,
		})

func _make_building(kind: String, pos: Vector2) -> Dictionary:
	if kind == "core":
		return {
			"kind": "core",
			"pos": pos,
			"hp": base_max_hp,
			"max_hp": base_max_hp,
			"size": Vector2(86, 86),
			"cooldown": 0.0,
		}
	var def: Dictionary = BUILDINGS[kind]
	return {
		"kind": kind,
		"pos": pos,
		"hp": float(def["hp"]),
		"max_hp": float(def["hp"]),
		"size": def["size"],
		"cooldown": 0.0,
	}

func _spawn_resources() -> void:
	var types := ["wood", "scrap", "food"]
	for i in 34:
		var resource_type: String = types[i % types.size()]
		var pos := Vector2(
			rng.randf_range(-MAP_HALF_SIZE.x + 180.0, MAP_HALF_SIZE.x - 180.0),
			rng.randf_range(-MAP_HALF_SIZE.y + 180.0, MAP_HALF_SIZE.y - 180.0)
		)
		if pos.length() < 260.0:
			pos += pos.normalized() * 320.0
		resources.append({
			"type": resource_type,
			"pos": pos,
			"amount": rng.randi_range(35, 70) + region_index * 12,
		})

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_phase(delta)
	_update_survivors(delta)
	_update_buildings(delta)
	_update_zombies(delta)
	_update_floating_texts(delta)
	_update_ui()
	queue_redraw()

func _update_camera(delta: float) -> void:
	var input := Vector2.ZERO
	input.x = Input.get_action_strength("camera_right") - Input.get_action_strength("camera_left")
	input.y = Input.get_action_strength("camera_down") - Input.get_action_strength("camera_up")
	if input.length() > 0.0:
		camera.position += input.normalized() * 640.0 * delta * camera.zoom.x
	camera.position.x = clamp(camera.position.x, -MAP_HALF_SIZE.x, MAP_HALF_SIZE.x)
	camera.position.y = clamp(camera.position.y, -MAP_HALF_SIZE.y, MAP_HALF_SIZE.y)

func _update_phase(delta: float) -> void:
	phase_time -= delta
	if phase == "day":
		canvas_modulate.color = canvas_modulate.color.lerp(Color(1.0, 1.0, 0.93), delta * 1.5)
		if phase_time <= 0.0:
			_start_night()
	else:
		canvas_modulate.color = canvas_modulate.color.lerp(Color(0.38, 0.43, 0.56), delta * 1.6)
		_update_wave_spawning(delta)
		if phase_time <= 0.0 and zombies.is_empty() and wave_spawned >= wave_target:
			_start_day()

func _start_night() -> void:
	phase = "night"
	phase_time = NIGHT_SECONDS
	var directions := ["north", "east", "south", "west"]
	current_spawn_direction = directions[(nights_survived_in_region + region_index + rng.randi_range(0, 2)) % directions.size()]
	wave_spawned = 0
	wave_target = 8 + REGIONS[region_index]["threat"] * 5 + nights_survived_in_region * 4
	spawn_timer = 0.4
	_show_message("夜晚尸潮来袭：%s方向，预计%d只。" % [_direction_text(current_spawn_direction), wave_target], 5.0)

func _start_day() -> void:
	phase = "day"
	phase_time = DAY_SECONDS
	day_count += 1
	nights_survived_in_region += 1
	for i in buildings.size():
		if buildings[i]["kind"] == "core":
			base_hp = buildings[i]["hp"]
			break
	_show_message("天亮了。第%d晚已守住，继续采集和加固营地。" % nights_survived_in_region, 5.0)
	if _region_complete():
		_show_message("区域任务完成！按 N 前往下一个地区。", 12.0)

func _update_wave_spawning(delta: float) -> void:
	if wave_spawned >= wave_target:
		return
	spawn_timer -= delta
	if spawn_timer <= 0.0:
		_spawn_zombie(current_spawn_direction)
		wave_spawned += 1
		spawn_timer = max(0.35, 1.35 - region_index * 0.16 - nights_survived_in_region * 0.05)

func _spawn_zombie(direction: String) -> void:
	var pos := Vector2.ZERO
	match direction:
		"north":
			pos = Vector2(rng.randf_range(-MAP_HALF_SIZE.x, MAP_HALF_SIZE.x), -MAP_HALF_SIZE.y - 80.0)
		"south":
			pos = Vector2(rng.randf_range(-MAP_HALF_SIZE.x, MAP_HALF_SIZE.x), MAP_HALF_SIZE.y + 80.0)
		"east":
			pos = Vector2(MAP_HALF_SIZE.x + 80.0, rng.randf_range(-MAP_HALF_SIZE.y, MAP_HALF_SIZE.y))
		_:
			pos = Vector2(-MAP_HALF_SIZE.x - 80.0, rng.randf_range(-MAP_HALF_SIZE.y, MAP_HALF_SIZE.y))
	var threat: int = REGIONS[region_index]["threat"]
	zombies.append({
		"pos": pos,
		"hp": 45.0 + threat * 16.0 + nights_survived_in_region * 6.0,
		"max_hp": 45.0 + threat * 16.0 + nights_survived_in_region * 6.0,
		"damage": 7.0 + threat * 2.0,
		"attack_timer": 0.0,
	})

func _update_survivors(delta: float) -> void:
	for i in range(survivors.size() - 1, -1, -1):
		var s := survivors[i]
		if s["hp"] <= 0.0:
			if selected_survivor == i:
				selected_survivor = -1
			survivors.remove_at(i)
			continue

		if s["task"] == "gather" and phase == "day":
			_process_gather_task(s, delta)
		elif s["task"] == "attack":
			_process_attack_task(s, delta)
		else:
			_move_survivor_toward(s, s["target"], delta)
			if phase == "night":
				_auto_attack_nearest_zombie(s, delta)

		survivors[i] = s

func _process_gather_task(s: Dictionary, delta: float) -> void:
	var resource_index: int = int(s["resource"])
	if resource_index < 0 or resource_index >= resources.size():
		s["task"] = "idle"
		return
	var r: Dictionary = resources[resource_index]
	_move_survivor_toward(s, r["pos"], delta)
	if s["pos"].distance_to(r["pos"]) <= INTERACT_RANGE:
		s["work_timer"] = float(s["work_timer"]) + delta
		if s["work_timer"] >= 0.45:
			s["work_timer"] = 0.0
			var amount: int = min(3, int(r["amount"]))
			r["amount"] = int(r["amount"]) - amount
			stock[r["type"]] = int(stock[r["type"]]) + amount
			_add_float_text("+%d %s" % [amount, r["type"]], r["pos"], RESOURCE_COLORS[r["type"]])
			resources[resource_index] = r
			if int(r["amount"]) <= 0:
				resources.remove_at(resource_index)
				s["task"] = "idle"
				s["resource"] = -1

func _process_attack_task(s: Dictionary, delta: float) -> void:
	var enemy_index: int = int(s["attack"])
	if enemy_index < 0 or enemy_index >= zombies.size():
		s["task"] = "idle"
		return
	var z := zombies[enemy_index]
	_move_survivor_toward(s, z["pos"], delta)
	if s["pos"].distance_to(z["pos"]) <= 72.0:
		s["work_timer"] = float(s["work_timer"]) + delta
		if s["work_timer"] >= 0.65:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - 12.0
			zombies[enemy_index] = z

func _auto_attack_nearest_zombie(s: Dictionary, delta: float) -> void:
	var enemy_index := _nearest_zombie(s["pos"], 115.0)
	if enemy_index == -1:
		return
	s["task"] = "attack"
	s["attack"] = enemy_index
	_process_attack_task(s, delta)

func _move_survivor_toward(s: Dictionary, target: Vector2, delta: float) -> void:
	var offset: Vector2 = target - s["pos"]
	if offset.length() > 5.0:
		s["pos"] += offset.normalized() * SURVIVOR_SPEED * delta

func _update_buildings(delta: float) -> void:
	for i in range(buildings.size() - 1, -1, -1):
		var b := buildings[i]
		if b["hp"] <= 0.0:
			if b["kind"] == "core":
				_show_message("营地核心被摧毁。按 R 重开当前地区。", 999.0)
			buildings.remove_at(i)
			continue
		if b["kind"] == "tower":
			b["cooldown"] = max(0.0, float(b["cooldown"]) - delta)
			if float(b["cooldown"]) <= 0.0:
				var enemy_index := _nearest_zombie(b["pos"], float(BUILDINGS["tower"]["range"]))
				if enemy_index != -1:
					zombies[enemy_index]["hp"] = float(zombies[enemy_index]["hp"]) - float(BUILDINGS["tower"]["damage"])
					b["cooldown"] = float(BUILDINGS["tower"]["cooldown"])
					_add_float_text("塔射击", b["pos"] + Vector2(0, -36), Color("#ffd54f"))
		if b["kind"] == "core":
			base_hp = float(b["hp"])
		buildings[i] = b

func _update_zombies(delta: float) -> void:
	for i in range(zombies.size() - 1, -1, -1):
		var z := zombies[i]
		if float(z["hp"]) <= 0.0:
			zombies.remove_at(i)
			continue
		var target := _best_zombie_target(z["pos"])
		if target["type"] == "":
			continue
		var target_pos: Vector2 = target["pos"]
		var distance: float = z["pos"].distance_to(target_pos)
		if distance > 34.0:
			z["pos"] += (target_pos - z["pos"]).normalized() * (ZOMBIE_SPEED + region_index * 7.0) * delta
		else:
			z["attack_timer"] = max(0.0, float(z["attack_timer"]) - delta)
			if float(z["attack_timer"]) <= 0.0:
				_apply_zombie_damage(target, float(z["damage"]))
				z["attack_timer"] = 0.75
		zombies[i] = z

func _best_zombie_target(pos: Vector2) -> Dictionary:
	var best := {"type": "", "index": -1, "pos": Vector2.ZERO, "distance": INF}
	for i in buildings.size():
		var d := pos.distance_to(buildings[i]["pos"])
		var weight := d
		if buildings[i]["kind"] == "core":
			weight -= 120.0
		if weight < float(best["distance"]):
			best = {"type": "building", "index": i, "pos": buildings[i]["pos"], "distance": weight}
	for i in survivors.size():
		var d := pos.distance_to(survivors[i]["pos"])
		if d < 180.0 and d < float(best["distance"]):
			best = {"type": "survivor", "index": i, "pos": survivors[i]["pos"], "distance": d}
	return best

func _apply_zombie_damage(target: Dictionary, damage: float) -> void:
	if target["type"] == "building":
		var i: int = target["index"]
		if i >= 0 and i < buildings.size():
			buildings[i]["hp"] = float(buildings[i]["hp"]) - damage
	elif target["type"] == "survivor":
		var i: int = target["index"]
		if i >= 0 and i < survivors.size():
			survivors[i]["hp"] = float(survivors[i]["hp"]) - damage

func _nearest_zombie(pos: Vector2, max_range: float) -> int:
	var best := -1
	var best_distance := max_range
	for i in zombies.size():
		var d := pos.distance_to(zombies[i]["pos"])
		if d < best_distance:
			best = i
			best_distance = d
	return best

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 0.9).clamp(Vector2(0.45, 0.45), Vector2(1.6, 1.6))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.45, 0.45), Vector2(1.6, 1.6))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_handle_right_click(get_global_mouse_position())
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_set_build_mode("wall")
			KEY_2:
				_set_build_mode("tower")
			KEY_3:
				_set_build_mode("shelter")
			KEY_ESCAPE:
				build_mode = ""
			KEY_N:
				if _region_complete():
					_travel_to_next_region()
			KEY_R:
				if _core_destroyed() or survivors.is_empty():
					_start_region(region_index, 3)

func _handle_left_click(world_pos: Vector2) -> void:
	if build_mode != "":
		_place_building(world_pos)
		return
	selected_survivor = _survivor_at(world_pos)
	if selected_survivor != -1:
		_show_message("已选择幸存者。右键资源、敌人或地面下达命令。", 2.5)

func _handle_right_click(world_pos: Vector2) -> void:
	if selected_survivor == -1 or selected_survivor >= survivors.size():
		return
	var resource_index := _resource_at(world_pos)
	var enemy_index := _zombie_at(world_pos)
	if resource_index != -1 and phase == "day":
		survivors[selected_survivor]["task"] = "gather"
		survivors[selected_survivor]["resource"] = resource_index
		survivors[selected_survivor]["work_timer"] = 0.0
	elif enemy_index != -1:
		survivors[selected_survivor]["task"] = "attack"
		survivors[selected_survivor]["attack"] = enemy_index
		survivors[selected_survivor]["work_timer"] = 0.0
	else:
		survivors[selected_survivor]["task"] = "move"
		survivors[selected_survivor]["target"] = world_pos

func _set_build_mode(kind: String) -> void:
	build_mode = kind
	_show_message("放置%s：左键确认，Esc取消。成本 %s" % [BUILDINGS[kind]["name"], _cost_text(BUILDINGS[kind]["cost"])], 4.0)

func _place_building(world_pos: Vector2) -> void:
	var pos := Vector2(round(world_pos.x / BUILD_GRID) * BUILD_GRID, round(world_pos.y / BUILD_GRID) * BUILD_GRID)
	if pos.length() < 110.0:
		_show_message("离营地核心太近。", 2.0)
		return
	if _building_at(pos) != -1:
		_show_message("这里已经有建筑。", 2.0)
		return
	var cost: Dictionary = BUILDINGS[build_mode]["cost"]
	if not _can_afford(cost):
		_show_message("资源不足：%s" % _cost_text(cost), 3.0)
		return
	_pay_cost(cost)
	buildings.append(_make_building(build_mode, pos))
	_add_float_text("建造完成", pos, Color("#90caf9"))
	if build_mode == "shelter" and survivors.size() < 6:
		survivors.append({
			"pos": pos + Vector2(0, 48),
			"target": pos + Vector2(0, 48),
			"hp": 100.0,
			"task": "idle",
			"resource": -1,
			"attack": -1,
			"carry_type": "",
			"carry": 0,
			"work_timer": 0.0,
		})
		_show_message("避难所接纳了一名新幸存者。", 4.0)

func _can_afford(cost: Dictionary) -> bool:
	for key in cost.keys():
		if int(stock.get(key, 0)) < int(cost[key]):
			return false
	return true

func _pay_cost(cost: Dictionary) -> void:
	for key in cost.keys():
		stock[key] = int(stock[key]) - int(cost[key])

func _region_complete() -> bool:
	var region: Dictionary = REGIONS[region_index]
	if nights_survived_in_region < int(region["required_nights"]):
		return false
	for key in region["resource_goal"].keys():
		if int(stock[key]) < int(region["resource_goal"][key]):
			return false
	var counts := _building_counts()
	for key in region["required_buildings"].keys():
		if int(counts.get(key, 0)) < int(region["required_buildings"][key]):
			return false
	return not _core_destroyed()

func _travel_to_next_region() -> void:
	if region_index >= REGIONS.size() - 1:
		_show_message("所有已知地区目标完成。末日营地路线已打通！", 999.0)
		return
	var living: int = clamp(survivors.size(), 2, 6)
	var goal: Dictionary = REGIONS[region_index]["resource_goal"]
	for key in goal.keys():
		stock[key] = max(20, int((int(stock[key]) - int(goal[key])) * 0.45))
	_start_region(region_index + 1, living)

func _building_counts() -> Dictionary:
	var counts := {}
	for b in buildings:
		var kind: String = b["kind"]
		if kind == "core":
			continue
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts

func _core_destroyed() -> bool:
	for b in buildings:
		if b["kind"] == "core":
			return float(b["hp"]) <= 0.0
	return true

func _survivor_at(pos: Vector2) -> int:
	for i in survivors.size():
		if survivors[i]["pos"].distance_to(pos) <= 28.0:
			return i
	return -1

func _resource_at(pos: Vector2) -> int:
	for i in resources.size():
		if resources[i]["pos"].distance_to(pos) <= 34.0:
			return i
	return -1

func _zombie_at(pos: Vector2) -> int:
	for i in zombies.size():
		if zombies[i]["pos"].distance_to(pos) <= 30.0:
			return i
	return -1

func _building_at(pos: Vector2) -> int:
	for i in buildings.size():
		var b := buildings[i]
		var half: Vector2 = b["size"] * 0.55
		if Rect2(b["pos"] - half, half * 2.0).has_point(pos):
			return i
	return -1

func _update_floating_texts(delta: float) -> void:
	for i in range(floating_texts.size() - 1, -1, -1):
		floating_texts[i]["life"] = float(floating_texts[i]["life"]) - delta
		floating_texts[i]["pos"] = floating_texts[i]["pos"] + Vector2(0, -24.0 * delta)
		if float(floating_texts[i]["life"]) <= 0.0:
			floating_texts.remove_at(i)

func _add_float_text(text: String, pos: Vector2, color: Color) -> void:
	floating_texts.append({"text": text, "pos": pos, "color": color, "life": 1.1})

func _show_message(text: String, duration: float) -> void:
	message = text
	message_time = duration

func _update_ui() -> void:
	message_time = max(0.0, message_time - get_process_delta_time())
	var region: Dictionary = REGIONS[region_index]
	hud_label.text = "地区 %d/%d：%s | 第%d天 | %s %.0fs | 木材 %d 废料 %d 食物 %d | 幸存者 %d | 核心 %.0f/%.0f" % [
		region_index + 1,
		REGIONS.size(),
		region["name"],
		day_count,
		"白天" if phase == "day" else "夜晚",
		phase_time,
		stock["wood"],
		stock["scrap"],
		stock["food"],
		survivors.size(),
		max(0.0, base_hp),
		base_max_hp,
	]
	objective_label.text = _objective_text(region)
	selected_label.text = _selected_text()
	message_label.text = message if message_time > 0.0 else ""
	for button in build_buttons:
		button.disabled = phase == "night"

func _objective_text(region: Dictionary) -> String:
	var counts := _building_counts()
	var required: Dictionary = region["required_buildings"]
	var resource_goal: Dictionary = region["resource_goal"]
	return "区域任务：守夜 %d/%d | 资源 木%d/%d 废%d/%d 食%d/%d | 建筑 墙%d/%d 塔%d/%d 避难所%d/%d%s" % [
		nights_survived_in_region,
		region["required_nights"],
		stock["wood"], resource_goal["wood"],
		stock["scrap"], resource_goal["scrap"],
		stock["food"], resource_goal["food"],
		counts.get("wall", 0), required.get("wall", 0),
		counts.get("tower", 0), required.get("tower", 0),
		counts.get("shelter", 0), required.get("shelter", 0),
		" | 按 N 前往下一区域" if _region_complete() else "",
	]

func _selected_text() -> String:
	if build_mode != "":
		return "建造模式：%s，左键放置，Esc取消" % BUILDINGS[build_mode]["name"]
	if selected_survivor == -1 or selected_survivor >= survivors.size():
		return "未选择幸存者"
	var s := survivors[selected_survivor]
	return "选中幸存者：生命 %.0f | 任务 %s" % [s["hp"], s["task"]]

func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = []
	for key in cost.keys():
		parts.append("%s:%d" % [key, cost[key]])
	return " ".join(parts)

func _direction_text(direction: String) -> String:
	match direction:
		"north":
			return "北方"
		"south":
			return "南方"
		"east":
			return "东方"
		"west":
			return "西方"
	return "未知"

func _draw() -> void:
	_draw_ground()
	_draw_resources()
	_draw_buildings()
	_draw_survivors()
	_draw_zombies()
	_draw_build_preview()
	_draw_floating_texts()
	_draw_spawn_direction()

func _draw_ground() -> void:
	draw_rect(Rect2(-MAP_HALF_SIZE, MAP_HALF_SIZE * 2.0), Color("#2f4a3a"))
	var grid_color := Color(1, 1, 1, 0.06)
	for x in range(int(-MAP_HALF_SIZE.x), int(MAP_HALF_SIZE.x) + 1, int(BUILD_GRID)):
		draw_line(Vector2(x, -MAP_HALF_SIZE.y), Vector2(x, MAP_HALF_SIZE.y), grid_color, 1.0)
	for y in range(int(-MAP_HALF_SIZE.y), int(MAP_HALF_SIZE.y) + 1, int(BUILD_GRID)):
		draw_line(Vector2(-MAP_HALF_SIZE.x, y), Vector2(MAP_HALF_SIZE.x, y), grid_color, 1.0)
	draw_rect(Rect2(-MAP_HALF_SIZE, MAP_HALF_SIZE * 2.0), Color("#1b2a22"), false, 8.0)

func _draw_resources() -> void:
	for r in resources:
		var color: Color = RESOURCE_COLORS[r["type"]]
		draw_circle(r["pos"], 20.0, color)
		draw_circle(r["pos"], 20.0, Color("#101010"), false, 2.0)

func _draw_buildings() -> void:
	for b in buildings:
		var half: Vector2 = b["size"] * 0.5
		var color: Color = Color("#90a4ae") if b["kind"] == "core" else BUILDINGS[b["kind"]]["color"]
		draw_rect(Rect2(b["pos"] - half, b["size"]), color)
		draw_rect(Rect2(b["pos"] - half, b["size"]), Color("#151515"), false, 3.0)
		var hp_ratio: float = clamp(float(b["hp"]) / float(b["max_hp"]), 0.0, 1.0)
		draw_rect(Rect2(b["pos"] + Vector2(-half.x, -half.y - 12), Vector2(b["size"].x * hp_ratio, 5)), Color("#66bb6a"))
		if b["kind"] == "tower":
			draw_circle(b["pos"], 10.0, Color("#ffd54f"))
		elif b["kind"] == "shelter":
			draw_line(b["pos"] + Vector2(-half.x, 0), b["pos"] + Vector2(half.x, 0), Color("#263238"), 2.0)
		elif b["kind"] == "core":
			draw_circle(b["pos"], 24.0, Color("#ef5350"))

func _draw_survivors() -> void:
	for i in survivors.size():
		var s := survivors[i]
		var color := Color("#42a5f5") if i != selected_survivor else Color("#fff176")
		draw_circle(s["pos"], 17.0, color)
		draw_circle(s["pos"], 17.0, Color("#0d1b2a"), false, 2.0)
		draw_line(s["pos"] + Vector2(-12, -22), s["pos"] + Vector2(-12 + 24.0 * (float(s["hp"]) / 100.0), -22), Color("#66bb6a"), 4.0)

func _draw_zombies() -> void:
	for z in zombies:
		draw_circle(z["pos"], 18.0, Color("#7cb342"))
		draw_circle(z["pos"], 18.0, Color("#263300"), false, 2.0)
		var hp_ratio: float = clamp(float(z["hp"]) / float(z["max_hp"]), 0.0, 1.0)
		draw_line(z["pos"] + Vector2(-14, -24), z["pos"] + Vector2(-14 + 28.0 * hp_ratio, -24), Color("#e53935"), 4.0)

func _draw_build_preview() -> void:
	if build_mode == "":
		return
	var pos := get_global_mouse_position()
	pos = Vector2(round(pos.x / BUILD_GRID) * BUILD_GRID, round(pos.y / BUILD_GRID) * BUILD_GRID)
	var size: Vector2 = BUILDINGS[build_mode]["size"]
	var color: Color = BUILDINGS[build_mode]["color"]
	color.a = 0.55
	draw_rect(Rect2(pos - size * 0.5, size), color)
	draw_rect(Rect2(pos - size * 0.5, size), Color("#ffffff"), false, 2.0)

func _draw_floating_texts() -> void:
	var font := ThemeDB.fallback_font
	for t in floating_texts:
		var color: Color = t["color"]
		color.a = clamp(float(t["life"]), 0.0, 1.0)
		draw_string(font, t["pos"], t["text"], HORIZONTAL_ALIGNMENT_CENTER, -1.0, 15, color)

func _draw_spawn_direction() -> void:
	if phase != "night":
		return
	var pos := Vector2.ZERO
	match current_spawn_direction:
		"north":
			pos = Vector2(0, -MAP_HALF_SIZE.y + 70)
		"south":
			pos = Vector2(0, MAP_HALF_SIZE.y - 70)
		"east":
			pos = Vector2(MAP_HALF_SIZE.x - 70, 0)
		"west":
			pos = Vector2(-MAP_HALF_SIZE.x + 70, 0)
	draw_circle(pos, 42.0, Color(0.8, 0.1, 0.1, 0.45))
	draw_circle(pos, 42.0, Color("#ef5350"), false, 5.0)
