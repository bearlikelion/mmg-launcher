class_name GameInfo
extends Resource

# Data for a single game shown in the launcher, authored as a .tres in Resources/Games/

enum Category { STEAM, PROTOTYPE, GAME_JAM, VIDEO, OPEN_SOURCE }

@export var enabled: bool = true
@export var category: Category = Category.PROTOTYPE
@export var title: String = ""
@export_multiline var description: String = ""
@export var date: String = ""
@export var dev_time: String = ""
@export var features: PackedStringArray = PackedStringArray()
@export var cover_image: Texture2D = null
@export var media: Array[Resource] = []
@export_global_file var executable_path: String = ""
@export var steam_id: String = ""


# A game launches through Steam when it has an app id
func is_steam() -> bool:
	return not steam_id.is_empty()


# Absolute filesystem path to the executable, resolving res:// bundles and paths
# relative to the launcher (Build/ in the editor, the binary's directory in exports).
# Absolute paths that do not exist on this machine but contain a Games/ folder are
# re-based onto the launcher directory, so editor-saved dev paths still work on device
func resolved_executable_path() -> String:
	if executable_path.begins_with("res://") or executable_path.begins_with("user://"):
		return ProjectSettings.globalize_path(executable_path)
	if executable_path.is_empty():
		return executable_path
	var relative_path: String = executable_path
	if relative_path.is_absolute_path():
		if FileAccess.file_exists(relative_path):
			return relative_path
		var games_index: int = relative_path.find("/Games/")
		if games_index == -1:
			return relative_path
		relative_path = relative_path.substr(games_index + 1)
	var base_dir: String = OS.get_executable_path().get_base_dir()
	if OS.has_feature("editor"):
		base_dir = ProjectSettings.globalize_path("res://Build")
	return base_dir.path_join(relative_path)


# Lowercase file-style name shown in the card editor tab
func tab_name() -> String:
	if is_steam():
		return "%s.steam" % title.to_lower().replace(" ", "-")
	if not executable_path.is_empty():
		return executable_path.get_file()
	return "%s.x86_64" % title.to_lower().replace(" ", "-")


# Shell-flavored launch line shown in the detail view footer
func launch_line() -> String:
	if is_steam():
		return "steam -applaunch %s" % steam_id
	if not executable_path.is_empty():
		return "./%s" % executable_path.get_file()
	return "./%s" % tab_name()
