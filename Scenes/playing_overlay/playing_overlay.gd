class_name PlayingOverlay
extends Control

# Full-screen canvas shown while a game process runs, swallowing all launcher input


# Show the canvas for the running game and steal focus so nothing else gets input
func open(game: GameInfo, accent: Color) -> void:
	%PromptLine.text = "[color=#%s]$[/color] [color=#%s]%s[/color]" % [
		Gruvbox.GRAY.to_html(false), Gruvbox.FG2.to_html(false), game.launch_line()
	]
	%PlayingTitle.text = "PLAYING: %s" % game.title.to_upper()
	%PlayingInitial.text = game.title.substr(0, 1).to_upper()
	%PlayingInitial.add_theme_color_override("font_color", accent)
	%PlayingInitial.visible = game.cover_image == null
	%PlayingCover.texture = game.cover_image
	CoverFit.apply(%PlayingCover)
	%PlayingCover.visible = game.cover_image != null
	var hint: String = "come back to the launcher when you finish playing" if game.is_steam() else "waiting for the game to exit"
	%InfoLine.text = "[color=#%s]└─[/color] [color=#%s]%s[/color]" % [
		Gruvbox.GRAY.to_html(false), Gruvbox.FG2.to_html(false), hint
	]
	visible = true
	grab_focus()


# Hide the canvas once the game session is over
func close() -> void:
	visible = false


# Swallow every input event while a game is running
func _gui_input(_event: InputEvent) -> void:
	accept_event()
