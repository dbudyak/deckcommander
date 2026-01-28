extends VBoxContainer
class_name FilePanel
## A dual-panel file browser component with selection support.
##
## This component displays a list of files and directories, supports
## single and multi-selection, and emits signals for user interactions.

const FileOperations = preload("res://scripts/file_operations.gd")


# =============================================================================
# Signals
# =============================================================================

## Emitted when a file (not directory) is activated.
signal file_activated(file_path: String)

## Emitted when the current directory changes.
signal path_changed(new_path: String)

## Emitted when the selection changes.
signal selection_changed(selected_files: Array[String])

## Emitted when this panel gains focus.
signal panel_focused()


# =============================================================================
# Node References
# =============================================================================

@onready var _path_label: Label = $CurrentPathLabel
@onready var _file_list: VBoxContainer = $ScrollContainer/FileList
@onready var _home_button: Button = $HBoxContainer/HomeButton
@onready var _up_button: Button = $HBoxContainer/UpButton
@onready var _hidden_button: Button = $HBoxContainer/HiddenButton
@onready var _scroll_container: ScrollContainer = $ScrollContainer


# =============================================================================
# State
# =============================================================================

## Current directory path being displayed.
var current_path: String = ""

## Whether this panel currently has focus.
var is_focused: bool = false

## Whether to show hidden files (starting with dot).
var show_hidden_files: bool = false

## Currently selected file names.
var _selected_files: Array[String] = []

## Map of file_name -> Button for quick lookup.
var _file_buttons: Dictionary = {}

## Item to focus after file list rebuild.
var _pending_focus_item: String = ""


# =============================================================================
# Lifecycle
# =============================================================================

func _ready() -> void:
	if current_path.is_empty():
		current_path = FileOperations.get_home_directory()

	_connect_toolbar_signals()
	_update_hidden_button_display()
	refresh_file_list()


func _connect_toolbar_signals() -> void:
	_home_button.pressed.connect(_on_home_pressed)
	_up_button.pressed.connect(_on_up_pressed)
	_hidden_button.pressed.connect(_on_hidden_pressed)

	# Track panel focus from toolbar buttons
	_home_button.focus_entered.connect(_emit_panel_focused)
	_up_button.focus_entered.connect(_emit_panel_focused)
	_hidden_button.focus_entered.connect(_emit_panel_focused)

	# Disable Tab navigation on toolbar to let main handle it
	_disable_button_focus_neighbors(_home_button)
	_disable_button_focus_neighbors(_up_button)
	_disable_button_focus_neighbors(_hidden_button)


func _disable_button_focus_neighbors(btn: Button) -> void:
	btn.focus_neighbor_left = btn.get_path()
	btn.focus_neighbor_right = btn.get_path()
	btn.focus_next = btn.get_path()
	btn.focus_previous = btn.get_path()


# =============================================================================
# Public API
# =============================================================================

## Changes the current directory and refreshes the file list.
func set_directory(path: String, focus_item: String = "") -> void:
	if not DirAccess.dir_exists_absolute(path):
		push_warning("FilePanel: Directory does not exist: %s" % path)
		return

	current_path = path
	_selected_files.clear()
	_pending_focus_item = focus_item
	refresh_file_list()
	path_changed.emit(current_path)


## Navigates to the parent directory.
func go_up() -> void:
	var parent := current_path.get_base_dir()
	if parent != current_path and not parent.is_empty():
		var current_dir_name := current_path.get_file()
		set_directory(parent, current_dir_name)


## Navigates to the home directory.
func go_home() -> void:
	set_directory(FileOperations.get_home_directory())


## Refreshes the file list, preserving selection where possible.
func refresh() -> void:
	var old_selected := _selected_files.duplicate()
	var old_focused := get_focused_file_name()
	_pending_focus_item = old_focused

	refresh_file_list()

	# Restore selection for files that still exist
	for file_name in old_selected:
		if file_name in _file_buttons:
			_selected_files.append(file_name)
			_update_button_selection_style(_file_buttons[file_name], file_name)


## Gives focus to this panel.
func focus_panel() -> void:
	_focus_first_item()
	_emit_panel_focused()


## Toggles selection on the currently focused file.
func toggle_selection() -> void:
	var btn := _get_focused_file_button()
	if btn == null:
		return

	var file_name: String = btn.get_meta("file_name")
	_toggle_file_selection(file_name, btn)

	# Move focus to next item
	_focus_next_item(btn)


## Selects all files in the current directory.
func select_all() -> void:
	_selected_files.clear()
	for file_name in _file_buttons.keys():
		_selected_files.append(file_name)
		_update_button_selection_style(_file_buttons[file_name], file_name)
	selection_changed.emit(_selected_files)


## Clears all selections.
func deselect_all() -> void:
	for file_name in _selected_files:
		if file_name in _file_buttons:
			_update_button_selection_style(_file_buttons[file_name], file_name)
	_selected_files.clear()
	selection_changed.emit(_selected_files)


## Returns the list of selected file names.
func get_selected_files() -> Array[String]:
	return _selected_files


## Returns the focused file name, or empty string if none.
func get_focused_file_name() -> String:
	var btn := _get_focused_file_button()
	if btn:
		return btn.get_meta("file_name")
	return ""


## Returns files for an operation (selected files, or focused file if none selected).
func get_files_for_operation() -> Array[String]:
	if _selected_files.size() > 0:
		return _selected_files.duplicate()
	var focused := get_focused_file_name()
	if not focused.is_empty():
		return [focused]
	return []


## Returns whether the focused item is a directory.
func is_focused_item_directory() -> bool:
	var btn := _get_focused_file_button()
	if btn and btn.has_meta("is_dir"):
		return btn.get_meta("is_dir")
	return false


