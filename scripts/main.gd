extends Node2D

const MAP_HALF_SIZE := Vector2(1800.0, 1200.0)
const CAMP_RADIUS := 560.0
const DAY_SECONDS := 38.0
const NIGHT_SECONDS := 45.0
const SURVIVOR_SPEED := 135.0
const ZOMBIE_SPEED := 72.0
const INTERACT_RANGE := 36.0
const BUILD_GRID := 48.0
const CLICK_DRAG_THRESHOLD := 8.0
const SURVIVOR_RANGED_RANGE := 245.0
const SURVIVOR_MELEE_RANGE := 58.0
const SURVIVOR_BOW_DAMAGE := 10.0
const SURVIVOR_MELEE_DAMAGE := 16.0
const SURVIVOR_BOW_COOLDOWN := 0.9
const SURVIVOR_MELEE_COOLDOWN := 0.55
const MANUAL_COMMAND_GRACE := 2.5
const SURVIVOR_REPAIR_RANGE := 52.0
const SURVIVOR_REPAIR_AMOUNT := 18.0
const STARTING_WALL_RADIUS := 250.0
const DAY_ROAMER_MIN_DISTANCE := 920.0
const DAY_CAMP_AGGRO_DISTANCE := 190.0
const DAY_BUILDING_AGGRO_DISTANCE := 120.0
const DAY_SURVIVOR_AGGRO_DISTANCE := 170.0

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
var camp_light: PointLight2D
var failure_panel: Control
var failure_label: Label
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
var current_spawn_directions: Array[String] = []
var wave_spawned := 0
var wave_target := 0
var spawn_timer := 0.0
var message := "白天：选择幸存者，右键资源采集，数字键建造防线。"
var message_time := 5.0

var survivor_texture: Texture2D
var zombie_texture: Texture2D
var survivor_textures: Array[Texture2D] = []
var zombie_textures: Array[Texture2D] = []
var bow_texture: Texture2D
var sword_texture: Texture2D
var stock := {"wood": 80, "scrap": 55, "food": 45}
var base_max_hp := 900.0
var base_hp := base_max_hp
var build_mode := ""
var selected_survivor := -1
var selected_building := -1
var left_mouse_down := false
var dragging_camera := false
var left_drag_start_screen := Vector2.ZERO
var left_drag_total := 0.0
var game_over := false

var survivors: Array[Dictionary] = []
var resources: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var zombies: Array[Dictionary] = []
var floating_texts: Array[Dictionary] = []
var attack_tracers: Array[Dictionary] = []
var command_flashes: Array[Dictionary] = []

func _ready() -> void:
	rng.randomize()
	survivor_texture = load("res://assets/placeholder/survivor.svg")
	zombie_texture = load("res://assets/placeholder/zombie.svg")
	survivor_textures = [
		survivor_texture,
		load("res://assets/placeholder/survivor_man.svg"),
		load("res://assets/placeholder/survivor_woman.svg"),
		load("res://assets/placeholder/survivor_beard.svg"),
	]
	zombie_textures = [
		zombie_texture,
		load("res://assets/placeholder/zombie_man.svg"),
		load("res://assets/placeholder/zombie_woman.svg"),
	]
	bow_texture = load("res://assets/placeholder/bow.svg")
	sword_texture = load("res://assets/placeholder/sword.svg")
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
	camp_light = PointLight2D.new()
	camp_light.position = Vector2.ZERO
	camp_light.texture = load("res://assets/placeholder/camp_light.svg")
	camp_light.texture_scale = 1.08
	camp_light.energy = 0.0
	camp_light.color = Color("#ffd36a")
	add_child(camp_light)

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

	failure_panel = ColorRect.new()
	failure_panel.color = Color(0.02, 0.02, 0.025, 0.82)
	failure_panel.anchor_right = 1.0
	failure_panel.anchor_bottom = 1.0
	failure_panel.visible = false
	layer.add_child(failure_panel)

	var failure_box := VBoxContainer.new()
	failure_box.anchor_left = 0.5
	failure_box.anchor_top = 0.5
	failure_box.anchor_right = 0.5
	failure_box.anchor_bottom = 0.5
	failure_box.offset_left = -360.0
	failure_box.offset_top = -120.0
	failure_box.offset_right = 360.0
	failure_box.offset_bottom = 120.0
	failure_box.alignment = BoxContainer.ALIGNMENT_CENTER
	failure_box.add_theme_constant_override("separation", 16)
	failure_panel.add_child(failure_box)

	failure_label = Label.new()
	failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_label.add_theme_font_size_override("font_size", 32)
	failure_box.add_child(failure_label)

	var restart_label := Label.new()
	restart_label.text = "Press R to restart this region"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 18)
	failure_box.add_child(restart_label)

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
	game_over = false
	if failure_panel:
		failure_panel.visible = false
	zombies.clear()
	buildings.clear()
	resources.clear()
	survivors.clear()
	base_hp = base_max_hp
	selected_survivor = -1
	selected_building = -1
	build_mode = ""
	_spawn_initial_camp(survivor_count)
	_spawn_resources()
	_spawn_day_roamers()
	_show_message("抵达%s。白天收集物资和建设，夜晚守住营地核心。" % REGIONS[region_index]["name"], 6.0)

