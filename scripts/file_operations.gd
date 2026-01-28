class_name FileOperations
extends RefCounted
## Utility class for file system operations.
##
## This class provides static methods for common file operations
## like copying, moving, and deleting files and directories.


## Copies a file or directory from source to destination.
## Returns true on success, false on failure.
static func copy_item(src: String, dst: String) -> bool:
	if DirAccess.dir_exists_absolute(src):
		return copy_directory(src, dst)
	return DirAccess.copy_absolute(src, dst) == OK


## Recursively copies a directory and its contents.
static func copy_directory(src: String, dst: String) -> bool:
	var dir := DirAccess.open(src)
	if dir == null:
		push_error("FileOperations: Cannot open directory: %s" % src)
		return false

	if not DirAccess.dir_exists_absolute(dst):
		var err := DirAccess.make_dir_recursive_absolute(dst)
		if err != OK:
			push_error("FileOperations: Cannot create directory: %s" % dst)
			return false

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var src_path := src.path_join(file_name)
			var dst_path := dst.path_join(file_name)

			if dir.current_is_dir():
				if not copy_directory(src_path, dst_path):
					dir.list_dir_end()
					return false
			else:
				if DirAccess.copy_absolute(src_path, dst_path) != OK:
					push_error("FileOperations: Cannot copy file: %s" % src_path)
					dir.list_dir_end()
					return false

		file_name = dir.get_next()

	dir.list_dir_end()
	return true


## Deletes a file or directory.
## Returns true on success, false on failure.
static func delete_item(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		return delete_directory(path)
	return DirAccess.remove_absolute(path) == OK


## Recursively deletes a directory and its contents.
static func delete_directory(path: String) -> bool:
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("FileOperations: Cannot open directory for deletion: %s" % path)
		return false

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while not file_name.is_empty():
		if file_name != "." and file_name != "..":
			var full_path := path.path_join(file_name)

			if dir.current_is_dir():
				if not delete_directory(full_path):
					dir.list_dir_end()
					return false
			else:
				if DirAccess.remove_absolute(full_path) != OK:
					push_error("FileOperations: Cannot delete file: %s" % full_path)
					dir.list_dir_end()
					return false

		file_name = dir.get_next()

	dir.list_dir_end()
	return DirAccess.remove_absolute(path) == OK


## Moves a file or directory from source to destination.
## Tries rename first, falls back to copy+delete for cross-filesystem moves.
static func move_item(src: String, dst: String) -> bool:
	# Try direct rename first (same filesystem)
	if DirAccess.rename_absolute(src, dst) == OK:
		return true

	# Fallback to copy + delete (cross-filesystem)
	if copy_item(src, dst):
		return delete_item(src)

	return false


## Renames a file or directory.
static func rename_item(old_path: String, new_path: String) -> bool:
	if FileAccess.file_exists(new_path) or DirAccess.dir_exists_absolute(new_path):
		push_error("FileOperations: Destination already exists: %s" % new_path)
		return false

	return DirAccess.rename_absolute(old_path, new_path) == OK


## Creates a new directory.
static func create_directory(path: String) -> bool:
	if DirAccess.dir_exists_absolute(path):
		push_error("FileOperations: Directory already exists: %s" % path)
		return false

	return DirAccess.make_dir_absolute(path) == OK


## Returns the home directory path.
static func get_home_directory() -> String:
	var home := OS.get_environment("HOME")
	if not home.is_empty() and DirAccess.dir_exists_absolute(home):
		return home

	home = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).get_base_dir()
	if DirAccess.dir_exists_absolute(home):
		return home

	return OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)


## Formats a file size in bytes to human-readable string.
static func format_size(bytes: int) -> String:
	const KB := 1024
	const MB := KB * 1024
	const GB := MB * 1024

	if bytes < KB:
		return "%d B" % bytes
	elif bytes < MB:
		return "%.1f KB" % (bytes / float(KB))
	elif bytes < GB:
		return "%.1f MB" % (bytes / float(MB))
	else:
		return "%.1f GB" % (bytes / float(GB))


## Returns an emoji icon for a file based on its extension.
static func get_file_icon(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()

	match ext:
		"png", "jpg", "jpeg", "gif", "webp", "svg", "bmp", "ico":
			return "🖼️"
		"mp3", "wav", "ogg", "flac", "m4a", "aac":
			return "🎵"
		"mp4", "mkv", "avi", "mov", "webm", "m4v":
			return "🎬"
		"zip", "tar", "gz", "7z", "rar", "bz2", "xz":
			return "📦"
		"exe", "app", "sh", "bin", "cmd", "bat":
			return "⚡"
		"pdf":
			return "📕"
		"doc", "docx", "odt", "rtf":
			return "📘"
		"xls", "xlsx", "ods", "csv":
			return "📊"
		"ppt", "pptx", "odp":
			return "📽️"
		"txt", "md", "log", "readme":
			return "📝"
		"gd", "py", "js", "ts", "rs", "go", "c", "cpp", "h", "hpp", "java", "kt", "swift":
			return "💻"
		"json", "xml", "yaml", "yml", "toml", "ini", "cfg", "conf":
			return "⚙️"
		"html", "htm", "css", "scss", "sass":
			return "🌐"
		"ttf", "otf", "woff", "woff2":
			return "🔤"
		_:
			return "📄"
