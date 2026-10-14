## Persistent pause overlay, title screen actions and audio preferences.
extends CanvasLayer

const MOTION := preload("res://scripts/ui/ui_motion.gd")
const TITLE_SCENE := "res://scenes/title_screen.tscn"
const GOLD := Color("d6b879")
const INK := Color("101e25")
var root: Control
var panel: PanelContainer
var content: VBoxContainer
var heading: Label
var subtitle: Label
var _transition: Tween
var _open := false
var _closing := false
var _busy := false
var _was_paused := false
var _previous_focus: WeakRef
var _page := ""
var _settings := ConfigFile.new()
var _message: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_setup_audio()
	_build_shell()
	get_tree().node_added.connect(_style_node)
	get_tree().auto_accept_quit = false

func _style_node(node: Node) -> void:
	if node is BaseButton: MOTION.bind_button(node)

func _setup_audio() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
	_settings.load("user://settings.cfg")
	for bus_name in ["Master", "Music", "SFX"]:
		_set_volume(float(_settings.get_value("audio", bus_name, 0.8)), bus_name, false)

func _set_volume(value: float, bus_name: String, persist := true) -> void:
	value = clampf(value, 0.0, 1.0)
	var index := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, value <= 0.0)
	_settings.set_value("audio", bus_name, value)
	if persist and _settings.save("user://settings.cfg") != OK and is_instance_valid(_message):
		_message.text = "音量已生效，但偏好设置保存失败。"

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _build_shell() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var theme := Theme.new()
	theme.default_font = preload("res://assets/fonts/font.ttf")
	theme.default_font_size = 20
	theme.set_color("font_color", "Label", Color("eee6d5"))
	theme.set_color("font_color", "Button", Color("eee6d5"))
	theme.set_color("font_hover_color", "Button", Color("ffe1a0"))
	theme.set_color("font_disabled_color", "Button", Color("647274"))
	theme.set_stylebox("normal", "Button", _style(Color("192d34"), Color("53615b")))
	theme.set_stylebox("hover", "Button", _style(Color("29444a"), GOLD))
	theme.set_stylebox("pressed", "Button", _style(Color("354b48"), GOLD))
	theme.set_stylebox("disabled", "Button", _style(Color("17242a"), Color("334247")))
	var focus := _style(Color(0, 0, 0, 0), GOLD)
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", focus)
	root.theme = theme
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(580, 0)
	var frame := _style(INK, GOLD)
	frame.content_margin_left = 32
	frame.content_margin_right = 32
	frame.content_margin_top = 26
	frame.content_margin_bottom = 24
	frame.shadow_color = Color(0, 0, 0, 0.45)
	frame.shadow_size = 24
	panel.add_theme_stylebox_override("panel", frame)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	heading = Label.new()
	heading.add_theme_color_override("font_color", GOLD)
	heading.add_theme_font_size_override("font_size", 32)
	column.add_child(heading)
	subtitle = Label.new()
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color("9caaa6"))
	column.add_child(subtitle)
	column.add_child(HSeparator.new())
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	column.add_child(content)
	root.hide()

func is_title() -> bool:
	return get_tree().current_scene != null and get_tree().current_scene.scene_file_path == TITLE_SCENE

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("cancel") or event.is_echo(): return
	get_viewport().set_input_as_handled()
	if _busy or _closing: return
	if not _open:
		if not is_title(): open_menu()
	elif _page == "pause":
		close_menu()
	elif is_title():
		close_menu()
	else:
		_show_pause()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not _busy:
		open_menu()
		_confirm("退出游戏", "尚未保存的进度将丢失。确定退回桌面？", func(): get_tree().quit())

func open_menu() -> void:
	if _open or _busy: return
	_open = true
	_closing = false
	_was_paused = get_tree().paused
	var focused := get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused else null
	get_tree().paused = true
	root.show()
	root.modulate.a = 0.0
	panel.scale = Vector2(0.97, 0.97)
	panel.pivot_offset = panel.size * 0.5
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_transition.tween_property(root, "modulate:a", 1.0, 0.22)
	_transition.tween_property(panel, "scale", Vector2.ONE, 0.26)
	_show_pause()

func close_menu() -> void:
	if _closing or not _open or _busy: return
	_closing = true
	if _transition: _transition.kill()
	_transition = create_tween()
	_transition.tween_property(root, "modulate:a", 0.0, 0.14)
	_transition.tween_callback(func():
		root.hide()
		_open = false
		_closing = false
		get_tree().paused = _was_paused
		if _previous_focus and is_instance_valid(_previous_focus.get_ref()):
			_previous_focus.get_ref().grab_focus()
	)

func _clear(title: String, detail: String, page: String) -> void:
	_page = page
	heading.text = title
	subtitle.text = detail
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	MOTION.reveal(content, 0.16)