func _spawn_initial_camp(survivor_count: int) -> void:
	buildings.append(_make_building("core", Vector2.ZERO))
	_spawn_starting_perimeter()
	buildings.append(_make_building("tower", Vector2(0, -168)))
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
			"weapon": "bow",
			"command_lock": 0.0,
			"texture": survivor_textures[i % survivor_textures.size()],
			"repair": -1,
		})

func _spawn_starting_perimeter() -> void:
	var wall_positions: Array[Vector2] = [
		Vector2(-240, -240), Vector2(-192, -240), Vector2(-144, -240), Vector2(-96, -240), Vector2(-48, -240),
		Vector2(48, -240), Vector2(96, -240), Vector2(144, -240), Vector2(192, -240), Vector2(240, -240),
		Vector2(-240, 240), Vector2(-192, 240), Vector2(-144, 240), Vector2(-96, 240), Vector2(-48, 240),
		Vector2(48, 240), Vector2(96, 240), Vector2(144, 240), Vector2(192, 240), Vector2(240, 240),
		Vector2(-240, -192), Vector2(-240, -144), Vector2(-240, -96), Vector2(-240, -48), Vector2(-240, 0),
		Vector2(-240, 48), Vector2(-240, 96), Vector2(-240, 144), Vector2(-240, 192),
		Vector2(240, -192), Vector2(240, -144), Vector2(240, -96), Vector2(240, -48), Vector2(240, 0),
		Vector2(240, 48), Vector2(240, 96), Vector2(240, 144), Vector2(240, 192),
	]
	for pos in wall_positions:
		buildings.append(_make_building("wall", pos))

