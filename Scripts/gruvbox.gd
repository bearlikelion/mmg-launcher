class_name Gruvbox
extends RefCounted

# Gruvbox palette shared with the GodotCon deck and markmakes.games

const BG0H: Color = Color("1d2021")
const BG0: Color = Color("282828")
const BG1: Color = Color("3c3836")
const BG2: Color = Color("504945")
const BG3: Color = Color("665c54")
const FG: Color = Color("ebdbb2")
const FG2: Color = Color("d5c4a1")
const GRAY: Color = Color("928374")
const RED: Color = Color("fb4934")
const GREEN: Color = Color("b8bb26")
const YELLOW: Color = Color("fabd2f")
const BLUE: Color = Color("83a598")
const PURPLE: Color = Color("d3869b")
const AQUA: Color = Color("8ec07c")
const ORANGE: Color = Color("fe8019")

const ACCENTS: Array[Color] = [AQUA, ORANGE, RED, GREEN, PURPLE, BLUE, YELLOW]


# Pick a stable accent color for a card by its position in the row
static func accent_for_index(index: int) -> Color:
	return ACCENTS[index % ACCENTS.size()]
