class_name DetailView
extends Control

signal launch_requested
signal closed

const MAX_MEDIA_ITEMS: int = 3
const THUMB_SIZE: Vector2 = Vector2(176, 99)
const VIDEO_TILE_SIZE: Vector2 = Vector2(300, 169)

var _pulse_tween: Tween = null
var _closing: bool = false
var _game: GameInfo = null
var _accent: Color = Gruvbox.AQUA
var _video_tiles: Array[Button] = []
var _last_tile: Button = null


# Connect the play button and overlays once the view enters the tree
func _ready() -> void:
	%PlayButton.pressed.connect(_on_play_button_pressed)
	%VideoOverlay.closed.connect(_on_video_overlay_closed)
	%ControlsButton.pressed.connect(_on_controls_pressed)
	%ControlsOverlay.closed.connect(_on_controls_closed)
	_style_controls_button()


# Populate the terminal window from a game resource and play the opening animation
func open(game: GameInfo, accent: Color) -> void:
	_game = game
	_accent = accent
	_closing = false
	_last_tile = null
	%PlayButton.visible = not game.is_video()
	%ControlsButton.visible = not game.controls.is_empty()
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
	%QRImage.texture = game.qr_code
	%WishlistPanel.visible = game.qr_code != null
	%WishlistText.text = "[color=#%s]scan to[/color]\n[color=#%s]WISHLIST[/color]\n[color=#%s]on steam[/color]" % [
		Gruvbox.FG2.to_html(false), Gruvbox.YELLOW.to_html(false), Gruvbox.FG2.to_html(false)
	]
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
		if game.is_video() and not _video_tiles.is_empty():
			_video_tiles[0].grab_focus()
		else:
			%PlayButton.grab_focus()
			_start_pulse()


# Play the closing animation, hide the view, and notify the launcher
func close() -> void:
	if _closing or not visible:
		return
	%VideoOverlay.stop_and_close()
	%ControlsOverlay.close()
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
	if not game.developer.is_empty():
		rows.append(_meta_row("made_by", game.developer, Gruvbox.FG))
	if not game.date.is_empty():
		rows.append(_meta_row("released", game.date, Gruvbox.FG))
	if not game.dev_time.is_empty():
		rows.append(_meta_row("dev_time", game.dev_time, Gruvbox.FG))
	if not game.wishlist_url.is_empty():
		var display_url: String = game.wishlist_url.trim_prefix("https://").split("?")[0]
		rows.append(_meta_row("wishlist", display_url, Gruvbox.YELLOW))
	if not game.features.is_empty():
		var joined: String = " [color=#%s]::[/color] " % Gruvbox.BG3.to_html(false)
		var feature_list: Array[String] = []
		for feature: String in game.features:
			feature_list.append("[color=#%s]%s[/color]" % [Gruvbox.AQUA.to_html(false), feature.to_lower()])
		rows.append("[color=#%s]features:[/color] %s" % [Gruvbox.BLUE.to_html(false), joined.join(feature_list)])
	if game.is_video():
		var clip_count: int = game.video_streams().size()
		rows.append(_meta_row("media", "%d clip%s" % [clip_count, "" if clip_count == 1 else "s"], Gruvbox.FG2))
	elif game.is_steam():
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


# Fill the media strip with screenshot thumbnails and playable video tiles
func _populate_media(game: GameInfo) -> void:
	_video_tiles.clear()
	for child: Node in %MediaStrip.get_children():
		child.queue_free()
	var shown: int = 0
	for item: Resource in game.media:
		if shown >= MAX_MEDIA_ITEMS:
			break
		var media_control: Control = _build_media_item(item, game)
		if media_control != null:
			%MediaStrip.add_child(media_control)
			shown += 1
	%MediaStrip.visible = shown > 0


# Build a thumbnail control for one media resource
func _build_media_item(item: Resource, game: GameInfo) -> Control:
	if item is Texture2D:
		var rect: TextureRect = TextureRect.new()
		rect.texture = item as Texture2D
		rect.custom_minimum_size = THUMB_SIZE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		rect.clip_contents = true
		return rect
	if item is VideoStream:
		return _build_video_tile(item as VideoStream, game)
	return null


# Build a focusable gallery tile that previews on highlight and plays fullscreen when pressed
func _build_video_tile(stream: VideoStream, game: GameInfo) -> Button:
	var tile: Button = Button.new()
	tile.custom_minimum_size = _video_tile_size(game)
	tile.clip_contents = true
	tile.add_theme_stylebox_override("normal", _tile_stylebox(Gruvbox.BG3, 1))
	tile.add_theme_stylebox_override("hover", _tile_stylebox(_accent, 1))
	tile.add_theme_stylebox_override("pressed", _tile_stylebox(_accent, 1))
	tile.add_theme_stylebox_override("focus", _tile_stylebox(_accent, 2))
	var player: VideoStreamPlayer = VideoStreamPlayer.new()
	player.stream = stream
	player.expand = true
	player.loop = true
	player.volume_db = -80.0
	player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.set_anchors_preset(Control.PRESET_FULL_RECT)
	player.offset_left = 2.0
	player.offset_top = 2.0
	player.offset_right = -2.0
	player.offset_bottom = -2.0
	tile.add_child(player)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.offset_left = 2.0
	dim.offset_top = 2.0
	dim.offset_right = -2.0
	dim.offset_bottom = -2.0
	tile.add_child(dim)
	var glyph: Label = Label.new()
	glyph.text = "▶"
	glyph.add_theme_font_size_override("font_size", 40 if game.is_video() else 26)
	glyph.add_theme_color_override("font_color", Color(Gruvbox.FG, 0.9))
	glyph.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	glyph.add_theme_constant_override("shadow_offset_x", 2)
	glyph.add_theme_constant_override("shadow_offset_y", 2)
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	tile.add_child(glyph)
	var caption: Label = Label.new()
	caption.text = stream.file.get_file()
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Gruvbox.FG)
	caption.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	caption.add_theme_constant_override("shadow_offset_x", 1)
	caption.add_theme_constant_override("shadow_offset_y", 1)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	caption.offset_left = 8.0
	caption.offset_right = -8.0
	caption.offset_top = -28.0
	caption.offset_bottom = -6.0
	tile.add_child(caption)
	tile.set_meta("player", player)
	tile.set_meta("dim", dim)
	tile.set_meta("glyph", glyph)
	tile.pressed.connect(_on_video_tile_pressed.bind(stream, tile))
	tile.focus_entered.connect(_refresh_tile.bind(tile))
	tile.focus_exited.connect(_refresh_tile.bind(tile))
	tile.mouse_entered.connect(_refresh_tile.bind(tile))
	tile.mouse_exited.connect(_refresh_tile.bind(tile))
	_video_tiles.append(tile)
	_prime_preview(tile)
	return tile