func _make_building(kind: String, pos: Vector2) -> Dictionary:
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
	var def: Dictionary = BUILDINGS[kind]
	return {
		"kind": kind,
		"pos": pos,
		"hp": float(def["hp"]),
		"max_hp": float(def["hp"]),
		"size": def["size"],
		"cooldown": 0.0,
		"angle": 0.0,
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

func _spawn_day_roamers() -> void:
	var count: int = 7 + region_index * 3
	for i in count:
		_spawn_zombie(_random_direction(), false, true)

func _maintain_day_roamers() -> void:
	var roaming_count: int = 0
	for z in zombies:
		if z.get("state", "attack") == "roam":
			roaming_count += 1
	var desired: int = 5 + region_index * 2
	while roaming_count < desired:
		_spawn_zombie(_random_direction(), false, true)
		roaming_count += 1

func _process(delta: float) -> void:
	if game_over:
		_update_floating_texts(delta)
		_update_command_flashes(delta)
		_update_ui()
		queue_redraw()
		return
	_update_camera(delta)
	_update_phase(delta)
	_update_survivors(delta)
	_update_buildings(delta)
	_update_zombies(delta)
	_update_floating_texts(delta)
	_update_attack_tracers(delta)
	_update_command_flashes(delta)
	_update_ui()
	_check_failure()
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
		camp_light.energy = lerp(camp_light.energy, 0.0, delta * 3.0)
		_maintain_day_roamers()
		if phase_time <= 0.0:
			_start_night()
	else:
		canvas_modulate.color = canvas_modulate.color.lerp(Color(0.12, 0.14, 0.22), delta * 1.8)
		camp_light.energy = lerp(camp_light.energy, 2.6, delta * 3.0)
		_update_wave_spawning(delta)
		if phase_time <= 0.0 and zombies.is_empty() and wave_spawned >= wave_target:
			_start_day()

func _start_night() -> void:
	phase = "night"
	phase_time = NIGHT_SECONDS
	current_spawn_directions = ["north", "east", "south", "west"]
	current_spawn_direction = "all"
	wave_spawned = 0
	wave_target = 28 + REGIONS[region_index]["threat"] * 10 + nights_survived_in_region * 8
	spawn_timer = 0.15
	for i in zombies.size():
		zombies[i]["state"] = "attack"
	_show_message("夜晚尸潮来袭：四面同时进攻，预计%d只。" % wave_target, 6.0)

func _start_day() -> void:
	phase = "day"
	phase_time = DAY_SECONDS
	current_spawn_directions.clear()
	current_spawn_direction = "none"
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
		var burst: int = min(4, wave_target - wave_spawned)
		for i in burst:
			var direction: String = current_spawn_directions[(wave_spawned + i) % current_spawn_directions.size()]
			_spawn_zombie(direction, true, false)
		wave_spawned += burst
		spawn_timer = max(0.18, 0.82 - region_index * 0.08 - nights_survived_in_region * 0.03)

func _spawn_zombie(direction: String, from_wave := true, roaming := false) -> void:
	var pos := Vector2.ZERO
	match direction:
		"north":
			pos = Vector2(rng.randf_range(-MAP_HALF_SIZE.x, MAP_HALF_SIZE.x), -MAP_HALF_SIZE.y - 120.0)
		"south":
			pos = Vector2(rng.randf_range(-MAP_HALF_SIZE.x, MAP_HALF_SIZE.x), MAP_HALF_SIZE.y + 120.0)
		"east":
			pos = Vector2(MAP_HALF_SIZE.x + 120.0, rng.randf_range(-MAP_HALF_SIZE.y, MAP_HALF_SIZE.y))
		_:
			pos = Vector2(-MAP_HALF_SIZE.x - 120.0, rng.randf_range(-MAP_HALF_SIZE.y, MAP_HALF_SIZE.y))
	if roaming:
		var angle: float = rng.randf_range(0.0, TAU)
		var distance: float = rng.randf_range(DAY_ROAMER_MIN_DISTANCE, min(MAP_HALF_SIZE.x, MAP_HALF_SIZE.y) - 80.0)
		pos = Vector2(cos(angle), sin(angle)) * distance
	var threat: int = REGIONS[region_index]["threat"]
	var hp := 45.0 + threat * 16.0 + nights_survived_in_region * 6.0
	zombies.append({
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"damage": 7.0 + threat * 2.0,
		"attack_timer": 0.0,
		"state": "roam" if roaming else "attack",
		"wander_target": _random_wander_target(pos),
		"from_wave": from_wave,
		"texture": zombie_textures[rng.randi_range(0, zombie_textures.size() - 1)],
	})

func _update_survivors(delta: float) -> void:
	for i in range(survivors.size() - 1, -1, -1):
		var s := survivors[i]
		if s["hp"] <= 0.0:
			if selected_survivor == i:
				selected_survivor = -1
			survivors.remove_at(i)
			continue
		s["command_lock"] = max(0.0, float(s.get("command_lock", 0.0)) - delta)

		if s["task"] == "gather" and phase == "day":
			_process_gather_task(s, delta)
		elif s["task"] == "attack":
			_process_attack_task(s, delta)
		elif s["task"] == "attack_move":
			_process_attack_move_task(s, delta)
		elif s["task"] == "repair":
			_process_repair_task(s, delta)
		else:
			_move_survivor_toward(s, s["target"], delta)
			if s["task"] == "idle":
				if not _auto_attack_nearest_zombie(s, delta):
					_auto_repair_damaged_building(s)
			elif phase == "night" and float(s["command_lock"]) <= 0.0:
				_auto_attack_nearest_zombie(s, delta)

		survivors[i] = s

func _process_gather_task(s: Dictionary, delta: float) -> void:
	var resource_index: int = int(s["resource"])
	if resource_index < 0 or resource_index >= resources.size():
		s["task"] = "idle"
		s["command_lock"] = 0.0
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
				s["command_lock"] = 0.0

func _process_attack_task(s: Dictionary, delta: float) -> void:
	var enemy_index: int = int(s["attack"])
	if enemy_index < 0 or enemy_index >= zombies.size():
		s["task"] = "idle"
		s["command_lock"] = 0.0
		return
	var z := zombies[enemy_index]
	var distance: float = s["pos"].distance_to(z["pos"])
	if distance < SURVIVOR_MELEE_RANGE * 1.35 and zombies.size() > 1:
		_kite_away_from_zombie(s, z["pos"], delta)
		_fire_at_zombie_without_chasing(s, enemy_index, delta)
		return
	if distance > SURVIVOR_RANGED_RANGE:
		_move_survivor_toward(s, z["pos"], delta)
		_fire_at_nearby_zombie(s, delta)
		s["weapon"] = "bow"
		return
	s["work_timer"] = float(s["work_timer"]) + delta
	if distance <= SURVIVOR_MELEE_RANGE:
		s["weapon"] = "sword"
		if s["work_timer"] >= SURVIVOR_MELEE_COOLDOWN:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - SURVIVOR_MELEE_DAMAGE
			zombies[enemy_index] = z
			attack_tracers.append({"from": s["pos"], "to": z["pos"], "life": 0.12, "kind": "melee"})
	else:
		s["weapon"] = "bow"
		if s["work_timer"] >= SURVIVOR_BOW_COOLDOWN:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - SURVIVOR_BOW_DAMAGE
			zombies[enemy_index] = z
			attack_tracers.append({"from": s["pos"], "to": z["pos"], "life": 0.18, "kind": "arrow"})

func _process_attack_move_task(s: Dictionary, delta: float) -> void:
	_move_survivor_toward(s, s["target"], delta)
	var enemy_index: int = int(s.get("attack", -1))
	if enemy_index == -1 or enemy_index >= zombies.size() or s["pos"].distance_to(zombies[enemy_index]["pos"]) > SURVIVOR_RANGED_RANGE:
		enemy_index = _nearest_zombie(s["pos"], SURVIVOR_RANGED_RANGE)
		s["attack"] = enemy_index
	if enemy_index != -1:
		_fire_at_zombie_without_chasing(s, enemy_index, delta)
	if s["pos"].distance_to(s["target"]) <= 7.0:
		s["task"] = "idle"
		s["attack"] = -1
		s["command_lock"] = 0.0

func _process_repair_task(s: Dictionary, delta: float) -> void:
	var building_index: int = int(s.get("repair", -1))
	if building_index < 0 or building_index >= buildings.size() or float(buildings[building_index]["hp"]) >= float(buildings[building_index]["max_hp"]):
		s["task"] = "idle"
		s["repair"] = -1
		return
	if _auto_attack_nearest_zombie(s, delta):
		return
	var b := buildings[building_index]
	_move_survivor_toward(s, b["pos"], delta)
	if s["pos"].distance_to(b["pos"]) <= SURVIVOR_REPAIR_RANGE:
		s["work_timer"] = float(s["work_timer"]) + delta
		if s["work_timer"] >= 0.55:
			s["work_timer"] = 0.0
			b["hp"] = min(float(b["max_hp"]), float(b["hp"]) + SURVIVOR_REPAIR_AMOUNT)
			buildings[building_index] = b
			_add_float_text("+repair", b["pos"] + Vector2(0, -42), Color("#81c784"))

func _kite_away_from_zombie(s: Dictionary, threat_pos: Vector2, delta: float) -> void:
	var away: Vector2 = s["pos"] - threat_pos
	if away.length() > 1.0:
		var target: Vector2 = s["pos"] + away.normalized() * 120.0
		_move_survivor_toward(s, target, delta)

func _fire_at_nearby_zombie(s: Dictionary, delta: float) -> bool:
	var enemy_index: int = _nearest_zombie(s["pos"], SURVIVOR_RANGED_RANGE)
	if enemy_index == -1:
		return false
	_fire_at_zombie_without_chasing(s, enemy_index, delta)
	return true

func _fire_at_zombie_without_chasing(s: Dictionary, enemy_index: int, delta: float) -> void:
	if enemy_index < 0 or enemy_index >= zombies.size():
		return
	var z := zombies[enemy_index]
	var distance: float = s["pos"].distance_to(z["pos"])
	s["work_timer"] = float(s["work_timer"]) + delta
	if distance <= SURVIVOR_MELEE_RANGE:
		s["weapon"] = "sword"
		if s["work_timer"] >= SURVIVOR_MELEE_COOLDOWN:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - SURVIVOR_MELEE_DAMAGE
			zombies[enemy_index] = z
			attack_tracers.append({"from": s["pos"], "to": z["pos"], "life": 0.12, "kind": "melee"})
	elif distance <= SURVIVOR_RANGED_RANGE:
		s["weapon"] = "bow"
		if s["work_timer"] >= SURVIVOR_BOW_COOLDOWN:
			s["work_timer"] = 0.0
			z["hp"] = float(z["hp"]) - SURVIVOR_BOW_DAMAGE
			zombies[enemy_index] = z
			attack_tracers.append({"from": s["pos"], "to": z["pos"], "life": 0.18, "kind": "arrow"})

func _auto_attack_nearest_zombie(s: Dictionary, delta: float) -> bool:
	var enemy_index := _nearest_zombie(s["pos"], SURVIVOR_RANGED_RANGE)
	if enemy_index == -1:
		return false
	s["task"] = "attack"
	s["attack"] = enemy_index
	_process_attack_task(s, delta)
	return true

func _auto_repair_damaged_building(s: Dictionary) -> bool:
	var building_index: int = _nearest_damaged_building(s["pos"], 520.0)
	if building_index == -1:
		return false
	s["task"] = "repair"
	s["repair"] = building_index
	s["work_timer"] = 0.0
	return true

func _move_survivor_toward(s: Dictionary, target: Vector2, delta: float) -> void:
	var offset: Vector2 = target - s["pos"]
	if offset.length() > 5.0:
		s["pos"] += offset.normalized() * SURVIVOR_SPEED * delta

func _update_buildings(delta: float) -> void:
	for i in range(buildings.size() - 1, -1, -1):
		var b := buildings[i]
		if b["hp"] <= 0.0:
			if selected_building == i:
				selected_building = -1
			if b["kind"] == "core":
				_show_message("营地核心被摧毁。按 R 重开当前地区。", 999.0)
			buildings.remove_at(i)
			continue
		if b["kind"] == "tower":
			b["cooldown"] = max(0.0, float(b["cooldown"]) - delta)
			if float(b["cooldown"]) <= 0.0:
				var enemy_index := _nearest_zombie(b["pos"], float(BUILDINGS["tower"]["range"]))
				if enemy_index != -1:
					var aim: Vector2 = zombies[enemy_index]["pos"] - b["pos"]
					b["angle"] = aim.angle()
					zombies[enemy_index]["hp"] = float(zombies[enemy_index]["hp"]) - float(BUILDINGS["tower"]["damage"])
					b["cooldown"] = float(BUILDINGS["tower"]["cooldown"])
					attack_tracers.append({"from": b["pos"], "to": zombies[enemy_index]["pos"], "life": 0.16})
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
		if phase == "day" and z.get("state", "attack") == "roam":
			if _should_day_zombie_attack(z):
				z["state"] = "attack"
				_add_float_text("发现营地", z["pos"], Color("#ff8a65"))
			else:
				_update_roaming_zombie(z, delta)
				zombies[i] = z
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

func _should_day_zombie_attack(z: Dictionary) -> bool:
	if z["pos"].length() <= STARTING_WALL_RADIUS + DAY_CAMP_AGGRO_DISTANCE:
		return true
	for b in buildings:
		if b["kind"] != "core" and z["pos"].distance_to(b["pos"]) <= DAY_BUILDING_AGGRO_DISTANCE:
			return true
	for s in survivors:
		if z["pos"].distance_to(s["pos"]) <= DAY_SURVIVOR_AGGRO_DISTANCE:
			return true
	return false

func _update_roaming_zombie(z: Dictionary, delta: float) -> void:
	var target: Vector2 = z["wander_target"]
	if z["pos"].distance_to(target) <= 24.0:
		z["wander_target"] = _random_wander_target(z["pos"])
		target = z["wander_target"]
	if target.length() < DAY_ROAMER_MIN_DISTANCE:
		z["wander_target"] = _random_wander_target(z["pos"])
		target = z["wander_target"]
	var direction: Vector2 = target - z["pos"]
	if direction.length() > 1.0:
		z["pos"] += direction.normalized() * (ZOMBIE_SPEED * 0.45) * delta

func _random_wander_target(from_pos: Vector2) -> Vector2:
	var angle: float = rng.randf_range(0.0, TAU)
	var distance: float = rng.randf_range(DAY_ROAMER_MIN_DISTANCE, min(MAP_HALF_SIZE.x, MAP_HALF_SIZE.y) - 80.0)
	var target: Vector2 = Vector2(cos(angle), sin(angle)) * distance
	if target.distance_to(from_pos) < 180.0:
		target += Vector2.RIGHT.rotated(angle + PI * 0.5) * 220.0
	return target

func _random_direction() -> String:
	var directions: Array[String] = ["north", "east", "south", "west"]
	return directions[rng.randi_range(0, directions.size() - 1)]

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

func _nearest_damaged_building(pos: Vector2, max_range: float) -> int:
	var best := -1
	var best_distance := max_range
	for i in buildings.size():
		if float(buildings[i]["hp"]) >= float(buildings[i]["max_hp"]):
			continue
		var d := pos.distance_to(buildings[i]["pos"])
		if d < best_distance:
			best = i
			best_distance = d
	return best

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.zoom = (camera.zoom * 0.9).clamp(Vector2(0.45, 0.45), Vector2(1.6, 1.6))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.45, 0.45), Vector2(1.6, 1.6))
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				left_mouse_down = true
				dragging_camera = false
				left_drag_start_screen = event.position
				left_drag_total = 0.0
			else:
				if left_mouse_down and not dragging_camera:
					_handle_left_click(get_global_mouse_position())
				left_mouse_down = false
				dragging_camera = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(get_global_mouse_position())
	elif event is InputEventMouseMotion and left_mouse_down:
		left_drag_total += event.relative.length()
		if left_drag_total >= CLICK_DRAG_THRESHOLD:
			dragging_camera = true
		if dragging_camera:
			camera.position -= event.relative * camera.zoom
			camera.position.x = clamp(camera.position.x, -MAP_HALF_SIZE.x, MAP_HALF_SIZE.x)
			camera.position.y = clamp(camera.position.y, -MAP_HALF_SIZE.y, MAP_HALF_SIZE.y)
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
			KEY_H:
				_heal_selected_survivor()
			KEY_R:
				if _core_destroyed() or survivors.is_empty():
					_start_region(region_index, 3)

