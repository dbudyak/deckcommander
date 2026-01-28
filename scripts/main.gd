extends Control
## Main controller for DeckCommander dual-panel file manager.
##
## Manages the two file panels, handles global input, and coordinates
## file operations between panels.


# =============================================================================
# Node References
# =============================================================================

@onready var _left_panel: FilePanel = $Panel/VBoxContainer/PanelsContainer/LeftPanel
@onready var _right_panel: FilePanel = $Panel/VBoxContainer/PanelsContainer/RightPanel
@onready var _status_label: Label = $Panel/VBoxContainer/StatusBar/StatusLabel
@onready var _hints_label: Label = $Panel/VBoxContainer/StatusBar/HintsLabel
@onready var _confirm_dialog: ConfirmationDialog = $ConfirmDialog
@onready var _input_dialog: Window = $InputDialog
@onready var _input_line_edit: LineEdit = $InputDialog/VBoxContainer/LineEdit
@onready var _input_ok_button: Button = $InputDialog/VBoxContainer/HBoxContainer/OkButton
@onready var _input_cancel_button: Button = $InputDialog/VBoxContainer/HBoxContainer/CancelButton


# =============================================================================
# State
# =============================================================================

enum Panel { LEFT, RIGHT }

var _active_panel: Panel = Panel.LEFT
var _pending_operation: String = ""
var _pending_files: Array[String] = []
var _using_gamepad: bool = false

# Navigation key repeat state
var _nav_direction: int = 0
var _nav_repeat_timer: float = 0.0
var _nav_repeating: bool = false


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	_initialize_panels()
	_connect_signals()
	_set_active_panel(Panel.LEFT)
	_update_status()
	_update_hints()


func _initialize_panels() -> void:
	var home := FileOperations.get_home_directory()
	_left_panel.set_directory(home)
	_right_panel.set_directory(home)


func _connect_signals() -> void:
	# Panel signals
	_left_panel.panel_focused.connect(_on_left_panel_focused)
	_right_panel.panel_focused.connect(_on_right_panel_focused)
	_left_panel.selection_changed.connect(_on_selection_changed)
	_right_panel.selection_changed.connect(_on_selection_changed)

	# Dialog signals
	_confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	_confirm_dialog.canceled.connect(_on_confirm_dialog_canceled)
	_input_ok_button.pressed.connect(_on_input_confirmed)
	_input_cancel_button.pressed.connect(_on_input_canceled)
	_input_line_edit.text_submitted.connect(_on_input_text_submitted)


# =============================================================================
# Input Handling
# =============================================================================

func _process(delta: float) -> void:
	_handle_navigation_repeat(delta)


func _handle_navigation_repeat(delta: float) -> void:
	if _nav_direction == 0:
		return

	_nav_repeat_timer += delta
	var threshold := Settings.NAV_REPEAT_DELAY if not _nav_repeating else Settings.NAV_REPEAT_RATE

	if _nav_repeat_timer >= threshold:
		_nav_repeat_timer = 0.0
		_nav_repeating = true
		_move_focus(_nav_direction)


func _input(event: InputEvent) -> void:
	_detect_input_device(event)
	_track_navigation_keys(event)
	_handle_panel_switch(event)


