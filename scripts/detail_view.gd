class_name DetailView
extends Control

signal launch_requested
signal closed

const BYTES_PER_MEGABYTE: float = 1048576.0

var _pulse_tween: Tween = null
var _closing: bool = false


# Connect the play button once the view enters the tree
func _ready() -> void:
	%PlayButton.pressed.connect(_on_play_button_pressed)


# Populate the panel from a card and play the opening animation
func open(card: GameCard) -> void:
	_closing = false
	%DetailTitle.text = card.game_title
	%DetailBlurb.text = card.blurb
	%DetailInitial.text = card.game_title.substr(0, 1).to_upper()
	%DetailArt.color = card.accent
	%DetailInfo.text = _describe_file(card.exec_path)
	_style_play_button(card.accent)
	set_running(false)
	visible = true
	%Dim.modulate.a = 0.0
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(%Dim, "modulate:a", 1.0, 0.2)
	UIAnimator.pop_in(%DetailPanel, 0.3)
	UIAnimator.slide_in(%DetailArt, Vector2(-48.0, 0.0), 0.3, 0.05)
	UIAnimator.slide_in(%DetailTitle, Vector2(48.0, 0.0), 0.3, 0.1)
	UIAnimator.slide_in(%DetailBlurb, Vector2(48.0, 0.0), 0.3, 0.16)
	UIAnimator.slide_in(%DetailInfo, Vector2(48.0, 0.0), 0.3, 0.22)
	UIAnimator.slide_in(%PlayButton, Vector2(0.0, 32.0), 0.3, 0.28)
	await get_tree().create_timer(0.2).timeout
	if visible and not _closing:
		%PlayButton.grab_focus()
		_start_pulse()


# Play the closing animation, hide the view, and notify the launcher
func close() -> void:
	if _closing or not visible:
		return
	_closing = true
	_stop_pulse()
	var out_tween: Tween = UIAnimator.pop_out(%DetailPanel, 0.18)
	var dim_tween: Tween = create_tween()
	dim_tween.tween_property(%Dim, "modulate:a", 0.0, 0.18)
	await out_tween.finished
	visible = false
	closed.emit()


# Reflect whether the selected game is currently running
func set_running(running: bool) -> void:
	%PlayButton.disabled = running
	%PlayButton.text = "RUNNING..." if running else "PLAY"
	if running:
		_stop_pulse()
	elif visible and not _closing:
		_start_pulse()


# Shake the panel when a launch attempt fails
func play_error_feedback() -> void:
	UIAnimator.shake(%DetailPanel)


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


# Build the info line describing the game executable on disk
func _describe_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "Executable not found: %s" % path
	var size_text: String = "unknown size"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file != null:
		size_text = "%.0f MB" % (float(file.get_length()) / BYTES_PER_MEGABYTE)
	var modified: int = FileAccess.get_modified_time(path)
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(modified)
	return "%s   |   %s   |   Updated %04d-%02d-%02d" % [path.get_file(), size_text, date.year, date.month, date.day]


# Tint the play button styleboxes with the game accent color
func _style_play_button(accent: Color) -> void:
	var normal_style: StyleBoxFlat = %PlayButton.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	if normal_style == null:
		return
	normal_style.bg_color = accent.darkened(0.45)
	var hover_style: StyleBoxFlat = normal_style.duplicate() as StyleBoxFlat
	hover_style.bg_color = accent.darkened(0.25)
	%PlayButton.add_theme_stylebox_override("normal", normal_style)
	%PlayButton.add_theme_stylebox_override("hover", hover_style)
	%PlayButton.add_theme_stylebox_override("pressed", hover_style)


# Notify the launcher that the play button was pressed
func _on_play_button_pressed() -> void:
	launch_requested.emit()