func _handle_left_click(world_pos: Vector2) -> void:
	if build_mode != "":
		_place_building(world_pos)
		return
	selected_building = -1
	selected_survivor = _survivor_at(world_pos)
	if selected_survivor != -1:
		_show_message("已选择幸存者。右键资源、敌人或地面下达命令。", 2.5)
		return
	selected_building = _building_at(world_pos)
	if selected_building != -1:
		_show_message("已选择建筑。墙和塔会自动防守，继续建造可以扩展营地。", 2.5)

func _handle_right_click(world_pos: Vector2) -> void:
	var resource_index := _resource_at(world_pos)
	var enemy_index := _zombie_at(world_pos)
	var building_index := _building_at(world_pos)
	if resource_index != -1:
		_add_command_flash(resources[resource_index]["pos"], Color("#66bb6a"), 46.0, "gather")
	elif enemy_index != -1:
		_add_command_flash(zombies[enemy_index]["pos"], Color("#ef5350"), 52.0, "attack")
	elif building_index != -1:
		_add_command_flash(buildings[building_index]["pos"], Color("#ffd54f"), 54.0, "building")
	else:
		_add_command_flash(world_pos, Color("#64b5f6"), 34.0, "move")
	if selected_survivor == -1 or selected_survivor >= survivors.size():
		_show_message("先左键选择幸存者，再右键下命令。", 2.0)
		return
	if resource_index != -1 and phase == "day":
		survivors[selected_survivor]["task"] = "gather"
		survivors[selected_survivor]["resource"] = resource_index
		survivors[selected_survivor]["attack"] = -1
		survivors[selected_survivor]["work_timer"] = 0.0
		survivors[selected_survivor]["command_lock"] = MANUAL_COMMAND_GRACE
		_show_message("幸存者开始采集资源。", 2.0)
	elif enemy_index != -1:
		survivors[selected_survivor]["task"] = "attack"
		survivors[selected_survivor]["attack"] = enemy_index
		survivors[selected_survivor]["work_timer"] = 0.0
		survivors[selected_survivor]["command_lock"] = 0.0
		_show_message("幸存者攻击目标。", 2.0)
	elif building_index != -1:
		if float(buildings[building_index]["hp"]) < float(buildings[building_index]["max_hp"]):
			survivors[selected_survivor]["task"] = "repair"
			survivors[selected_survivor]["repair"] = building_index
			survivors[selected_survivor]["work_timer"] = 0.0
			_show_message("幸存者前往维修建筑。", 2.0)
	else:
		survivors[selected_survivor]["task"] = "attack_move"
		survivors[selected_survivor]["target"] = world_pos
		survivors[selected_survivor]["resource"] = -1
		survivors[selected_survivor]["attack"] = _nearest_zombie(survivors[selected_survivor]["pos"], SURVIVOR_RANGED_RANGE)
		survivors[selected_survivor]["work_timer"] = 0.0
		survivors[selected_survivor]["command_lock"] = MANUAL_COMMAND_GRACE
		_show_message("幸存者移动到指定位置，并边走边射击。", 2.0)

