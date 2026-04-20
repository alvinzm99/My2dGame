class_name HudController
extends RefCounted

var hud_label: Label
var objective_label: Label
var selected_label: Label
var message_label: Label
var build_buttons: Array[Button] = []
var failure_panel: Control
var failure_label: Label
var building_panel: PanelContainer
var building_title: Label
var building_stats: Label
var staff_slot: Button
var survivor_list: VBoxContainer
var assign_callback: Callable

func setup(owner: Node, build_callback: Callable, staff_callback: Callable) -> void:
	assign_callback = staff_callback
	var layer := CanvasLayer.new()
	owner.add_child(layer)

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
	_add_build_button(build_bar, "1 墙", "wall", build_callback)
	_add_build_button(build_bar, "2 塔", "tower", build_callback)
	_add_build_button(build_bar, "3 避难所", "shelter", build_callback)
	_add_build_button(build_bar, "4 伐木场", "lumberyard", build_callback)
	_add_build_button(build_bar, "5 工坊", "workshop", build_callback)
	_add_build_button(build_bar, "6 瞭望塔", "lookout", build_callback)

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	root.add_child(message_label)

	_setup_building_panel(layer)
	_setup_failure_panel(layer)

func _add_build_button(parent: HBoxContainer, text: String, kind: String, build_callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(96, 34)
	button.pressed.connect(func() -> void:
		build_callback.call(kind)
	)
	parent.add_child(button)
	build_buttons.append(button)

func _setup_failure_panel(layer: CanvasLayer) -> void:
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

func _setup_building_panel(layer: CanvasLayer) -> void:
	building_panel = PanelContainer.new()
	building_panel.anchor_left = 1.0
	building_panel.anchor_right = 1.0
	building_panel.offset_left = -330.0
	building_panel.offset_top = 96.0
	building_panel.offset_right = -18.0
	building_panel.offset_bottom = 430.0
	building_panel.visible = false
	layer.add_child(building_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	building_panel.add_child(box)

	building_title = Label.new()
	building_title.add_theme_font_size_override("font_size", 20)
	box.add_child(building_title)

	building_stats = Label.new()
	building_stats.add_theme_font_size_override("font_size", 14)
	box.add_child(building_stats)

	staff_slot = Button.new()
	staff_slot.custom_minimum_size = Vector2(260, 36)
	staff_slot.pressed.connect(_toggle_survivor_list)
	box.add_child(staff_slot)

	survivor_list = VBoxContainer.new()
	survivor_list.add_theme_constant_override("separation", 4)
	survivor_list.visible = false
	box.add_child(survivor_list)

func set_texts(hud_text: String, objective_text: String, selected_text: String, message_text: String) -> void:
	hud_label.text = hud_text
	objective_label.text = objective_text
	selected_label.text = selected_text
	message_label.text = message_text

func set_build_disabled(disabled: bool) -> void:
	for button in build_buttons:
		button.disabled = disabled

func show_failure(reason: String) -> void:
	failure_panel.visible = true
	failure_label.text = "FAILED\n%s" % reason

func hide_failure() -> void:
	failure_panel.visible = false

func update_building_panel(selected_building: int, buildings: Array[Dictionary], survivors: Array[Dictionary]) -> void:
	if selected_building < 0 or selected_building >= buildings.size():
		building_panel.visible = false
		return
	var b: Dictionary = buildings[selected_building]
	var def: Dictionary = GameConfig.BUILDINGS.get(b["kind"], {"name": "Camp Core"})
	building_panel.visible = true
	building_title.text = "%s" % def["name"]
	building_stats.text = "HP %.0f/%.0f\nMode: %s" % [
		b["hp"],
		b["max_hp"],
		def.get("staff_mode", "none"),
	]
	if not def.has("staff_mode"):
		staff_slot.text = "No staff slot"
		staff_slot.disabled = true
		survivor_list.visible = false
		return
	staff_slot.disabled = false
	var staff_index: int = int(b.get("staff", -1))
	if staff_index >= 0 and staff_index < survivors.size():
		staff_slot.text = "Staffed: Survivor %d (%s)" % [staff_index + 1, survivors[staff_index].get("behavior", "assigned")]
	else:
		staff_slot.text = "+ Assign survivor"
	if survivor_list.visible:
		_populate_survivor_list(survivors)

func _toggle_survivor_list() -> void:
	if staff_slot.disabled:
		return
	survivor_list.visible = not survivor_list.visible

func _populate_survivor_list(survivors: Array[Dictionary]) -> void:
	for child in survivor_list.get_children():
		child.queue_free()
	for i in survivors.size():
		var button := Button.new()
		button.text = "Survivor %d | HP %.0f | %s" % [i + 1, survivors[i]["hp"], survivors[i].get("behavior", "idle")]
		button.pressed.connect(func() -> void:
			assign_callback.call(i)
			survivor_list.visible = false
		)
		survivor_list.add_child(button)