func _button(text: String, action: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.disabled = disabled
	content.add_child(button)
	button.pressed.connect(func():
		if not _closing and not _busy: action.call()
	)
	return button

func _focus_first() -> void:
	for child in content.get_children():
		if child is Button and not child.disabled:
			child.grab_focus.call_deferred()
			return

func _show_pause() -> void:
	_clear("暂 歇 江 湖", "游戏已暂停  ·  ESC 继续旅程", "pause")
	_button("继续游戏", close_menu)
	_button("保存进度", _show_slots.bind(true))
	_button("读取存档", _show_slots.bind(false))
	_button("声音设置", show_audio)
	_button("返回主界面", func(): _confirm("返回主界面", "尚未保存的进度将丢失。确定返回？", _change_scene.bind(TITLE_SCENE, {})))
	_button("退出游戏 · 退回桌面", func(): _confirm("退出游戏", "尚未保存的进度将丢失。确定退回桌面？", func(): get_tree().quit()))
	_focus_first()

func _back() -> void:
	if is_title(): close_menu()
	else: _show_pause()

func show_audio() -> void:
	if not _open: open_menu()
	_clear("声 音 设 置", "即时生效 · 自动保存音量偏好", "audio")
	for entry in [["Master", "总音量"], ["Music", "背景音乐"], ["SFX", "游戏音效"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 18)
		content.add_child(row)
		var label := Label.new()
		label.text = entry[1]
		label.custom_minimum_size.x = 100
		row.add_child(label)
		var slider := HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size = Vector2(240, 48)
		slider.max_value = 100
		slider.step = 1
		slider.value = float(_settings.get_value("audio", entry[0], 0.8)) * 100
		row.add_child(slider)
		var amount := Label.new()
		amount.custom_minimum_size.x = 62
		amount.text = "%d%%" % slider.value
		row.add_child(amount)
		slider.value_changed.connect(func(value: float):
			amount.text = "%d%%" % value
			_set_volume(value / 100.0, entry[0])
		)
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 16)
	content.add_child(_message)
	_button("返回", _back)
	_focus_first()

func show_load() -> void:
	if not _open: open_menu()
	_show_slots(false)

func _show_slots(saving: bool) -> void:
	var can_save := GameData.current_state == GameData.GameState.EXPLORE and not is_title()
	_clear("保 存 进 度" if saving else "读 取 存 档", "选择一个存档栏位" if not saving or can_save else "剧情、战斗或背包中无法存档，请先回到探索。", "save" if saving else "load")
	for slot in range(1, 4):
		var data := SaveManager.read_slot(slot)
		var valid := SaveManager.valid_save(data)
		var exists := FileAccess.file_exists(SaveManager.path_for(slot))
		var detail := "空白存档"
		if exists: detail = "存档损坏或版本不支持"
		if valid:
			var location: String = StoryManager.location_name(data.scene)
			detail = "%s · 等级 %d\n%s" % [location, data.party[0].stats.level, str(data.get("time", ""))]
		_button("存档 %02d   ·   %s" % [slot, detail], func():
			if saving:
				if exists: _confirm("覆盖存档", "确定覆盖存档 %02d？此操作无法撤销。" % slot, _save.bind(slot))
				else: _save(slot)
			else: _confirm("读取存档", "将回到存档中的进度，当前未保存的进度将丢失。", _load.bind(slot))
		, (saving and not can_save) or (not saving and not valid))
	_message = Label.new()
	_message.add_theme_font_size_override("font_size", 16)
	_message.add_theme_color_override("font_color", GOLD)
	content.add_child(_message)
	_button("返回", _back)
	_focus_first()

func _save(slot: int) -> void:
	var ok := SaveManager.save_slot(slot)
	_show_slots(true)
	_message.text = "存档 %02d 已保存。" % slot if ok else SaveManager.last_error

func _load(slot: int) -> void:
	var data := SaveManager.read_slot(slot)
	if not SaveManager.valid_save(data):
		_show_slots(false)
		_message.text = "存档无法读取，当前进度未改变。"
		return
	_change_scene(data.scene, data)

func _confirm(title: String, detail: String, action: Callable) -> void:
	var previous := _page
	_clear(title, detail, "confirm")
	_button("确定", action)
	var cancel := _button("取消", func():
		match previous:
			"save": _show_slots(true)
			"load": _show_slots(false)
			_: _back()
	)
	cancel.grab_focus.call_deferred()

func new_game() -> void:
	_change_scene(SaveManager.SCENES[0], {"new_game": true})

func quit_from_title() -> void:
	open_menu()
	_confirm("退出游戏", "确定退出游戏，退回桌面？", func(): get_tree().quit())

func _change_scene(path: String, data: Dictionary) -> void:
	if _busy: return
	var packed := load(path) as PackedScene
	if not packed:
		_confirm("切换失败", "场景暂时无法加载，请返回后重试。", _back)
		return
	_busy = true
	if _transition: _transition.kill()
	# Remove old scene before resetting autoload data, so old signals cannot act on it.
	get_tree().paused = true
	var old_scene := get_tree().current_scene
	get_tree().current_scene = null
	if old_scene:
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()
	BattleSystem.end_battle()
	DialogueSystem.reset_dialogue()
	StoryManager.cancel_pending()
	GameData.stop_persistent_music()
	if is_instance_valid(GameData._scene_title_layer):
		GameData._scene_title_layer.queue_free()
	if data.get("new_game", false): SaveManager.reset_game()
	elif not data.is_empty(): SaveManager.apply_save(data)
	GameData.current_state = GameData.GameState.EXPLORE
	var next := packed.instantiate()
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	if data.has("position"):
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player:
			player.global_position = Vector3(data.position[0], data.position[1], data.position[2])
			if player is CharacterBody3D: player.velocity = Vector3.ZERO
		if path != SaveManager.SCENES[2] and GameData.opening_intro_finished:
			GameData.play_persistent_music(GameData.OPENING_INN_MUSIC)
	root.hide()
	_open = false
	_closing = false
	_busy = false
	_previous_focus = null
	get_tree().paused = false
