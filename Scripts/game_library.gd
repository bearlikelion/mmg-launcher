class_name GameLibrary
extends Resource

@export var games: Array[GameInfo] = []


func enabled_games() -> Array[GameInfo]:
	var result: Array[GameInfo] = []
	for game: GameInfo in games:
		if game != null and game.enabled:
			result.append(game)
	return result


func games_in_category(category: GameInfo.Category) -> Array[GameInfo]:
	var result: Array[GameInfo] = []
	for game: GameInfo in enabled_games():
		if game.category == category:
			result.append(game)
	return result