func _set_build_mode(kind: String) -> void:
	build_mode = kind
	_show_message("放置%s：左键确认，Esc取消。成本 %s" % [BUILDINGS[kind]["name"], _cost_text(BUILDINGS[kind]["cost"])], 4.0)

func _place_building(world_pos: Vector2) -> void:
	var pos := Vector2(round(world_pos.x / BUILD_GRID) * BUILD_GRID, round(world_pos.y / BUILD_GRID) * BUILD_GRID)
	if pos.length() < 110.0:
		_show_message("离营地核心太近。", 2.0)
		return
	if pos.length() > CAMP_RADIUS:
		_show_message("只能在营地区域内建造。先守住当前营地，再去下一个地区。", 3.0)
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
			"weapon": "bow",
			"command_lock": 0.0,
			"texture": survivor_textures[survivors.size() % survivor_textures.size()],
			"repair": -1,
		})
		_show_message("避难所接纳了一名新幸存者。", 4.0)

func _heal_selected_survivor() -> void:
	if selected_survivor == -1 or selected_survivor >= survivors.size():
		_show_message("先选择一名幸存者，再按 H 使用食物治疗。", 2.5)
		return
	if int(stock["food"]) < 8:
		_show_message("食物不足，治疗需要 8 食物。", 2.5)
		return
	if float(survivors[selected_survivor]["hp"]) >= 100.0:
		_show_message("这名幸存者状态良好，不需要治疗。", 2.5)
		return
	stock["food"] = int(stock["food"]) - 8
	survivors[selected_survivor]["hp"] = min(100.0, float(survivors[selected_survivor]["hp"]) + 35.0)
	_add_float_text("+治疗", survivors[selected_survivor]["pos"], Color("#f8bbd0"))
	_show_message("消耗 8 食物，为幸存者恢复生命。", 3.0)

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

