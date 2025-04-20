extends VBoxContainer

@onready var current_path_label = $CurrentPathLabel
@onready var file_list = $ScrollContainer/FileList

var current_path: String
var is_focused: bool = false

signal file_selected(file_name: String, is_dir: bool)
signal path_changed(new_path: String)

func _ready():
	# Placeholder path, can be set from outside
	if current_path == null or current_path == "":
		current_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	update_file_list()

func set_path(path: String):
	current_path = path
	update_file_list()

func update_file_list():
	#file_list.clear()
	current_path_label.text = "📁 " + current_path

	var dir = DirAccess.open(current_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var is_dir = dir.current_is_dir()
			var btn = Button.new()
			btn.text = ("[DIR] " if is_dir else "") + file_name
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.focus_mode = Control.FOCUS_ALL
			
			print(file_name)

			btn.connect("pressed", Callable(self, "_on_file_pressed").bind(file_name, is_dir))
			file_list.add_child(btn)
		file_name = dir.get_next()
	dir.list_dir_end()

func _on_file_pressed(file_name: String, is_dir: bool):
	if is_dir:
		current_path = current_path + file_name
		update_file_list()
		emit_signal("path_changed", current_path)
	else:
		emit_signal("file_selected", file_name, is_dir)

func go_up():
	var parent = current_path.get_base_dir()
	if parent != current_path:
		current_path = parent
		update_file_list()
