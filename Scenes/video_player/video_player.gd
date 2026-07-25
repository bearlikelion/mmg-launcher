class_name VideoPlayerOverlay
extends Control

signal closed

const BAR_HIDE_DELAY: float = 2.5
const SEEK_STEP: float = 10.0

var _bar_idle: float = 0.0
var _bar_shown: bool = true
var _bar_tween: Tween = null


func _ready() -> void:
	%Player.finished.connect(_on_player_finished)


func play_video(stream: VideoStream, accent: Color, qr_code: Texture2D = null) -> void:
	%ProgressFill.color = accent
	%Frame.ratio = 16.0 / 9.0
	%QRBadge.visible = qr_code != null
	%QRBadgeImage.texture = qr_code
	%CmdLine.text = _cmd_bbcode(stream)
	%Player.stream = stream
	%Player.paused = false
	%Player.play()
	%HintLabel.text = "A: Pause      B: Back"
	visible = true
	_show_bar()
	get_viewport().gui_release_focus()
	grab_focus.call_deferred()


func stop_and_close() -> void:
	if not visible:
		return
	%Player.stop()
	%Player.stream = null
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		stop_and_close()
	elif event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_toggle_paused()
	elif event.is_action_pressed("ui_left", true):
		get_viewport().set_input_as_handled()
		_seek_by(-SEEK_STEP)
	elif event.is_action_pressed("ui_right", true):
		get_viewport().set_input_as_handled()
		_seek_by(SEEK_STEP)
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseMotion:
		_show_bar()


func _gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_toggle_paused()


# The bar only idles out while playing, so a paused video keeps its controls
func _process(delta: float) -> void:
	if not visible:
		return
	_update_ratio()
	_update_progress()
	if %Player.paused:
		return
	_bar_idle += delta
	if _bar_shown and _bar_idle > BAR_HIDE_DELAY:
		_hide_bar()


func _toggle_paused() -> void:
	%Player.paused = not %Player.paused
	%HintLabel.text = "A: Play      B: Back" if %Player.paused else "A: Pause      B: Back"
	_show_bar()


func _seek_by(offset: float) -> void:
	var length: float = %Player.get_stream_length()
	if length <= 0.0:
		return
	%Player.stream_position = clampf(%Player.stream_position + offset, 0.0, length - 0.1)
	_show_bar()


# Ratio is unknown until the decoder produces a frame, so re-check each tick
func _update_ratio() -> void:
	var texture: Texture2D = %Player.get_video_texture()
	if texture == null:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.y > 0.0:
		%Frame.ratio = texture_size.x / texture_size.y


func _update_progress() -> void:
	var length: float = %Player.get_stream_length()
	var position_seconds: float = %Player.stream_position
	if length > 0.0:
		%TimeLabel.text = "%s / %s" % [_format_time(position_seconds), _format_time(length)]
		%ProgressFill.anchor_right = clampf(position_seconds / length, 0.0, 1.0)
	else:
		%TimeLabel.text = _format_time(position_seconds)
	%ProgressTrack.visible = length > 0.0


func _cmd_bbcode(stream: VideoStream) -> String:
	return "[color=#%s]$[/color] [color=#%s]mpv %s[/color]" % [
		Gruvbox.GRAY.to_html(false), Gruvbox.FG2.to_html(false), stream.file.get_file()
	]


func _format_time(seconds: float) -> String:
	var minutes: int = int(seconds / 60.0)
	var remainder: int = int(seconds) % 60
	return "%02d:%02d" % [minutes, remainder]


func _show_bar() -> void:
	_bar_idle = 0.0
	if _bar_shown:
		return
	_bar_shown = true
	_fade_bar_to(1.0)


func _hide_bar() -> void:
	_bar_shown = false
	_fade_bar_to(0.0)


func _fade_bar_to(alpha: float) -> void:
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	_bar_tween = create_tween()
	_bar_tween.tween_property(%BarMargin, "modulate:a", alpha, 0.25)


func _on_player_finished() -> void:
	stop_and_close()
