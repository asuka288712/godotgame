extends Control

const TITLE_BGM := preload("res://assets/music/bgm1.mp3")

var _title_bgm: AudioStreamPlayer

func _ready() -> void:
	_play_title_bgm()
	var backdrop := TextureRect.new()
	backdrop.texture = preload("res://assets/uis/background/title_art.png")
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# Keep the original illustration bright; only soften the menu's left edge.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.98, 0.96, 0.92, 0.72))
	gradient.set_color(1, Color(0.98, 0.96, 0.92, 0.0))
	var wash := GradientTexture2D.new()
	wash.gradient = gradient
	wash.fill_from = Vector2.ZERO
	wash.fill_to = Vector2(0.45, 0)
	var shade := TextureRect.new()
	shade.texture = wash
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	theme = GlobalMenu.root.theme
	var placement := MarginContainer.new()
	placement.anchor_top = 0.42
	placement.anchor_bottom = 1.0
	placement.anchor_right = 0.34
	placement.offset_left = 96
	placement.offset_right = -20
	placement.offset_bottom = -28
	add_child(placement)
	var column := VBoxContainer.new()
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 12)
	placement.add_child(column)
	var title := TextureRect.new()
	title.texture = preload("res://assets/uis/background/title_logo.png")
	title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.custom_minimum_size.y = 56
	title.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "一剑入江湖 · HD–2D 重制版"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("667582"))
	column.add_child(subtitle)
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 8
	column.add_child(spacer)
	var has_save := false
	for slot in range(1, 4): has_save = has_save or SaveManager.valid_save(SaveManager.read_slot(slot))
	var button_index := 0
	for entry in [["新的旅程", GlobalMenu.new_game], ["继续游戏 · 读取存档", GlobalMenu.show_load], ["声音设置", GlobalMenu.show_audio], ["退出游戏", GlobalMenu.quit_from_title]]:
		var button := Button.new()
		button.text = entry[0]
		button.custom_minimum_size.y = 44
		_style_button(button)
		button.disabled = entry[0].begins_with("继续") and not has_save
		button.pressed.connect(entry[1])
		column.add_child(button)
		_prepare_button_motion(button, button_index)
		button_index += 1
	column.get_child(3).grab_focus.call_deferred()
	GlobalMenu.MOTION.reveal(column, 0.65)

func _play_title_bgm() -> void:
	# 标题页只保留自己的 BGM；切入游戏时 GlobalMenu 会停止全局音乐。
	GameData.stop_persistent_music()
	_title_bgm = AudioStreamPlayer.new()
	_title_bgm.stream = TITLE_BGM
	_title_bgm.bus = &"Music"
	_title_bgm.volume_db = -10.0
	_title_bgm.finished.connect(func():
		if is_instance_valid(_title_bgm):
			_title_bgm.play()
	)
	add_child(_title_bgm)
	_title_bgm.play()

func _prepare_button_motion(button: Button, index: int) -> void:
	button.modulate.a = 0.0
	button.scale = Vector2(0.94, 0.94)
	button.mouse_entered.connect(_set_button_emphasis.bind(button, true))
	button.mouse_exited.connect(_set_button_emphasis.bind(button, button.has_focus()))
	button.focus_entered.connect(_set_button_emphasis.bind(button, true))
	button.focus_exited.connect(_set_button_emphasis.bind(button, false))
	button.pressed.connect(_pulse_button.bind(button))
	_animate_button_entrance.call_deferred(button, index)

func _animate_button_entrance(button: Button, index: int) -> void:
	if not is_instance_valid(button):
		return
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "modulate:a", 1.0, 0.24).set_delay(0.12 + index * 0.07)
	tween.tween_property(button, "scale", Vector2.ONE, 0.30).set_delay(0.12 + index * 0.07)

func _set_button_emphasis(button: Button, active: bool) -> void:
	if button.disabled:
		return
	var previous: Tween = button.get_meta("title_button_tween") as Tween if button.has_meta("title_button_tween") else null
	if previous and previous.is_valid():
		previous.kill()
	var tween := button.create_tween()
	button.set_meta("title_button_tween", tween)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.045, 1.045) if active else Vector2.ONE, 0.12)

func _pulse_button(button: Button) -> void:
	if button.disabled:
		return
	var tween := button.create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.97, 0.97), 0.06)
	tween.tween_property(button, "scale", Vector2.ONE, 0.11)

func _style_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color("344e61"))
	button.add_theme_color_override("font_hover_color", Color("223c54"))
	button.add_theme_color_override("font_pressed_color", Color("223c54"))
	button.add_theme_color_override("font_focus_color", Color("223c54"))
	button.add_theme_color_override("font_disabled_color", Color("8b9299"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.98, 0.97, 0.94, 0.68)
		style.border_color = Color(0.38, 0.46, 0.55, 0.3)
		style.set_border_width_all(1)
		style.set_corner_radius_all(3)
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		if state in ["hover", "pressed"]:
			style.bg_color = Color(0.85, 0.9, 0.94, 0.9)
			style.border_color = Color("72869a")
		elif state == "disabled":
			style.bg_color = Color(0.94, 0.94, 0.94, 0.4)
		elif state == "focus":
			style.bg_color = Color.TRANSPARENT
			style.border_color = Color("72869a")
			style.set_border_width_all(2)
		button.add_theme_stylebox_override(state, style)
