## Shared motion: short, interruptible transitions; never animate container positions.
extends RefCounted

static func reveal(control: Control, duration := 0.22) -> void:
	if control.has_meta("reveal_tween"):
		var old: Tween = control.get_meta("reveal_tween")
		if old and old.is_valid(): old.kill()
	control.modulate.a = 0.0
	var tween := control.create_tween()
	control.set_meta("reveal_tween", tween)
	tween.tween_property(control, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

static func bind_button(button: BaseButton) -> void:
	if button.has_meta("motion_bound"): return
	button.set_meta("motion_bound", true)
	button.mouse_entered.connect(func(): _highlight(button, true))
	button.mouse_exited.connect(func(): _highlight(button, button.has_focus()))
	button.focus_entered.connect(func(): _highlight(button, true))
	button.focus_exited.connect(func(): _highlight(button, false))

static func _highlight(button: BaseButton, active: bool) -> void:
	if button.disabled: return
	if button.has_meta("hover_tween"):
		var old: Tween = button.get_meta("hover_tween")
		if old and old.is_valid(): old.kill()
	var tween := button.create_tween()
	button.set_meta("hover_tween", tween)
	tween.tween_property(button, "modulate", Color(1.12, 1.09, 1.02) if active else Color.WHITE, 0.14)
