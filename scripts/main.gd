extends Control

@onready var left_panel : FilePanel = $Panel/VBoxContainer/PanelsContainer/LeftPanel
@onready var right_panel : FilePanel = $Panel/VBoxContainer/PanelsContainer/RightPanel
@onready var status_label : Label = $Panel/VBoxContainer/StatusBar/StatusLabel
@onready var hints_label : Label = $Panel/VBoxContainer/StatusBar/HintsLabel
@onready var confirm_dialog : ConfirmationDialog = $ConfirmDialog

var active_panel : String = "left"
var pending_operation : String = ""  # "delete", "move"
var pending_files : Array[String] = []

func _ready() -> void:
	left_panel.set_path(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))
	right_panel.set_path(OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP))

	left_panel.selection_changed.connect(_on_selection_changed)
	right_panel.selection_changed.connect(_on_selection_changed)

	confirm_dialog.confirmed.connect(_on_confirm_dialog_confirmed)
	confirm_dialog.canceled.connect(_on_confirm_dialog_canceled)

	toggle_active_panel()
	update_status()

func _unhandled_input(event) -> void:
	if event.is_action_pressed("ui_focus_next"):  # Tab or L/R bumper
		toggle_active_panel()
	elif event.is_action_pressed("ui_cancel"):  # ESC or B button
		get_active_panel().go_up()
	elif event.is_action_pressed("ui_text_backspace"):  # Backspace
		get_active_panel().go_up()
	elif event.is_action_pressed("select_file"):  # Space or X button
		get_active_panel().toggle_selection()
	elif event.is_action_pressed("copy_file"):  # F5 or Y button
		copy_files()
	elif event.is_action_pressed("move_file"):  # F6 or A+Y
		move_files()
	elif event.is_action_pressed("delete_file"):  # F8/Delete or X+A
		delete_files()
	elif event.is_action_pressed("select_all"):  # Ctrl+A
		get_active_panel().select_all()
	elif event.is_action_pressed("refresh"):  # F5 with no selection or R button
		refresh_panels()

func toggle_active_panel() -> void:
	if active_panel == "left":
		active_panel = "right"
		left_panel.modulate = Color(0.7, 0.7, 0.7)
		left_panel.is_focused = false
		right_panel.modulate = Color(1, 1, 1)
		right_panel.is_focused = true
		right_panel.grab_focus()
	else:
		active_panel = "left"
		right_panel.modulate = Color(0.7, 0.7, 0.7)
		right_panel.is_focused = false
		left_panel.modulate = Color(1, 1, 1)
		left_panel.is_focused = true
		left_panel.grab_focus()
	update_status()

func get_active_panel() -> FilePanel:
	return left_panel if active_panel == "left" else right_panel

func get_inactive_panel() -> FilePanel:
	return right_panel if active_panel == "left" else left_panel

func _on_selection_changed(_selected: Array) -> void:
	update_status()

func update_status() -> void:
	var panel = get_active_panel()
	var selected = panel.get_selected_files()
	if selected.size() > 0:
		status_label.text = "%d selected" % selected.size()
	else:
		var focused = panel.get_focused_file()
		if focused != "":
			status_label.text = focused
		else:
			status_label.text = "Ready"

func show_status(message: String) -> void:
	status_label.text = message

func copy_files() -> void:
	var source_panel = get_active_panel()
	var dest_panel = get_inactive_panel()
	var files = source_panel.get_files_for_operation()

	if files.size() == 0:
		show_status("No files selected")
		return

	var source_path = source_panel.current_path
	var dest_path = dest_panel.current_path

	var success_count = 0
	var error_count = 0

	for file_name in files:
		var src = source_path + "/" + file_name
		var dst = dest_path + "/" + file_name

		if DirAccess.dir_exists_absolute(src):
			if copy_directory_recursive(src, dst):
				success_count += 1
			else:
				error_count += 1
		else:
			if DirAccess.copy_absolute(src, dst) == OK:
				success_count += 1
			else:
				error_count += 1

	dest_panel.refresh()
	source_panel.deselect_all()

	if error_count == 0:
		show_status("Copied %d item(s)" % success_count)
	else:
		show_status("Copied %d, failed %d" % [success_count, error_count])