func _check_failure() -> void:
	if game_over:
		return
	if _core_destroyed():
		_trigger_failure("Camp core destroyed")
	elif survivors.is_empty():
		_trigger_failure("All survivors are dead")

func _trigger_failure(reason: String) -> void:
	game_over = true
	build_mode = ""
	selected_survivor = -1
	selected_building = -1
	if failure_panel:
		failure_panel.visible = true
	if failure_label:
		failure_label.text = "FAILED\n%s" % reason
	_show_message("任务失败。按 R 重开当前地区。", 999.0)

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

func _add_float_text(text: String, pos: Vector2, color: Color) -> void:
	floating_texts.append({"text": text, "pos": pos, "color": color, "life": 1.1})

func _add_command_flash(pos: Vector2, color: Color, radius: float, text: String) -> void:
	command_flashes.append({"pos": pos, "color": color, "radius": radius, "text": text, "life": 0.55})

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
		if selected_building != -1 and selected_building < buildings.size():
			var b: Dictionary = buildings[selected_building]
			var building_name: String = "营地核心" if b["kind"] == "core" else BUILDINGS[b["kind"]]["name"]
			return "选中建筑：%s | 生命 %.0f/%.0f" % [building_name, b["hp"], b["max_hp"]]
		return "未选择目标。左键点选，按住左键拖拽视野，右键下命令。"
	var s := survivors[selected_survivor]
	return "选中幸存者：生命 %.0f | 任务 %s | 武器 %s | 按 H 消耗食物回血" % [s["hp"], s["task"], "弓" if s.get("weapon", "bow") == "bow" else "刀"]

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
	_draw_command_flashes()
	_draw_attack_tracers()
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
	draw_circle(Vector2.ZERO, CAMP_RADIUS, Color(0.18, 0.36, 0.28, 0.22))
	draw_circle(Vector2.ZERO, CAMP_RADIUS, Color("#8bc34a"), false, 4.0)
	draw_circle(Vector2.ZERO, STARTING_WALL_RADIUS, Color(0.55, 0.68, 0.36, 0.18))
	draw_circle(Vector2.ZERO, STARTING_WALL_RADIUS, Color("#cddc39"), false, 3.0)
	if phase == "night":
		draw_circle(Vector2.ZERO, 430.0, Color(1.0, 0.78, 0.32, 0.24))
		draw_circle(Vector2.ZERO, 270.0, Color(1.0, 0.91, 0.55, 0.22))
		draw_circle(Vector2.ZERO, 76.0, Color(1.0, 0.84, 0.34, 0.42))
		draw_circle(Vector2.ZERO, 430.0, Color("#ffca28"), false, 3.0)
	draw_circle(Vector2.ZERO, 120.0, Color(0.85, 0.2, 0.16, 0.08))

