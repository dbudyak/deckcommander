extends Control

## Main controller for DeckCommander dual-panel file manager.

@onready var left_panel: FilePanel = $Panel/VBoxContainer/PanelsContainer/LeftPanel
@onready var right_panel: FilePanel = $Panel/VBoxContainer/PanelsContainer/RightPanel
@onready var status_label: Label = $Panel/VBoxContainer/StatusBar/StatusLabel
@onready var hints_label: Label = $Panel/VBoxContainer/StatusBar/HintsLabel
@onready var confirm_dialog: ConfirmationDialog = $ConfirmDialog
@onready var input_dialog: Window = $InputDialog
@onready var input_line_edit: LineEdit = $InputDialog/VBoxContainer/LineEdit
@onready var input_ok_button: Button = $InputDialog/VBoxContainer/HBoxContainer/OkButton
@onready var input_cancel_button: Button = $InputDialog/VBoxContainer/HBoxContainer/CancelButton
@onready var panel_container: HBoxContainer = $Panel/VBoxContainer/PanelsContainer

var active_panel: String = "left"
var pending_operation: String = ""
var pending_files: Array[String] = []
var using_gamepad: bool = false

# Navigation repeat
var nav_repeat_timer: float = 0.0
var nav_repeat_delay: float = 0.4  # Initial delay before repeat starts
var nav_repeat_rate: float = 0.08  # Time between repeats
var nav_direction: int = 0  # -1 = up, 1 = down, 0 = none
var nav_repeating: bool = false

# Colors for the gaming aesthetic
const ACTIVE_COLOR := Color(1.0, 1.0, 1.0)
const INACTIVE_COLOR := Color(0.5, 0.5, 0.6)
const ACCENT_COLOR := Color(0.0, 0.85, 1.0)  # Cyan
const ACCENT_COLOR_2 := Color(1.0, 0.4, 0.7)  # Pink/Magenta


func _ready() -> void:
	# Initialize panels with home directory
	var home := _get_start_directory()
	left_panel.set_path(home)
	right_panel.set_path(home)

	# Connect panel focus signals - THIS IS KEY FOR PROPER FOCUS TRACKING
	left_panel.panel_focused.connect(_on_left_panel_focused)
	right_panel.panel_focused.connect(_on_right_panel_focused)

	left_panel.selection_changed.connect(_on_selection_changed)
	right_panel.selection_changed.connect(_on_selection_changed)

	confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	confirm_dialog.canceled.connect(_on_confirm_dialog_canceled)

	input_ok_button.pressed.connect(_on_input_confirmed)
	input_cancel_button.pressed.connect(_on_input_canceled)
	input_line_edit.text_submitted.connect(_on_input_text_submitted)

	# Set initial focus to left panel
	_set_active_panel("left")
	_update_status()
	_update_hints()


func _process(delta: float) -> void:
	# Handle navigation repeat when holding down/up
	if nav_direction != 0:
		nav_repeat_timer += delta
		var threshold := nav_repeat_delay if not nav_repeating else nav_repeat_rate
		if nav_repeat_timer >= threshold:
			nav_repeat_timer = 0.0
			nav_repeating = true
			_move_focus(nav_direction)


func _input(event: InputEvent) -> void:
	# Detect if using gamepad or keyboard
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not using_gamepad:
			using_gamepad = true
			_update_hints()
	elif event is InputEventKey:
		if using_gamepad:
			using_gamepad = false
			_update_hints()

	# Track navigation key hold state
	if event.is_action_pressed("ui_down"):
		nav_direction = 1
		nav_repeat_timer = 0.0
		nav_repeating = false
	elif event.is_action_pressed("ui_up"):
		nav_direction = -1
		nav_repeat_timer = 0.0
		nav_repeating = false
	elif event.is_action_released("ui_down") or event.is_action_released("ui_up"):
		nav_direction = 0
		nav_repeating = false

	# Handle Tab/panel switch here in _input so it's not consumed by focus system
	if not confirm_dialog.visible and not input_dialog.visible:
		if event.is_action_pressed("ui_focus_next"):
			_toggle_active_panel()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if confirm_dialog.visible or input_dialog.visible:
		return

	# Handle actions (Tab is handled in _input to intercept before focus system)
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_text_backspace"):
		_get_active_panel().go_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("select_file"):
		_get_active_panel().toggle_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("copy_file"):
		_copy_files()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_file"):
		_move_files()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("delete_file"):
		_delete_files()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("select_all"):
		_get_active_panel().select_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("refresh"):
		_refresh_panels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rename_file"):
		_rename_file()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("create_dir"):
		_create_directory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_hidden"):
		_get_active_panel()._on_hidden_pressed()
		get_viewport().set_input_as_handled()


func _on_left_panel_focused() -> void:
	if active_panel != "left":
		_set_active_panel("left")


