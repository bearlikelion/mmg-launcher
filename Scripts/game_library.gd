class_name GameLibrary
extends Resource

# Master list of every game the launcher knows about

@export var games: Array[GameInfo] = []


# Games that should appear in the launcher row
func enabled_games() -> Array[GameInfo]:
	var result: Array[GameInfo] = []
	for game: GameInfo in games:
		if game != null and game.enabled:
			result.append(game)
	return result


# Enabled games belonging to one launcher category, in library order
func games_in_category(category: GameInfo.Category) -> Array[GameInfo]:
	var result: Array[GameInfo] = []
	for game: GameInfo in enabled_games():
		if game.category == category:
			result.append(game)
	return result


# Number of enabled games launched through Steam
func steam_count() -> int:
	var count: int = 0
	for game: GameInfo in enabled_games():
		if game.is_steam():
			count += 1
	return count
