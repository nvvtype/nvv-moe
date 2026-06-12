class_name FightMainMenu
extends Control

## Template main menu: VERSUS (local 2P), TRAINING, QUIT.
## Set this scene (main_menu.tscn) as the project's main scene.

const FIGHT_SCENE := "res://addons/fightengine/template/fight_scene.tscn"


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = Color(0.07, 0.06, 0.1)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 18)
	add_child(box)

	var title := Label.new()
	title.text = "FIGHT ENGINE"
	title.add_theme_font_size_override("font_size", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "kusoge edition"
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.modulate = Color(1, 1, 1, 0.5)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	box.add_child(_spacer(24))
	var versus := _menu_button(box, "VERSUS")
	var training := _menu_button(box, "TRAINING")
	var quit := _menu_button(box, "QUIT")

	versus.pressed.connect(_start_fight.bind(&"versus"))
	training.pressed.connect(_start_fight.bind(&"training"))
	quit.pressed.connect(func() -> void: get_tree().quit())

	var controls := Label.new()
	controls.text = "P1: WASD move · U I O P = L M H S        P2: arrows · numpad 4 5 6 + = L M H S"
	controls.add_theme_font_size_override("font_size", 14)
	controls.modulate = Color(1, 1, 1, 0.4)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_spacer(24))
	box.add_child(controls)

	versus.grab_focus()


func _menu_button(parent: Container, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(280, 48)
	button.add_theme_font_size_override("font_size", 24)
	parent.add_child(button)
	return button


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


func _start_fight(mode: StringName) -> void:
	FightScene.next_mode = mode
	get_tree().change_scene_to_file(FIGHT_SCENE)