func _on_right_panel_focused() -> void:
	if active_panel != "right":
		_set_active_panel("right")


func _set_active_panel(panel_name: String) -> void:
	active_panel = panel_name

	if panel_name == "left":
		left_panel.modulate = ACTIVE_COLOR
		left_panel.is_focused = true
		right_panel.modulate = INACTIVE_COLOR
		right_panel.is_focused = false
	else:
		right_panel.modulate = ACTIVE_COLOR
		right_panel.is_focused = true
		left_panel.modulate = INACTIVE_COLOR
		left_panel.is_focused = false

	_update_status()


func _toggle_active_panel() -> void:
	var new_panel := "right" if active_panel == "left" else "left"
	_set_active_panel(new_panel)
	_get_active_panel().focus_panel()


func _get_active_panel() -> FilePanel:
	return left_panel if active_panel == "left" else right_panel


func _get_inactive_panel() -> FilePanel:
	return right_panel if active_panel == "left" else left_panel


func _on_selection_changed(_selected: Array) -> void:
	_update_status()


func _update_status() -> void:
	var panel := _get_active_panel()
	var selected := panel.get_selected_files()

	if selected.size() > 0:
		status_label.text = "✨ %d item(s) selected" % selected.size()
	else:
		var focused := panel.get_focused_file()
		if not focused.is_empty():
			status_label.text = "► " + focused
		else:
			status_label.text = "🎮 Ready"


func _update_hints() -> void:
	if using_gamepad:
		hints_label.text = "Ⓧ Sel  Ⓨ Copy  ☰ Move  ⊞ Del  LB/RB Switch"
	else:
		hints_label.text = "Ins:Sel  F2:Ren  F5:Copy  F6:Move  F7:Mkdir  F8:Del  Tab:Switch"


func _show_status(message: String) -> void:
	status_label.text = message


# =============================================================================
# File Operations
# =============================================================================

func _copy_files() -> void:
	var source := _get_active_panel()
	var dest := _get_inactive_panel()
	var files := source.get_files_for_operation()

	if files.is_empty():
		_show_status("⚠ No files to copy")
		return

	var source_path := source.current_path
	var dest_path := dest.current_path

	var success := 0
	var failed := 0

	for file_name in files:
		var src := source_path.path_join(file_name)
		var dst := dest_path.path_join(file_name)

		if _copy_item(src, dst):
			success += 1
		else:
			failed += 1

	dest.refresh()
	source.deselect_all()

	if failed == 0:
		_show_status("✅ Copied %d item(s)" % success)
	else:
		_show_status("⚠ Copied %d, failed %d" % [success, failed])


func _copy_item(src: String, dst: String) -> bool:
	if DirAccess.dir_exists_absolute(src):
		return _copy_directory_recursive(src, dst)
	else:
		return DirAccess.copy_absolute(src, dst) == OK


func _copy_directory_recursive(src: String, dst: String) -> bool:
	var dir := DirAccess.open(src)
	if dir == null:
		return false

	if not DirAccess.dir_exists_absolute(dst):
		if DirAccess.make_dir_recursive_absolute(dst) != OK:
			return false

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var src_path := src.path_join(file_name)
			var dst_path := dst.path_join(file_name)

			if dir.current_is_dir():
				if not _copy_directory_recursive(src_path, dst_path):
					dir.list_dir_end()
					return false
			else:
				if DirAccess.copy_absolute(src_path, dst_path) != OK:
					dir.list_dir_end()
					return false

		file_name = dir.get_next()

	dir.list_dir_end()
	return true


func _move_files() -> void:
	var source := _get_active_panel()
	var files := source.get_files_for_operation()

	if files.is_empty():
		_show_status("⚠ No files to move")
		return

	pending_operation = "move"
	pending_files = files.duplicate()
	confirm_dialog.dialog_text = "Move %d item(s) to other panel?" % files.size()
	confirm_dialog.popup_centered()


func _delete_files() -> void:
	var source := _get_active_panel()
	var files := source.get_files_for_operation()

	if files.is_empty():
		_show_status("⚠ No files to delete")
		return

	pending_operation = "delete"
	pending_files = files.duplicate()
	confirm_dialog.dialog_text = "🗑️ Delete %d item(s)?\nThis cannot be undone!" % files.size()
	confirm_dialog.popup_centered()


func _rename_file() -> void:
	var panel := _get_active_panel()
	var focused := panel.get_focused_file()

	if focused.is_empty():
		_show_status("⚠ No file selected")
		return

	pending_operation = "rename"
	pending_files = [focused]
	input_dialog.title = "✏️ Rename"
	input_line_edit.text = focused
	input_line_edit.select_all()
	input_dialog.popup_centered()
	input_line_edit.grab_focus()


func _create_directory() -> void:
	pending_operation = "mkdir"
	pending_files.clear()
	input_dialog.title = "📁 Create Directory"
	input_line_edit.text = ""
	input_dialog.popup_centered()
	input_line_edit.grab_focus()


