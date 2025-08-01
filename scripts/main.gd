extends Control

@onready var left_panel : VBoxContainer = $Panel/VBoxContainer/PanelsContainer/LeftPanel
@onready var right_panel : VBoxContainer = $Panel/VBoxContainer/PanelsContainer/RightPanel
@onready var status_label : HBoxContainer = $Panel/VBoxContainer/StatusLabel

var active_panel : String= "left"

func _ready() -> void:
	left_panel.set_path(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))
	right_panel.set_path(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))

	toggle_active_panel()

func _unhandled_input(event) -> void:
	if event.is_action_pressed("ui_focus_next"):  # remap to Tab or L/R bumper
		toggle_active_panel()
	elif event.is_action_pressed("ui_cancel"):
		get_active_panel().go_up()
	elif event.is_action_pressed("ui_text_backspace"):
		get_active_panel().go_up()

func toggle_active_panel() -> void:
	if active_panel == "left":
		active_panel = "right"
		left_panel.modulate  = Color(0.7, 0.7, 0.7)
		left_panel.is_focused = false
		right_panel.modulate = Color(1, 1, 1)
		right_panel.is_focused = true
		right_panel.grab_focus()
	else:
		active_panel = "left"
		right_panel.modulate = Color(0.7, 0.7, 0.7)
		right_panel.is_focused = false
		left_panel.modulate  = Color(1, 1, 1)
		left_panel.is_focused = true
		left_panel.grab_focus()

func get_active_panel() -> VBoxContainer:
	return left_panel if active_panel == "left" else right_panel
