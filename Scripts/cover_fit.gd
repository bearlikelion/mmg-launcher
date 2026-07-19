class_name CoverFit
extends RefCounted

const FRAME_ASPECT: float = 16.0 / 9.0
const TOLERANCE: float = 1.08


# Crop covers that are close to the 16:9 frame, letterbox anything wider or taller
static func apply(rect: TextureRect) -> void:
	if rect.texture == null:
		return
	var texture_size: Vector2 = rect.texture.get_size()
	if texture_size.y <= 0.0:
		return
	var aspect: float = texture_size.x / texture_size.y
	if aspect > FRAME_ASPECT * TOLERANCE or aspect < FRAME_ASPECT / TOLERANCE:
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else:
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
