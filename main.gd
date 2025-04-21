extends Control

@onready var left_panel : VBoxContainer = $VBoxContainer/PanelsContainer/LeftPanel
@onready var right_panel : VBoxContainer = $VBoxContainer/PanelsContainer/RightPanel
@onready var status_label : HBoxContainer = $VBoxContainer/StatusLabel

var active_panel : String= "left"  # or "right"

func _ready():
	left_panel.set_path(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))
	right_panel.set_path(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))

	left_panel.grab_focus()
	left_panel.is_focused = true
	right_panel.is_focused = false

func _unhandled_input(event):
	if event.is_action_pressed("ui_focus_next"):  # remap to Tab or L/R bumper
		toggle_active_panel()
	elif event.is_action_pressed("ui_cancel"):
		get_active_panel().go_up()
	elif event.is_action_pressed("ui_text_backspace"):
		get_active_panel().go_up()

func toggle_active_panel():
	if active_panel == "left":
		active_panel = "right"
		left_panel.is_focused = false
		right_panel.is_focused = true
		right_panel.grab_focus()
	else:
		active_panel = "left"
		right_panel.is_focused = false
		left_panel.is_focused = true
		left_panel.grab_focus()

func get_active_panel() -> VBoxContainer:
	return left_panel if active_panel == "left" else right_panel
