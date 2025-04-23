extends VBoxContainer

@onready var current_path_label = $CurrentPathLabel
@onready var file_list = $ScrollContainer/FileList

var current_path: String
var is_focused: bool = false

signal file_selected(file_name: String, is_dir: bool)
signal path_changed(new_path: String)

func _ready():
	if current_path == null or current_path == "":
		current_path = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	update_file_list()

func set_path(path: String):
	current_path = path
	update_file_list()

func update_file_list():
	var children = file_list.get_children()
	for c in children:
		file_list.remove_child(c)
		
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
		file_list.add_child(build_file_item(file, true))
		
	files.sort()
	for file : String in files:
		file_list.add_child(build_file_item(file, false))
	
	var first_button : Button = file_list.get_child(0)
	first_button.grab_focus()
	
func build_file_item(file_name: String, is_dir: bool) -> Button:
	var btn = Button.new()
	btn.text = ("📁 " if is_dir else "📄 ") + file_name
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_ALL
	btn.connect(
		"pressed", 
		Callable(self, "_on_file_pressed").bind(file_name, is_dir)
	)
	return btn

func _on_file_pressed(file_name: String, is_dir: bool):
	if is_dir:
		current_path = current_path + "/" + file_name
		update_file_list()
		emit_signal("path_changed", current_path)
	else:
		emit_signal("file_selected", file_name, is_dir)

func go_up():
	var parent = current_path.get_base_dir()
	if parent != current_path:
		current_path = parent
		update_file_list()
