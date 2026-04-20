class_name HudController
extends RefCounted

var hud_label: Label
var objective_label: Label
var selected_label: Label
var message_label: Label
var build_buttons: Array[Button] = []
var failure_panel: Control
var failure_label: Label

func setup(owner: Node, build_callback: Callable) -> void:
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

	message_label = Label.new()
	message_label.add_theme_font_size_override("font_size", 16)
	root.add_child(message_label)

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
