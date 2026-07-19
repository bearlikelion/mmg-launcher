class_name DetailView
extends Control

signal launch_requested
signal closed

const MAX_MEDIA_ITEMS: int = 3
const THUMB_SIZE: Vector2 = Vector2(176, 99)

var _pulse_tween: Tween = null
var _closing: bool = false
var _game: GameInfo = null


# Connect the play button once the view enters the tree
func _ready() -> void:
	%PlayButton.pressed.connect(_on_play_button_pressed)


# Populate the terminal window from a game resource and play the opening animation
func open(game: GameInfo, accent: Color) -> void:
	_game = game
	_closing = false
	%TermTitle.text = "~/games/%s" % game.tab_name()
	%PromptLine.text = _prompt_bbcode(game)
	%DetailTitle.text = game.title.to_upper()
	%DetailDescription.text = game.description
	%MetaTree.text = _meta_bbcode(game)
	%LaunchLine.text = _launch_bbcode(game)
	%DetailInitial.text = game.title.substr(0, 1).to_upper()
	%DetailInitial.add_theme_color_override("font_color", accent)
	%DetailInitial.visible = game.cover_image == null
	%DetailCover.texture = game.cover_image
	CoverFit.apply(%DetailCover)
	%DetailCover.visible = game.cover_image != null
	_populate_media(game)
	set_running(false)
	visible = true
	%Dim.modulate.a = 0.0
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(%Dim, "modulate:a", 1.0, 0.2)
	UIAnimator.pop_in(%Window, 0.3)
	await get_tree().create_timer(0.2).timeout
	while Input.is_action_pressed("ui_accept"):
		await get_tree().process_frame
	if visible and not _closing:
		%PlayButton.grab_focus()
		_start_pulse()


# Play the closing animation, hide the view, and notify the launcher
func close() -> void:
	if _closing or not visible:
		return
	_closing = true
	_stop_pulse()
	var out_tween: Tween = UIAnimator.pop_out(%Window, 0.18)
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(%Dim, "modulate:a", 0.0, 0.18)
	await out_tween.finished
	visible = false
	closed.emit()


# Reflect whether the selected game is currently running
func set_running(running: bool) -> void:
	%PlayButton.disabled = running
	%PlayButton.text = "RUNNING..." if running else "▶  PLAY"
	if running:
		_stop_pulse()
	elif visible and not _closing:
		_start_pulse()


# Shake the window when a launch attempt fails
func play_error_feedback() -> void:
	UIAnimator.shake(%Window)


# Terminal prompt line above the game details
func _prompt_bbcode(game: GameInfo) -> String:
	var slug: String = game.title.to_lower().replace(" ", "-")
	return "[color=#%s]mark@launcher[/color] [color=#%s]~/games[/color] [color=#%s]$[/color] cat %s.md" % [
		Gruvbox.GREEN.to_html(false), Gruvbox.BLUE.to_html(false), Gruvbox.GRAY.to_html(false), slug
	]


# File-tree style metadata block listing date, dev time, features, and launch target
func _meta_bbcode(game: GameInfo) -> String:
	var rows: Array[String] = []
	if not game.date.is_empty():
		rows.append(_meta_row("released", game.date, Gruvbox.FG))
	if not game.dev_time.is_empty():
		rows.append(_meta_row("dev_time", game.dev_time, Gruvbox.FG))
	if not game.features.is_empty():
		var joined: String = " [color=#%s]::[/color] " % Gruvbox.BG3.to_html(false)
		var feature_list: Array[String] = []
		for feature: String in game.features:
			feature_list.append("[color=#%s]%s[/color]" % [Gruvbox.AQUA.to_html(false), feature.to_lower()])
		rows.append("[color=#%s]features:[/color] %s" % [Gruvbox.BLUE.to_html(false), joined.join(feature_list)])
	if game.is_steam():
		rows.append(_meta_row("launch", "steam://rungameid/%s" % game.steam_id, Gruvbox.FG2))
	else:
		rows.append(_meta_row("launch", game.executable_path.get_file(), Gruvbox.FG2))
	var lines: Array[String] = []
	for i in range(rows.size()):
		var branch: String = "└─" if i == rows.size() - 1 else "├─"
		lines.append("[color=#%s]%s[/color] %s" % [Gruvbox.GRAY.to_html(false), branch, rows[i]])
	return "\n".join(lines)


# One key/value row of the metadata tree
func _meta_row(key: String, value: String, value_color: Color) -> String:
	return "[color=#%s]%s:[/color] [color=#%s]%s[/color]" % [
		Gruvbox.BLUE.to_html(false), key, value_color.to_html(false), value
	]


# Shell-style launch command shown next to the play button
func _launch_bbcode(game: GameInfo) -> String:
	return "[color=#%s]$[/color] [color=#%s]%s[/color]" % [
		Gruvbox.GRAY.to_html(false), Gruvbox.FG2.to_html(false), game.launch_line()
	]


# Fill the media strip with screenshot thumbnails and looping video previews
func _populate_media(game: GameInfo) -> void:
	for child: Node in %MediaStrip.get_children():
		child.queue_free()
	var shown: int = 0
	for item: Resource in game.media:
		if shown >= MAX_MEDIA_ITEMS:
			break
		var media_control: Control = _build_media_item(item)
		if media_control != null:
			%MediaStrip.add_child(media_control)
			shown += 1
	%MediaStrip.visible = shown > 0


# Build a thumbnail control for one media resource
func _build_media_item(item: Resource) -> Control:
	if item is Texture2D:
		var rect: TextureRect = TextureRect.new()
		rect.texture = item as Texture2D
		rect.custom_minimum_size = THUMB_SIZE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.clip_contents = true
		return rect
	if item is VideoStream:
		var player: VideoStreamPlayer = VideoStreamPlayer.new()
		player.stream = item as VideoStream
		player.custom_minimum_size = THUMB_SIZE
		player.expand = true
		player.autoplay = true
		player.loop = true
		player.volume_db = -80.0
		return player
	return null


# Begin the idle pulse on the play button
func _start_pulse() -> void:
	_stop_pulse()
	_pulse_tween = UIAnimator.pulse(%PlayButton, 1.03, 1.2)


# Stop the idle pulse and reset the button scale
func _stop_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	%PlayButton.offset_transform_scale = Vector2.ONE


# Notify the launcher that the play button was pressed
func _on_play_button_pressed() -> void:
	launch_requested.emit()
