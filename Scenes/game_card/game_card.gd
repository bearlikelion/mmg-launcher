class_name GameCard
extends Button

signal selected(card: GameCard)

const FOCUS_SCALE: Vector2 = Vector2(1.04, 1.04)

var game: GameInfo = null
var accent: Color = Gruvbox.AQUA

var _entrance_tween: Tween = null
var _focus_tween: Tween = null


# Connect interaction signals when the card enters the tree
func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_on_pressed)


# Fill the card from a GameInfo resource in the library
func setup(game_data: GameInfo, index: int) -> void:
	game = game_data
	accent = Gruvbox.accent_for_index(index)
	%TabLabel.text = game.tab_name()
	%TitleLabel.text = game.title
	%DescLabel.text = game.description
	%DateLabel.text = game.date
	%InitialLabel.text = game.title.substr(0, 1).to_upper()
	%InitialLabel.add_theme_color_override("font_color", accent)
	if game.is_steam():
		%PlatformLabel.text = "steam"
		%PlatformLabel.add_theme_color_override("font_color", Gruvbox.GREEN)
	else:
		%PlatformLabel.text = "local"
		%PlatformLabel.add_theme_color_override("font_color", Gruvbox.BLUE)
	if game.cover_image != null:
		%CoverImage.texture = game.cover_image
		CoverFit.apply(%CoverImage)
		%CoverImage.visible = true
		%InitialLabel.visible = false
	var tab_style: StyleBoxFlat = %TabName.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if tab_style != null:
		tab_style.border_color = accent
		%TabName.add_theme_stylebox_override("panel", tab_style)


# Pop the card in as part of the staggered row entrance
func play_entrance(delay: float) -> void:
	_entrance_tween = UIAnimator.pop_in(self, 0.4, delay)


# Kill a running entrance animation and snap to the settled state
func _settle() -> void:
	if _entrance_tween != null and _entrance_tween.is_valid():
		_entrance_tween.kill()
		_entrance_tween = null
		modulate.a = 1.0
		offset_transform_position = Vector2.ZERO


# Grow the card when it gains focus
func _on_focus_entered() -> void:
	_settle()
	z_index = 1
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = UIAnimator.scale_to(self, FOCUS_SCALE, 0.15)


# Shrink the card back to normal size when focus moves away
func _on_focus_exited() -> void:
	z_index = 0
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = UIAnimator.scale_to(self, Vector2.ONE, 0.15)


# Tell the launcher this game was chosen
func _on_pressed() -> void:
	selected.emit(self)
