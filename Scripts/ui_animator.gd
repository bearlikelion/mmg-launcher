class_name UIAnimator
extends RefCounted

# Offset transforms are visual-only, so cards animate inside a container without it fighting back


static func prepare(target: Control) -> void:
	target.offset_transform_enabled = true
	target.offset_transform_pivot_ratio = Vector2(0.5, 0.5)


static func slide_in(target: Control, from_offset: Vector2, duration: float = 0.3, delay: float = 0.0) -> Tween:
	prepare(target)
	target.modulate.a = 0.0
	target.offset_transform_position = from_offset
	var tween: Tween = target.create_tween().set_parallel(true)
	tween.tween_property(target, "offset_transform_position", Vector2.ZERO, duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 1.0, duration * 0.8).set_delay(delay)
	return tween


static func pop_in(target: Control, duration: float = 0.4, delay: float = 0.0) -> Tween:
	prepare(target)
	target.modulate.a = 0.0
	target.offset_transform_scale = Vector2(0.6, 0.6)
	var tween: Tween = target.create_tween().set_parallel(true)
	tween.tween_property(target, "offset_transform_scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "modulate:a", 1.0, duration * 0.6).set_delay(delay)
	return tween


static func pop_out(target: Control, duration: float = 0.18, delay: float = 0.0) -> Tween:
	prepare(target)
	var tween: Tween = target.create_tween().set_parallel(true)
	tween.tween_property(target, "offset_transform_scale", Vector2(0.85, 0.85), duration).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(target, "modulate:a", 0.0, duration).set_delay(delay)
	return tween


static func scale_to(target: Control, target_scale: Vector2, duration: float = 0.15) -> Tween:
	prepare(target)
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "offset_transform_scale", target_scale, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


# Loops until the returned tween is killed
static func pulse(target: Control, amount: float = 1.04, period: float = 1.0) -> Tween:
	prepare(target)
	var tween: Tween = target.create_tween().set_loops()
	tween.tween_property(target, "offset_transform_scale", Vector2(amount, amount), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, "offset_transform_scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


static func shake(target: Control, strength: float = 14.0) -> Tween:
	prepare(target)
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "offset_transform_position:x", strength, 0.05).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "offset_transform_position:x", -strength * 0.6, 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "offset_transform_position:x", strength * 0.3, 0.08).set_trans(Tween.TRANS_SINE)
	tween.tween_property(target, "offset_transform_position:x", 0.0, 0.06).set_trans(Tween.TRANS_SINE)
	return tween
