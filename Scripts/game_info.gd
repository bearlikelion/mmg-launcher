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


# Absolute filesystem path to the executable, resolving res:// bundles
func resolved_executable_path() -> String:
	if executable_path.begins_with("res://") or executable_path.begins_with("user://"):
		return ProjectSettings.globalize_path(executable_path)
	return executable_path


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