# Size gallery tiles to share the cover column width, small thumbs for regular games
func _video_tile_size(game: GameInfo) -> Vector2:
	if not game.is_video():
		return THUMB_SIZE
	var clip_count: int = maxi(1, mini(game.video_streams().size(), MAX_MEDIA_ITEMS))
	var width: float = minf(VIDEO_TILE_SIZE.x, (560.0 - 10.0 * float(clip_count - 1)) / float(clip_count))
	return Vector2(width, roundf(width * 9.0 / 16.0))


# Decode the first frame so an unfocused tile shows a dimmed poster instead of black
func _prime_preview(tile: Button) -> void:
	var player: VideoStreamPlayer = tile.get_meta("player") as VideoStreamPlayer
	if not tile.is_inside_tree():
		await tile.tree_entered
	player.play()
	for i in range(12):
		await get_tree().process_frame
		if not is_instance_valid(player):
			return
		var texture: Texture2D = player.get_video_texture()
		if texture != null and texture.get_size().x > 0.0:
			break
	if is_instance_valid(tile):
		_refresh_tile(tile)


# Play the preview only while its tile is highlighted, dimmed poster otherwise
func _refresh_tile(tile: Button) -> void:
	if not is_instance_valid(tile) or not tile.has_meta("player"):
		return
	var player: VideoStreamPlayer = tile.get_meta("player") as VideoStreamPlayer
	var dim: ColorRect = tile.get_meta("dim") as ColorRect
	var glyph: Label = tile.get_meta("glyph") as Label
	var active: bool = (tile.has_focus() or tile.is_hovered()) and not %VideoOverlay.visible
	if active and not player.is_playing():
		player.play()
	player.paused = not active
	dim.visible = not active
	glyph.visible = not active


# Bordered stylebox used for the gallery tile states
func _tile_stylebox(border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Gruvbox.BG0H
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	return style


# Re-evaluate every tile's preview state, e.g. around fullscreen playback
func _refresh_all_tiles() -> void:
	for tile: Button in _video_tiles:
		_refresh_tile(tile)


# Open the fullscreen player for a pressed gallery tile
func _on_video_tile_pressed(stream: VideoStream, tile: Button) -> void:
	if %VideoOverlay.visible:
		return
	_last_tile = tile
	_stop_pulse()
	%VideoOverlay.play_video(stream, _accent, _game.qr_code if _game != null else null)
	_refresh_all_tiles()


# Restore focus and previews when the fullscreen player closes
func _on_video_overlay_closed() -> void:
	_refresh_all_tiles()
	if not visible or _closing:
		return
	if _last_tile != null and is_instance_valid(_last_tile):
		_last_tile.grab_focus()
	if _game != null and not _game.is_video():
		_start_pulse()


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


# Open the controller layout overlay for the current game
func _on_controls_pressed() -> void:
	if _game == null or %ControlsOverlay.visible:
		return
	%ControlsOverlay.open(_game, _accent)


# Return focus to the controls button when the layout overlay closes
func _on_controls_closed() -> void:
	if visible and not _closing:
		%ControlsButton.grab_focus()


# Rounded pill styles matching the play button, tinted for the controls action
func _style_controls_button() -> void:
	var normal: StyleBoxFlat = _controls_stylebox(Color(Gruvbox.BLUE, 0.08))
	var hover: StyleBoxFlat = _controls_stylebox(Color(Gruvbox.BLUE, 0.18))
	var focus: StyleBoxFlat = _controls_stylebox(Color(0.0, 0.0, 0.0, 0.0))
	focus.draw_center = false
	focus.border_color = Gruvbox.YELLOW
	focus.set_border_width_all(2)
	focus.content_margin_left = 0.0
	focus.content_margin_right = 0.0
	focus.content_margin_top = 0.0
	focus.content_margin_bottom = 0.0
	%ControlsButton.add_theme_stylebox_override("normal", normal)
	%ControlsButton.add_theme_stylebox_override("hover", hover)
	%ControlsButton.add_theme_stylebox_override("pressed", hover)
	%ControlsButton.add_theme_stylebox_override("focus", focus)


# One pill stylebox for the controls button states
func _controls_stylebox(bg_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = Gruvbox.BLUE
	style.set_border_width_all(1)
	style.set_corner_radius_all(20)
	style.content_margin_left = 26.0
	style.content_margin_right = 26.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style


# Notify the launcher that the play button was pressed
func _on_play_button_pressed() -> void:
	launch_requested.emit()