func copy_directory_recursive(src: String, dst: String) -> bool:
	var dir = DirAccess.open(src)
	if dir == null:
		return false

	if not DirAccess.dir_exists_absolute(dst):
		DirAccess.make_dir_recursive_absolute(dst)

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var src_path = src + "/" + file_name
			var dst_path = dst + "/" + file_name

			if dir.current_is_dir():
				if not copy_directory_recursive(src_path, dst_path):
					return false
			else:
				if DirAccess.copy_absolute(src_path, dst_path) != OK:
					return false

		file_name = dir.get_next()

	return true

func move_files() -> void:
	var source_panel = get_active_panel()
	var files = source_panel.get_files_for_operation()

	if files.size() == 0:
		show_status("No files selected")
		return

	pending_operation = "move"
	pending_files = files.duplicate()
	confirm_dialog.dialog_text = "Move %d item(s) to other panel?" % files.size()
	confirm_dialog.popup_centered()

func delete_files() -> void:
	var source_panel = get_active_panel()
	var files = source_panel.get_files_for_operation()

	if files.size() == 0:
		show_status("No files selected")
		return

	pending_operation = "delete"
	pending_files = files.duplicate()
	confirm_dialog.dialog_text = "Delete %d item(s)? This cannot be undone." % files.size()
	confirm_dialog.popup_centered()

func _on_confirm_dialog_confirmed() -> void:
	if pending_operation == "delete":
		execute_delete()
	elif pending_operation == "move":
		execute_move()
	pending_operation = ""
	pending_files.clear()

func _on_confirm_dialog_canceled() -> void:
	pending_operation = ""
	pending_files.clear()
	show_status("Cancelled")

func execute_delete() -> void:
	var source_panel = get_active_panel()
	var source_path = source_panel.current_path

	var success_count = 0
	var error_count = 0

	for file_name in pending_files:
		var path = source_path + "/" + file_name

		if DirAccess.dir_exists_absolute(path):
			if delete_directory_recursive(path):
				success_count += 1
			else:
				error_count += 1
		else:
			if DirAccess.remove_absolute(path) == OK:
				success_count += 1
			else:
				error_count += 1

	source_panel.refresh()

	if error_count == 0:
		show_status("Deleted %d item(s)" % success_count)
	else:
		show_status("Deleted %d, failed %d" % [success_count, error_count])

func delete_directory_recursive(path: String) -> bool:
	var dir = DirAccess.open(path)
	if dir == null:
		return false

	dir.list_dir_begin()
	var file_name = dir.get_next()

	while file_name != "":
		if file_name != "." and file_name != "..":
			var full_path = path + "/" + file_name

			if dir.current_is_dir():
				if not delete_directory_recursive(full_path):
					return false
			else:
				if DirAccess.remove_absolute(full_path) != OK:
					return false

		file_name = dir.get_next()

	return DirAccess.remove_absolute(path) == OK

func execute_move() -> void:
	var source_panel = get_active_panel()
	var dest_panel = get_inactive_panel()
	var source_path = source_panel.current_path
	var dest_path = dest_panel.current_path

	var success_count = 0
	var error_count = 0

	for file_name in pending_files:
		var src = source_path + "/" + file_name
		var dst = dest_path + "/" + file_name

		if DirAccess.rename_absolute(src, dst) == OK:
			success_count += 1
		else:
			# Try copy then delete for cross-filesystem moves
			if DirAccess.dir_exists_absolute(src):
				if copy_directory_recursive(src, dst) and delete_directory_recursive(src):
					success_count += 1
				else:
					error_count += 1
			else:
				if DirAccess.copy_absolute(src, dst) == OK:
					if DirAccess.remove_absolute(src) == OK:
						success_count += 1
					else:
						error_count += 1
				else:
					error_count += 1

	source_panel.refresh()
	dest_panel.refresh()

	if error_count == 0:
		show_status("Moved %d item(s)" % success_count)
	else:
		show_status("Moved %d, failed %d" % [success_count, error_count])

func refresh_panels() -> void:
	left_panel.refresh()
	right_panel.refresh()
	show_status("Refreshed")
