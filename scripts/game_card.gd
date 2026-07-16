class_name GameCard
extends Button

signal selected(card: GameCard)

const ACCENT_COLORS: Array[Color] = [
	Color("e05d5d"),
	Color("e0a15d"),
	Color("d8c95a"),
	Color("7fc96b"),
	Color("5dc9c0"),
	Color("5d8fe0"),
	Color("9b6be0"),
	Color("e06bb8"),
]
const FOCUS_SCALE: Vector2 = Vector2(1.07, 1.07)

var game_title: String = ""
var blurb: String = ""
var exec_path: String = ""
var accent: Color = Color.WHITE

var _entrance_tween: Tween = null
var _focus_tween: Tween = null


# Connect interaction signals when the card enters the tree
func _ready() -> void:
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	pressed.connect(_on_pressed)


# Fill the card with a single game entry loaded from games.json
func setup(data: Dictionary, index: int) -> void:
	game_title = data.get("title", "Unknown")
	blurb = data.get("blurb", "")
	exec_path = data.get("path", "")
	accent = ACCENT_COLORS[index % ACCENT_COLORS.size()]
	%TitleLabel.text = game_title
	%InitialLabel.text = game_title.substr(0, 1).to_upper()
	%ArtBlock.color = accent


# Pop the card in as part of the staggered grid entrance
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
