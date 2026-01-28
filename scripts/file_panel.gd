extends VBoxContainer
class_name FilePanel

## A file browser panel component with selection support.

@onready var current_path_label: Label = $CurrentPathLabel
@onready var file_list: VBoxContainer = $ScrollContainer/FileList
@onready var home_button: Button = $HBoxContainer/HomeButton
@onready var up_button: Button = $HBoxContainer/UpButton
@onready var hidden_button: Button = $HBoxContainer/HiddenButton
@onready var scroll_container: ScrollContainer = $ScrollContainer

var current_path: String = ""
var is_focused: bool = false
var show_hidden_files: bool = false
var selected_files: Array[String] = []
var file_buttons: Dictionary = {}

signal file_selected(file_name: String, is_dir: bool)
signal path_changed(new_path: String)
signal selection_changed(selected: Array[String])
signal panel_focused()  # Emitted when this panel gains focus


func _ready() -> void:
	if current_path.is_empty():
		current_path = _get_home_directory()

	home_button.pressed.connect(_on_home_pressed)
	up_button.pressed.connect(_on_up_pressed)
	hidden_button.pressed.connect(_on_hidden_pressed)

	# Connect toolbar button focus to panel focus
	home_button.focus_entered.connect(_on_panel_focus_gained)
	up_button.focus_entered.connect(_on_panel_focus_gained)
	hidden_button.focus_entered.connect(_on_panel_focus_gained)

	_update_hidden_button()
	update_file_list()