func _draw_resources() -> void:
	for r in resources:
		var color: Color = RESOURCE_COLORS[r["type"]]
		var pos: Vector2 = r["pos"]
		if r["type"] == "wood":
			draw_rect(Rect2(pos + Vector2(-8, -24), Vector2(16, 44)), Color("#6d4c41"))
			draw_circle(pos + Vector2(0, -22), 22.0, color)
			draw_circle(pos + Vector2(0, -22), 22.0, Color("#1b2a22"), false, 2.0)
		elif r["type"] == "scrap":
			draw_rect(Rect2(pos + Vector2(-22, -14), Vector2(44, 28)), color)
			draw_line(pos + Vector2(-18, -10), pos + Vector2(18, 10), Color("#37474f"), 4.0)
			draw_line(pos + Vector2(-18, 10), pos + Vector2(18, -10), Color("#37474f"), 4.0)
		else:
			draw_circle(pos, 19.0, color)
			draw_circle(pos + Vector2(7, -8), 7.0, Color("#ef5350"))
			draw_line(pos + Vector2(3, -19), pos + Vector2(14, -28), Color("#66bb6a"), 3.0)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-22, 34), "%s %d" % [r["type"], r["amount"]], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("#dfe8df"))

func _draw_buildings() -> void:
	for i in buildings.size():
		var b := buildings[i]
		var half: Vector2 = b["size"] * 0.5
		var color: Color = Color("#90a4ae") if b["kind"] == "core" else BUILDINGS[b["kind"]]["color"]
		draw_rect(Rect2(b["pos"] - half, b["size"]), color)
		draw_rect(Rect2(b["pos"] - half, b["size"]), Color("#151515"), false, 3.0)
		if i == selected_building:
			draw_rect(Rect2(b["pos"] - half - Vector2(5, 5), b["size"] + Vector2(10, 10)), Color("#fff176"), false, 4.0)
		var hp_ratio: float = clamp(float(b["hp"]) / float(b["max_hp"]), 0.0, 1.0)
		draw_rect(Rect2(b["pos"] + Vector2(-half.x, -half.y - 12), Vector2(b["size"].x * hp_ratio, 5)), Color("#66bb6a"))
		if b["kind"] == "tower":
			draw_circle(b["pos"], 10.0, Color("#ffd54f"))
			var barrel_end: Vector2 = b["pos"] + Vector2.RIGHT.rotated(float(b["angle"])) * 38.0
			draw_line(b["pos"], barrel_end, Color("#263238"), 7.0)
			draw_circle(b["pos"], float(BUILDINGS["tower"]["range"]), Color(1.0, 0.84, 0.25, 0.06), false, 2.0)
		elif b["kind"] == "shelter":
			draw_line(b["pos"] + Vector2(-half.x, 0), b["pos"] + Vector2(half.x, 0), Color("#263238"), 2.0)
		elif b["kind"] == "core":
			draw_circle(b["pos"], 24.0, Color("#ef5350"))