func _on_confirm_dialog_confirmed() -> void:
	match pending_operation:
		"delete":
			_execute_delete()
		"move":
			_execute_move()

	pending_operation = ""
	pending_files.clear()


func _on_confirm_dialog_canceled() -> void:
	pending_operation = ""
	pending_files.clear()
	_show_status("❌ Cancelled")


func _on_input_confirmed() -> void:
	var text := input_line_edit.text.strip_edges()
	input_dialog.hide()

	if text.is_empty():
		_show_status("⚠ Name cannot be empty")
		pending_operation = ""
		pending_files.clear()
		return

	match pending_operation:
		"rename":
			_execute_rename(text)
		"mkdir":
			_execute_mkdir(text)

	pending_operation = ""
	pending_files.clear()


func _on_input_canceled() -> void:
	input_dialog.hide()
	pending_operation = ""
	pending_files.clear()
	_show_status("❌ Cancelled")


func _on_input_text_submitted(_text: String) -> void:
	_on_input_confirmed()


func _execute_delete() -> void:
	var source := _get_active_panel()
	var source_path := source.current_path

	var success := 0
	var failed := 0

	for file_name in pending_files:
		var path := source_path.path_join(file_name)

		if _delete_item(path):
			success += 1
		else:
			failed += 1

	source.refresh()

	if failed == 0:
		_show_status("🗑️ Deleted %d item(s)" % success)
	else:
		_show_status("⚠ Deleted %d, failed %d" % [success, failed])


func _delete_item(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return _delete_directory_recursive(path)
	else:
		return DirAccess.remove_absolute(path) == OK


func _delete_directory_recursive(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		return false

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var full_path := path.path_join(file_name)

			if dir.current_is_dir():
				if not _delete_directory_recursive(full_path):
					dir.list_dir_end()
					return false
			else:
				if DirAccess.remove_absolute(full_path) != OK:
					dir.list_dir_end()
					return false

		file_name = dir.get_next()

	dir.list_dir_end()
	return DirAccess.remove_absolute(path) == OK


func _execute_move() -> void:
	var source := _get_active_panel()
	var dest := _get_inactive_panel()
	var source_path := source.current_path
	var dest_path := dest.current_path

	var success := 0
	var failed := 0

	for file_name in pending_files:
		var src := source_path.path_join(file_name)
		var dst := dest_path.path_join(file_name)

		# Try direct rename first (same filesystem)
		if DirAccess.rename_absolute(src, dst) == OK:
			success += 1
		else:
			# Fallback to copy + delete (cross-filesystem)
			if _copy_item(src, dst) and _delete_item(src):
				success += 1
			else:
				failed += 1

	source.refresh()
	dest.refresh()

	if failed == 0:
		_show_status("📦 Moved %d item(s)" % success)
	else:
		_show_status("⚠ Moved %d, failed %d" % [success, failed])


func _execute_rename(new_name: String) -> void:
	if pending_files.is_empty():
		return

	var panel := _get_active_panel()
	var old_name: String = pending_files[0]
	var old_path := panel.current_path.path_join(old_name)
	var new_path := panel.current_path.path_join(new_name)

	if old_name == new_name:
		_show_status("⚠ Name unchanged")
		return

	if FileAccess.file_exists(new_path) or DirAccess.dir_exists_absolute(new_path):
		_show_status("⚠ Name already exists")
		return

	if DirAccess.rename_absolute(old_path, new_path) == OK:
		panel.refresh()
		_show_status("✏️ Renamed to: " + new_name)
	else:
		_show_status("❌ Rename failed")


func _execute_mkdir(dir_name: String) -> void:
	var panel := _get_active_panel()
	var new_path := panel.current_path.path_join(dir_name)

	if DirAccess.dir_exists_absolute(new_path):
		_show_status("⚠ Directory already exists")
		return

	if DirAccess.make_dir_absolute(new_path) == OK:
		panel.refresh()
		_show_status("📁 Created: " + dir_name)
	else:
		_show_status("❌ Failed to create directory")


func _refresh_panels() -> void:
	left_panel.refresh()
	right_panel.refresh()
	_show_status("🔄 Refreshed")


func _get_start_directory() -> String:
	var home := OS.get_environment("HOME")
	if not home.is_empty() and DirAccess.dir_exists_absolute(home):
		return home
	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)


func _move_focus(direction: int) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return

	var panel := _get_active_panel()
	var file_list := panel.file_list

	# Check if focus is on a file button
	if focused.get_parent() == file_list:
		var idx := focused.get_index()
		var new_idx := idx + direction

		if new_idx >= 0 and new_idx < file_list.get_child_count():
			var next_btn := file_list.get_child(new_idx) as Button
			if next_btn:
				next_btn.grab_focus()