func _detect_input_device(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if not _using_gamepad:
			_using_gamepad = true
			_update_hints()
	elif event is InputEventKey:
		if _using_gamepad:
			_using_gamepad = false
			_update_hints()


func _track_navigation_keys(event: InputEvent) -> void:
	if event.is_action_pressed("ui_down"):
		_nav_direction = 1
		_nav_repeat_timer = 0.0
		_nav_repeating = false
	elif event.is_action_pressed("ui_up"):
		_nav_direction = -1
		_nav_repeat_timer = 0.0
		_nav_repeating = false
	elif event.is_action_released("ui_down") or event.is_action_released("ui_up"):
		_nav_direction = 0
		_nav_repeating = false


func _handle_panel_switch(event: InputEvent) -> void:
	if _is_dialog_open():
		return

	if event.is_action_pressed("ui_focus_next"):
		_toggle_active_panel()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _is_dialog_open():
		return

	var panel := _get_active_panel()

	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_text_backspace"):
		panel.go_up()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("select_file"):
		panel.toggle_selection()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("copy_file"):
		_execute_copy()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("move_file"):
		_request_move()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("delete_file"):
		_request_delete()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("select_all"):
		panel.select_all()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("refresh"):
		_refresh_panels()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rename_file"):
		_request_rename()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("create_dir"):
		_request_create_directory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_hidden"):
		panel._on_hidden_pressed()
		get_viewport().set_input_as_handled()


func _is_dialog_open() -> bool:
	return _confirm_dialog.visible or _input_dialog.visible


# =============================================================================
# Panel Management
# =============================================================================

func _set_active_panel(panel: Panel) -> void:
	_active_panel = panel

	if panel == Panel.LEFT:
		_left_panel.modulate = Settings.PANEL_ACTIVE_COLOR
		_left_panel.is_focused = true
		_right_panel.modulate = Settings.PANEL_INACTIVE_COLOR
		_right_panel.is_focused = false
	else:
		_right_panel.modulate = Settings.PANEL_ACTIVE_COLOR
		_right_panel.is_focused = true
		_left_panel.modulate = Settings.PANEL_INACTIVE_COLOR
		_left_panel.is_focused = false

	_update_status()


func _toggle_active_panel() -> void:
	var new_panel := Panel.RIGHT if _active_panel == Panel.LEFT else Panel.LEFT
	_set_active_panel(new_panel)
	_get_active_panel().focus_panel()


func _get_active_panel() -> FilePanel:
	return _left_panel if _active_panel == Panel.LEFT else _right_panel


func _get_inactive_panel() -> FilePanel:
	return _right_panel if _active_panel == Panel.LEFT else _left_panel


func _on_left_panel_focused() -> void:
	if _active_panel != Panel.LEFT:
		_set_active_panel(Panel.LEFT)


func _on_right_panel_focused() -> void:
	if _active_panel != Panel.RIGHT:
		_set_active_panel(Panel.RIGHT)


func _on_selection_changed(_selected: Array) -> void:
	_update_status()


# =============================================================================
# Status Bar
# =============================================================================

func _update_status() -> void:
	var panel := _get_active_panel()
	var selected := panel.get_selected_files()

	if selected.size() > 0:
		_status_label.text = "%s %d item(s) selected" % [Settings.ICON_SELECTED, selected.size()]
	else:
		var focused := panel.get_focused_file_name()
		if not focused.is_empty():
			_status_label.text = "%s %s" % [Settings.ICON_POINTER, focused]
		else:
			_status_label.text = "%s Ready" % Settings.ICON_READY


func _update_hints() -> void:
	_hints_label.text = Settings.HINTS_GAMEPAD if _using_gamepad else Settings.HINTS_KEYBOARD


func _show_status(icon: String, message: String) -> void:
	_status_label.text = "%s %s" % [icon, message]


# =============================================================================
# File Operations
# =============================================================================

func _execute_copy() -> void:
	var source := _get_active_panel()
	var dest := _get_inactive_panel()
	var files := source.get_files_for_operation()

	if files.is_empty():
		_show_status(Settings.ICON_WARNING, "No files to copy")
		return

	var source_path := source.current_path
	var dest_path := dest.current_path

	var success := 0
	var failed := 0

	for file_name in files:
		var src := source_path.path_join(file_name)
		var dst := dest_path.path_join(file_name)

		if FileOperations.copy_item(src, dst):
			success += 1
		else:
			failed += 1

	dest.refresh()
	source.deselect_all()

	if failed == 0:
		_show_status(Settings.ICON_COPY, "Copied %d item(s)" % success)
	else:
		_show_status(Settings.ICON_WARNING, "Copied %d, failed %d" % [success, failed])


func _request_move() -> void:
	var files := _get_active_panel().get_files_for_operation()
	if files.is_empty():
		_show_status(Settings.ICON_WARNING, "No files to move")
		return

	_pending_operation = "move"
	_pending_files = files.duplicate()
	_confirm_dialog.dialog_text = "Move %d item(s) to other panel?" % files.size()
	_confirm_dialog.popup_centered()


func _request_delete() -> void:
	var files := _get_active_panel().get_files_for_operation()
	if files.is_empty():
		_show_status(Settings.ICON_WARNING, "No files to delete")
		return

	_pending_operation = "delete"
	_pending_files = files.duplicate()
	_confirm_dialog.dialog_text = "%s Delete %d item(s)?\nThis cannot be undone!" % [Settings.ICON_DELETE, files.size()]
	_confirm_dialog.popup_centered()


func _request_rename() -> void:
	var focused := _get_active_panel().get_focused_file_name()
	if focused.is_empty():
		_show_status(Settings.ICON_WARNING, "No file selected")
		return

	_pending_operation = "rename"
	_pending_files = [focused]
	_input_dialog.title = "%s Rename" % Settings.ICON_RENAME
	_input_line_edit.text = focused
	_input_line_edit.select_all()
	_input_dialog.popup_centered()
	_input_line_edit.grab_focus()


func _request_create_directory() -> void:
	_pending_operation = "mkdir"
	_pending_files.clear()
	_input_dialog.title = "%s Create Directory" % Settings.ICON_MKDIR
	_input_line_edit.text = ""
	_input_dialog.popup_centered()
	_input_line_edit.grab_focus()


func _execute_move() -> void:
	var source := _get_active_panel()
	var dest := _get_inactive_panel()
	var source_path := source.current_path
	var dest_path := dest.current_path

	var success := 0
	var failed := 0

	for file_name in _pending_files:
		var src := source_path.path_join(file_name)
		var dst := dest_path.path_join(file_name)

		if FileOperations.move_item(src, dst):
			success += 1
		else:
			failed += 1

	source.refresh()
	dest.refresh()

	if failed == 0:
		_show_status(Settings.ICON_MOVE, "Moved %d item(s)" % success)
	else:
		_show_status(Settings.ICON_WARNING, "Moved %d, failed %d" % [success, failed])


func _execute_delete() -> void:
	var source := _get_active_panel()
	var source_path := source.current_path

	var success := 0
	var failed := 0

	for file_name in _pending_files:
		var path := source_path.path_join(file_name)

		if FileOperations.delete_item(path):
			success += 1
		else:
			failed += 1

	source.refresh()

	if failed == 0:
		_show_status(Settings.ICON_DELETE, "Deleted %d item(s)" % success)
	else:
		_show_status(Settings.ICON_WARNING, "Deleted %d, failed %d" % [success, failed])


func _execute_rename(new_name: String) -> void:
	if _pending_files.is_empty():
		return

	var panel := _get_active_panel()
	var old_name: String = _pending_files[0]

	if old_name == new_name:
		_show_status(Settings.ICON_WARNING, "Name unchanged")
		return

	var old_path := panel.current_path.path_join(old_name)
	var new_path := panel.current_path.path_join(new_name)

	if FileOperations.rename_item(old_path, new_path):
		panel.refresh()
		_show_status(Settings.ICON_RENAME, "Renamed to: " + new_name)
	else:
		_show_status(Settings.ICON_ERROR, "Rename failed")


func _execute_create_directory(dir_name: String) -> void:
	var panel := _get_active_panel()
	var new_path := panel.current_path.path_join(dir_name)

	if FileOperations.create_directory(new_path):
		panel.refresh()
		_show_status(Settings.ICON_MKDIR, "Created: " + dir_name)
	else:
		_show_status(Settings.ICON_ERROR, "Failed to create directory")


func _refresh_panels() -> void:
	_left_panel.refresh()
	_right_panel.refresh()
	_show_status(Settings.ICON_REFRESH, "Refreshed")


# =============================================================================
# Dialog Handlers
# =============================================================================

func _on_confirm_dialog_confirmed() -> void:
	match _pending_operation:
		"delete":
			_execute_delete()
		"move":
			_execute_move()

	_clear_pending_operation()


func _on_confirm_dialog_canceled() -> void:
	_clear_pending_operation()
	_show_status(Settings.ICON_ERROR, "Cancelled")


func _on_input_confirmed() -> void:
	var text := _input_line_edit.text.strip_edges()
	_input_dialog.hide()

	if text.is_empty():
		_show_status(Settings.ICON_WARNING, "Name cannot be empty")
		_clear_pending_operation()
		return

	match _pending_operation:
		"rename":
			_execute_rename(text)
		"mkdir":
			_execute_create_directory(text)

	_clear_pending_operation()


func _on_input_canceled() -> void:
	_input_dialog.hide()
	_clear_pending_operation()
	_show_status(Settings.ICON_ERROR, "Cancelled")


func _on_input_text_submitted(_text: String) -> void:
	_on_input_confirmed()


func _clear_pending_operation() -> void:
	_pending_operation = ""
	_pending_files.clear()


# =============================================================================
# Focus Navigation
# =============================================================================

func _move_focus(direction: int) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return

	var panel := _get_active_panel()
	var file_list := panel.file_list

	if focused.get_parent() == file_list:
		var idx := focused.get_index()
		var new_idx := idx + direction

		if new_idx >= 0 and new_idx < file_list.get_child_count():
			var next_btn := file_list.get_child(new_idx) as Button
			if next_btn:
				next_btn.grab_focus()