func set_path(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	current_path = path
	selected_files.clear()
	update_file_list()
	path_changed.emit(current_path)


func update_file_list() -> void:
	# Clear existing items
	for child in file_list.get_children():
		child.queue_free()
	file_buttons.clear()

	# Update path display
	current_path_label.text = current_path

	# Open directory
	var dir := DirAccess.open(current_path)
	if dir == null:
		current_path_label.text = "Error: " + str(DirAccess.get_open_error())
		return

	# Collect files and directories
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

	# Sort alphabetically (case-insensitive)
	dirs.sort_custom(_sort_case_insensitive)
	files.sort_custom(_sort_case_insensitive)

	# Add directory items first
	for dir_name in dirs:
		_add_file_item(dir_name, true)

	# Add file items
	for fname in files:
		_add_file_item(fname, false)

	# Focus first item if available
	await get_tree().process_frame
	if is_focused:
		_focus_first_item()


func _sort_case_insensitive(a: String, b: String) -> bool:
	return a.to_lower() < b.to_lower()


func _add_file_item(file_name: String, is_dir: bool) -> void:
	var btn := Button.new()

	# Get file info
	var full_path := current_path.path_join(file_name)
	var icon := "📁 " if is_dir else _get_file_icon(file_name)
	var size_text := ""

	if not is_dir:
		var file := FileAccess.open(full_path, FileAccess.READ)
		if file:
			var size := file.get_length()
			size_text = "  %s" % _format_size(size)
			file.close()

	btn.text = icon + file_name + size_text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	btn.set_meta("file_name", file_name)
	btn.set_meta("is_dir", is_dir)

	btn.pressed.connect(_on_file_pressed.bind(file_name, is_dir))
	btn.focus_entered.connect(_on_file_focus_entered.bind(btn))

	_update_button_style(btn, file_name)
	file_list.add_child(btn)
	file_buttons[file_name] = btn


func _get_file_icon(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	match ext:
		"png", "jpg", "jpeg", "gif", "webp", "svg", "bmp":
			return "🖼️ "
		"mp3", "wav", "ogg", "flac", "m4a":
			return "🎵 "
		"mp4", "mkv", "avi", "mov", "webm":
			return "🎬 "
		"zip", "tar", "gz", "7z", "rar":
			return "📦 "
		"exe", "app", "sh", "bin":
			return "⚡ "
		"pdf":
			return "📕 "
		"txt", "md", "log":
			return "📝 "
		"gd", "py", "js", "ts", "rs", "go", "c", "cpp", "h":
			return "💻 "
		"json", "xml", "yaml", "toml", "ini", "cfg":
			return "⚙️ "
		_:
			return "📄 "


func _format_size(bytes: int) -> String:
	if bytes < 1024:
		return "%d B" % bytes
	elif bytes < 1024 * 1024:
		return "%.1f KB" % (bytes / 1024.0)
	elif bytes < 1024 * 1024 * 1024:
		return "%.1f MB" % (bytes / 1024.0 / 1024.0)
	else:
		return "%.1f GB" % (bytes / 1024.0 / 1024.0 / 1024.0)


func _update_button_style(btn: Button, file_name: String) -> void:
	if file_name in selected_files:
		btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		btn.add_theme_color_override("font_focus_color", Color(0.4, 1.0, 0.6))
		btn.add_theme_color_override("font_hover_color", Color(0.3, 1.0, 0.5))
	else:
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_focus_color")
		btn.remove_theme_color_override("font_hover_color")


func _on_file_pressed(file_name: String, is_dir: bool) -> void:
	if is_dir:
		set_path(current_path.path_join(file_name))
	else:
		file_selected.emit(file_name, is_dir)


func _on_file_focus_entered(btn: Button) -> void:
	# Notify that this panel gained focus
	_on_panel_focus_gained()
	# Ensure the focused button is visible in scroll container
	await get_tree().process_frame
	scroll_container.ensure_control_visible(btn)


func _on_panel_focus_gained() -> void:
	panel_focused.emit()


func toggle_selection() -> void:
	var focused := _get_focused_button()
	if focused == null:
		return

	var file_name: String = focused.get_meta("file_name")

	if file_name in selected_files:
		selected_files.erase(file_name)
	else:
		selected_files.append(file_name)

	_update_button_style(focused, file_name)
	selection_changed.emit(selected_files)

	# Move focus to next item
	var idx := focused.get_index()
	if idx < file_list.get_child_count() - 1:
		var next_btn := file_list.get_child(idx + 1) as Button
		if next_btn:
			next_btn.grab_focus()


func select_all() -> void:
	selected_files.clear()
	for file_name in file_buttons.keys():
		selected_files.append(file_name)
		_update_button_style(file_buttons[file_name], file_name)
	selection_changed.emit(selected_files)


func deselect_all() -> void:
	for file_name in selected_files:
		if file_name in file_buttons:
			_update_button_style(file_buttons[file_name], file_name)
	selected_files.clear()
	selection_changed.emit(selected_files)


func get_selected_files() -> Array[String]:
	return selected_files


func get_focused_file() -> String:
	var focused := _get_focused_button()
	if focused:
		return focused.get_meta("file_name")
	return ""


func get_files_for_operation() -> Array[String]:
	if selected_files.size() > 0:
		return selected_files.duplicate()
	var focused := get_focused_file()
	if not focused.is_empty():
		return [focused]
	return []


func is_focused_item_directory() -> bool:
	var focused := _get_focused_button()
	if focused and focused.has_meta("is_dir"):
		return focused.get_meta("is_dir")
	return false


func go_up() -> void:
	var parent := current_path.get_base_dir()
	if parent != current_path and not parent.is_empty():
		set_path(parent)


func focus_panel() -> void:
	_focus_first_item()


func refresh() -> void:
	var old_selected := selected_files.duplicate()
	var old_focused := get_focused_file()

	update_file_list()

	# Restore selection for files that still exist
	for file_name in old_selected:
		if file_name in file_buttons:
			selected_files.append(file_name)
			_update_button_style(file_buttons[file_name], file_name)

	# Try to restore focus
	if old_focused in file_buttons:
		(file_buttons[old_focused] as Button).grab_focus()


func has_focus_in_panel() -> bool:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null:
		return false
	return focused == home_button or focused == up_button or focused == hidden_button or (focused is Button and focused.has_meta("file_name") and focused.get_parent() == file_list)


func _get_focused_button() -> Button:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and focused.has_meta("file_name"):
		return focused as Button
	return null


func _focus_first_item() -> void:
	if file_list.get_child_count() > 0:
		var first := file_list.get_child(0) as Button
		if first:
			first.grab_focus()


func _on_home_pressed() -> void:
	set_path(_get_home_directory())


func _on_up_pressed() -> void:
	go_up()


func _on_hidden_pressed() -> void:
	show_hidden_files = not show_hidden_files
	_update_hidden_button()
	refresh()


func _update_hidden_button() -> void:
	hidden_button.text = "👁" if show_hidden_files else "◌"
	hidden_button.tooltip_text = "Hide hidden files" if show_hidden_files else "Show hidden files"


func _get_home_directory() -> String:
	var home := OS.get_environment("HOME")
	if not home.is_empty() and DirAccess.dir_exists_absolute(home):
		return home

	home = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).get_base_dir()
	if DirAccess.dir_exists_absolute(home):
		return home

	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
