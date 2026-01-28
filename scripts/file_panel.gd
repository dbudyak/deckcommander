extends VBoxContainer
class_name FilePanel

@onready var current_path_label = $CurrentPathLabel
@onready var file_list = $ScrollContainer/FileList
@onready var home_button = $HBoxContainer/Button

var current_path: String
var is_focused: bool = false
var selected_files: Array[String] = []
var file_buttons: Dictionary = {}  # Maps file_name -> Button

signal file_selected(file_name: String, is_dir: bool)
signal path_changed(new_path: String)
signal selection_changed(selected: Array[String])

func _ready() -> void:
	if current_path == null or current_path == "":
		current_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	update_file_list()
	home_button.pressed.connect(_on_home_pressed)

func set_path(path: String) -> void:
	current_path = path
	selected_files.clear()
	update_file_list()

func update_file_list() -> void:
	var children = file_list.get_children()
	for c in children:
		file_list.remove_child(c)
		c.queue_free()

	file_buttons.clear()
	current_path_label.text = "📁 " + current_path

	var dir : DirAccess = DirAccess.open(current_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	var files : Array[String] = []
	var dirs : Array[String] = []

	while file_name != "":
		if file_name != "." and file_name != "..":
			if dir.current_is_dir():
				dirs.append(file_name)
			else:
				files.append(file_name)

		file_name = dir.get_next()

	dirs.sort()
	for file : String in dirs:
		var btn = build_file_item(file, true)
		file_list.add_child(btn)
		file_buttons[file] = btn

	files.sort()
	for file : String in files:
		var btn = build_file_item(file, false)
		file_list.add_child(btn)
		file_buttons[file] = btn

	if file_list.get_child_count() > 0:
		var first_button : Button = file_list.get_child(0)
		first_button.grab_focus()

func build_file_item(file_name: String, is_dir: bool) -> Button:
	var btn = Button.new()
	btn.text = ("📁 " if is_dir else "📄 ") + file_name
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	btn.set_meta("file_name", file_name)
	btn.set_meta("is_dir", is_dir)
	btn.connect(
		"pressed",
		Callable(self, "_on_file_pressed").bind(file_name, is_dir)
	)
	update_button_style(btn, file_name)
	return btn

func update_button_style(btn: Button, file_name: String) -> void:
	if file_name in selected_files:
		btn.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Green for selected
		btn.add_theme_color_override("font_focus_color", Color(0.2, 1.0, 0.2))
	else:
		btn.remove_theme_color_override("font_color")
		btn.remove_theme_color_override("font_focus_color")

func _on_file_pressed(file_name: String, is_dir: bool) -> void:
	if is_dir:
		current_path = current_path + "/" + file_name
		selected_files.clear()
		update_file_list()
		emit_signal("path_changed", current_path)
	else:
		emit_signal("file_selected", file_name, is_dir)

func toggle_selection() -> void:
	var focused = get_viewport().gui_get_focus_owner()
	if focused and focused.has_meta("file_name"):
		var file_name = focused.get_meta("file_name")
		if file_name in selected_files:
			selected_files.erase(file_name)
		else:
			selected_files.append(file_name)
		update_button_style(focused, file_name)
		emit_signal("selection_changed", selected_files)
		# Move focus to next item
		var idx = focused.get_index()
		if idx < file_list.get_child_count() - 1:
			file_list.get_child(idx + 1).grab_focus()

func select_all() -> void:
	selected_files.clear()
	for file_name in file_buttons.keys():
		selected_files.append(file_name)
		update_button_style(file_buttons[file_name], file_name)
	emit_signal("selection_changed", selected_files)

func deselect_all() -> void:
	for file_name in selected_files:
		if file_name in file_buttons:
			update_button_style(file_buttons[file_name], file_name)
	selected_files.clear()
	emit_signal("selection_changed", selected_files)

func get_selected_files() -> Array[String]:
	return selected_files

func get_focused_file() -> String:
	var focused = get_viewport().gui_get_focus_owner()
	if focused and focused.has_meta("file_name"):
		return focused.get_meta("file_name")
	return ""

func get_files_for_operation() -> Array[String]:
	# Returns selected files if any, otherwise the currently focused file
	if selected_files.size() > 0:
		return selected_files
	var focused = get_focused_file()
	if focused != "":
		return [focused]
	return []

func go_up() -> void:
	var parent = current_path.get_base_dir()
	if parent != current_path:
		current_path = parent
		selected_files.clear()
		update_file_list()

func _on_home_pressed() -> void:
	set_path(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))

func grab_focus() -> void:
	if file_list.get_child_count() > 0:
		file_list.get_child(0).grab_focus()

func refresh() -> void:
	var old_selected = selected_files.duplicate()
	update_file_list()
	# Restore selection for files that still exist
	for file_name in old_selected:
		if file_name in file_buttons:
			selected_files.append(file_name)
			update_button_style(file_buttons[file_name], file_name)