func _draw_attack_tracers() -> void:
	for tracer in attack_tracers:
		var alpha: float = clamp(float(tracer["life"]) / 0.16, 0.0, 1.0)
		if tracer.get("kind", "tower") == "melee":
			draw_line(tracer["from"], tracer["to"], Color(0.9, 0.95, 1.0, alpha), 8.0)
		elif tracer.get("kind", "tower") == "arrow":
			draw_line(tracer["from"], tracer["to"], Color(0.76, 0.48, 0.2, alpha), 3.0)
		else:
			draw_line(tracer["from"], tracer["to"], Color(1.0, 0.9, 0.25, alpha), 5.0)

func _draw_command_flashes() -> void:
	var font := ThemeDB.fallback_font
	for flash in command_flashes:
		var alpha: float = clamp(float(flash["life"]) / 0.55, 0.0, 1.0)
		var color: Color = flash["color"]
		color.a = alpha
		draw_circle(flash["pos"], float(flash["radius"]), Color(color.r, color.g, color.b, 0.18 * alpha))
		draw_circle(flash["pos"], float(flash["radius"]), color, false, 5.0)
		draw_string(font, flash["pos"] + Vector2(-24, -float(flash["radius"]) - 8), flash["text"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)

func _draw_survivors() -> void:
	for i in survivors.size():
		var s := survivors[i]
		var pos: Vector2 = s["pos"]
		var rect := Rect2(pos - Vector2(24, 24), Vector2(48, 48))
		var texture: Texture2D = s.get("texture", survivor_texture)
		if texture:
			draw_texture_rect(texture, rect, false)
		else:
			draw_circle(pos, 17.0, Color("#42a5f5"))
		var outline := Color("#fff176") if i == selected_survivor else Color("#0d1b2a")
		draw_circle(pos, 25.0, outline, false, 3.0)
		_draw_weapon_badge(pos, s.get("weapon", "bow"))
		draw_line(s["pos"] + Vector2(-12, -22), s["pos"] + Vector2(-12 + 24.0 * (float(s["hp"]) / 100.0), -22), Color("#66bb6a"), 4.0)

func _draw_weapon_badge(pos: Vector2, weapon: String) -> void:
	var badge_rect := Rect2(pos + Vector2(9, -31), Vector2(22, 22))
	draw_rect(badge_rect.grow(2), Color("#101820"))
	if weapon == "sword" and sword_texture:
		draw_texture_rect(sword_texture, badge_rect, false)
	elif bow_texture:
		draw_texture_rect(bow_texture, badge_rect, false)
	else:
		draw_circle(badge_rect.get_center(), 9.0, Color("#ffc107"))

func _draw_zombies() -> void:
	for z in zombies:
		var pos: Vector2 = z["pos"]
		var rect := Rect2(pos - Vector2(24, 24), Vector2(48, 48))
		if z.get("state", "attack") == "roam":
			draw_circle(pos, 34.0, Color(0.45, 0.75, 0.25, 0.12))
		var texture: Texture2D = z.get("texture", zombie_texture)
		if texture:
			draw_texture_rect(texture, rect, false)
		else:
			draw_circle(pos, 18.0, Color("#7cb342"))
		var ring := Color("#9ccc65") if z.get("state", "attack") == "roam" else Color("#ef5350")
		draw_circle(pos, 25.0, ring, false, 3.0)
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
	for direction in current_spawn_directions:
		var pos := Vector2.ZERO
		match direction:
			"north":
				pos = Vector2(0, -MAP_HALF_SIZE.y + 70)
			"south":
				pos = Vector2(0, MAP_HALF_SIZE.y - 70)
			"east":
				pos = Vector2(MAP_HALF_SIZE.x - 70, 0)
			"west":
				pos = Vector2(-MAP_HALF_SIZE.x + 70, 0)
		draw_circle(pos, 54.0, Color(0.8, 0.1, 0.1, 0.5))
		draw_circle(pos, 54.0, Color("#ef5350"), false, 6.0)
		draw_line(pos, Vector2.ZERO, Color(0.9, 0.1, 0.1, 0.25), 4.0)
