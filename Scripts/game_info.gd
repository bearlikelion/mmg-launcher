class_name GameInfo
extends Resource

# Authored as a .tres in Resources/Games/

enum Category { STEAM, PROTOTYPE, GAME_JAM, VIDEO, OPEN_SOURCE }

@export var enabled: bool = true
@export var category: Category = Category.PROTOTYPE
@export var title: String = ""
@export_multiline var description: String = ""
@export var date: String = ""
@export var dev_time: String = ""
@export var developer: String = ""
@export var wishlist_url: String = ""
@export var qr_code: Texture2D = null
@export var features: PackedStringArray = PackedStringArray()
@export var controls: Dictionary = {}
@export var cover_image: Texture2D = null
@export var media: Array[Resource] = []
@export_global_file var executable_path: String = ""
@export var steam_id: String = ""


func is_steam() -> bool:
	return not steam_id.is_empty()


func is_video() -> bool:
	return category == Category.VIDEO


func video_streams() -> Array[VideoStream]:
	var streams: Array[VideoStream] = []
	for item: Resource in media:
		if item is VideoStream:
			streams.append(item as VideoStream)
	return streams


func first_video_file() -> String:
	var streams: Array[VideoStream] = video_streams()
	if streams.is_empty():
		return "%s.mp4" % title.to_lower().replace(" ", "-")
	return streams[0].file.get_file()


# Entries are authored with .x86_64 paths, so Windows launches the .exe sibling
static func platform_executable(path: String) -> String:
	if OS.has_feature("windows") and path.ends_with(".x86_64"):
		return path.trim_suffix(".x86_64") + ".exe"
	return path


# Videos and Steam entries always work, local games need the executable present
func is_available() -> bool:
	if is_video() or is_steam():
		return true
	if executable_path.is_empty():
		return false
	return FileAccess.file_exists(resolved_executable_path())


func resolved_executable_path() -> String:
	return platform_executable(_resolved_linux_path())


# Relative paths resolve against Build/ in the editor, the binary's dir in exports
func _resolved_linux_path() -> String:
	if executable_path.begins_with("res://") or executable_path.begins_with("user://"):
		return ProjectSettings.globalize_path(executable_path)
	if executable_path.is_empty():
		return executable_path
	var relative_path: String = executable_path
	if relative_path.is_absolute_path():
		if FileAccess.file_exists(relative_path):
			return relative_path
		# Re-base editor-saved dev paths onto the launcher dir so they work on device
		var games_index: int = relative_path.find("/Games/")
		if games_index == -1:
			return relative_path
		relative_path = relative_path.substr(games_index + 1)
	var base_dir: String = OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		base_dir = ProjectSettings.globalize_path("res://Build")
	return base_dir.path_join(relative_path)


func tab_name() -> String:
	if is_video():
		return first_video_file()
	if is_steam():
		return "%s.steam" % title.to_lower().replace(" ", "-")
	if not executable_path.is_empty():
		return platform_executable(executable_path.get_file())
	return platform_executable("%s.x86_64" % title.to_lower().replace(" ", "-"))


func launch_line() -> String:
	if is_video():
		return "mpv %s" % first_video_file()
	if is_steam():
		return "steam -applaunch %s" % steam_id
	if not executable_path.is_empty():
		return "./%s" % platform_executable(executable_path.get_file())
	return "./%s" % tab_name()