## Returns whether any element within this panel has focus.
func has_focus_in_panel() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return false

	if focused in [_home_button, _up_button, _hidden_button]:
		return true

	return focused is Button and focused.has_meta("file_name") and focused.get_parent() == _file_list


## Provides access to the file list container (for focus management).
var file_list: VBoxContainer:
	get:
		return _file_list


# =============================================================================
# File List Management
# =============================================================================

func refresh_file_list() -> void:
	_clear_file_list()
	_path_label.text = current_path

	var dir := DirAccess.open(current_path)
	if dir == null:
		_path_label.text = "Error: " + str(DirAccess.get_open_error())
		return

	var entries := _collect_directory_entries(dir)
	_populate_file_list(entries.dirs, entries.files)

	# Focus appropriate item after the tree is ready
	await get_tree().process_frame
	_apply_pending_focus()


func _clear_file_list() -> void:
	for child in _file_list.get_children():
		child.queue_free()
	_file_buttons.clear()


func _collect_directory_entries(dir: DirAccess) -> Dictionary:
	var dirs: Array[String] = []
	var files: Array[String] = []

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var is_hidden := file_name.begins_with(".")
			if show_hidden_files or not is_hidden:
				if dir.current_is_dir():
					dirs.append(file_name)
				else:
					files.append(file_name)
		file_name = dir.get_next()

	dir.list_dir_end()

	# Sort case-insensitive
	dirs.sort_custom(func(a, b): return a.to_lower() < b.to_lower())
	files.sort_custom(func(a, b): return a.to_lower() < b.to_lower())

	return { "dirs": dirs, "files": files }


func _populate_file_list(dirs: Array[String], files: Array[String]) -> void:
	for dir_name in dirs:
		_create_file_button(dir_name, true)

	for file_name in files:
		_create_file_button(file_name, false)


func _create_file_button(file_name: String, is_dir: bool) -> void:
	var btn := Button.new()

	# Build display text
	var icon := "📁" if is_dir else FileOperations.get_file_icon(file_name)
	var size_text := _get_file_size_text(file_name) if not is_dir else ""
	btn.text = "%s %s%s" % [icon, file_name, size_text]

	# Configure button
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	btn.set_meta("file_name", file_name)
	btn.set_meta("is_dir", is_dir)

	# Connect signals
	btn.pressed.connect(_on_file_button_pressed.bind(file_name, is_dir))
	btn.focus_entered.connect(_on_file_button_focus_entered.bind(btn))

	# Apply selection style if previously selected
	_update_button_selection_style(btn, file_name)

	# Add to tree
	_file_list.add_child(btn)
	_file_buttons[file_name] = btn

	# Disable horizontal focus (must be after adding to tree)
	btn.focus_neighbor_left = btn.get_path()
	btn.focus_neighbor_right = btn.get_path()


func _get_file_size_text(file_name: String) -> String:
	var full_path := current_path.path_join(file_name)
	var file := FileAccess.open(full_path, FileAccess.READ)
	if file:
		var size := file.get_length()
		file.close()
		return "  %s" % FileOperations.format_size(size)
	return ""


func _apply_pending_focus() -> void:
	if is_focused:
		if not _pending_focus_item.is_empty() and _pending_focus_item in _file_buttons:
			(_file_buttons[_pending_focus_item] as Button).grab_focus()
		else:
			_focus_first_item()
	_pending_focus_item = ""


# =============================================================================
# Selection Management
# =============================================================================

func _toggle_file_selection(file_name: String, btn: Button) -> void:
	if file_name in _selected_files:
		_selected_files.erase(file_name)
	else:
		_selected_files.append(file_name)

	_update_button_selection_style(btn, file_name)
	selection_changed.emit(_selected_files)


func _update_button_selection_style(btn: Button, file_name: String) -> void:
	if file_name in _selected_files:
		btn.add_theme_color_override("font_color", Settings.SELECTION_COLOR)
		btn.add_theme_color_override("font_focus_color", Settings.SELECTION_FOCUS_COLOR)
		btn.add_theme_color_override("font_hover_color", Settings.SELECTION_FOCUS_COLOR)
	else:
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_focus_color")
		btn.remove_theme_color_override("font_hover_color")


# =============================================================================
# Focus Management
# =============================================================================

func _focus_first_item() -> void:
	if _file_list.get_child_count() > 0:
		var first := _file_list.get_child(0) as Button
		if first:
			first.grab_focus()
	else:
		_up_button.grab_focus()


func _focus_next_item(current_btn: Button) -> void:
	var idx := current_btn.get_index()
	if idx < _file_list.get_child_count() - 1:
		var next := _file_list.get_child(idx + 1) as Button
		if next:
			next.grab_focus()


func _get_focused_file_button() -> Button:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and focused.has_meta("file_name"):
		return focused as Button
	return null


func _emit_panel_focused() -> void:
	panel_focused.emit()


# =============================================================================
# Event Handlers
# =============================================================================

func _on_file_button_pressed(file_name: String, is_dir: bool) -> void:
	if is_dir:
		set_directory(current_path.path_join(file_name))
	else:
		file_activated.emit(current_path.path_join(file_name))


func _on_file_button_focus_entered(btn: Button) -> void:
	_emit_panel_focused()
	# Ensure visible in scroll container
	await get_tree().process_frame
	_scroll_container.ensure_control_visible(btn)


func _on_home_pressed() -> void:
	go_home()


func _on_up_pressed() -> void:
	go_up()


func _on_hidden_pressed() -> void:
	show_hidden_files = not show_hidden_files
	_update_hidden_button_display()
	refresh()


func _update_hidden_button_display() -> void:
	_hidden_button.text = "👁" if show_hidden_files else "◌"
	_hidden_button.tooltip_text = "Hide hidden files" if show_hidden_files else "Show hidden files"
