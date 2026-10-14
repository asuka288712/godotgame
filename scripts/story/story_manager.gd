## Persistent chapter state. Stages advance only after dialogue/battle completes.
extends Node

const DATA_PATH := "res://resources/story/yuhang.json"
const LOCATIONS := {
	"bedroom": "res://scenes/xyr/lixiaoyao_room.tscn",
	"inn": "res://scenes/lijiakezhan.tscn",
	"town": "res://scenes/main.tscn",
	"guestroom": "res://scenes/chapter/inn_guestroom.tscn",
	"kitchen": "res://scenes/chapter/inn_kitchen.tscn",
	"market": "res://scenes/chapter/yuhang_market.tscn",
	"dock": "res://scenes/chapter/yuhang_dock.tscn",
	"island": "res://scenes/chapter/xianling_island.tscn",
	"palace": "res://scenes/chapter/shuiyue_palace.tscn",
	"temple": "res://scenes/chapter/mountain_temple.tscn",
}
const NAMES := {"bedroom": "逍遥房间", "inn": "李家客栈", "town": "余杭镇", "guestroom": "客栈客房", "kitchen": "客栈厨房", "market": "余杭集市", "dock": "余杭码头", "island": "仙灵岛", "palace": "水月宫", "temple": "十里坡 · 山神庙"}
var stage := 0
var flags: Dictionary = {}
var key_items: Dictionary = {}
var gold := 100
var pending_spawn := ""
var _seen_scene: Node
var _data: Dictionary = {}
var _pending_event := ""
var _battle_event := ""
var _hint: Label
var _quest: Label
var _journal: PanelContainer
var _journal_label: Label
var _journal_previous_state: int
var _nearest: Node3D
var _changing := false
var _transition_layer: CanvasLayer
var _transition_fade: ColorRect

func _ready() -> void:
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	DialogueSystem.dialogue_finished.connect(_finish_dialogue)
	GameData._bind("quest_journal", KEY_Q)
	_build_hud()
	_build_scene_transition()

func reset_story() -> void:
	stage = 0
	flags.clear()
	key_items.clear()
	gold = 100
	cancel_pending()
	pending_spawn = ""

func cancel_pending() -> void:
	_pending_event = ""
	_battle_event = ""
	_journal.hide()
	_nearest = null

func snapshot() -> Dictionary:
	return {"stage": stage, "flags": flags.duplicate(), "key_items": key_items.duplicate(), "gold": gold}

func valid_snapshot(data) -> bool:
	if not data is Dictionary: return false
	var saved_stage = data.get("stage")
	if not (saved_stage is float or saved_stage is int): return false
	if saved_stage < 0 or saved_stage > 17 or saved_stage != int(saved_stage): return false
	if not data.get("flags") is Dictionary or not data.get("key_items") is Dictionary: return false
	for value in data.flags.values():
		if not value is bool: return false
	for value in data.key_items.values():
		if not (value is int or value is float) or value != 1: return false
	var money = data.get("gold", 100)
	return (money is int or money is float) and money >= 0 and money <= 1000000 and money == int(money)

func restore(data: Dictionary) -> void:
	cancel_pending()
	stage = int(data.get("stage", 0))
	flags = data.get("flags", {}).duplicate()
	key_items.clear()
	for item in data.get("key_items", {}): key_items[str(item)] = 1
	gold = int(data.get("gold", 100))
	pending_spawn = ""
	sync_skills()

func objective() -> String:
	if not GameData.opening_intro_finished: return "清晨 · 回应婶婶，完成起床对话。"
	return str(_data.objectives[stage])

func location_name(path: String) -> String:
	for id in LOCATIONS:
		if LOCATIONS[id] == path: return NAMES[id]
	return "江湖"

func say(speaker: String, text: String) -> void:
	DialogueSystem.start_dialogue([{"speaker": speaker, "text": text}])

func activate(id: String, speaker := "旁白", fallback := "") -> void:
	if GameData.current_state != GameData.GameState.EXPLORE or not _pending_event.is_empty(): return
	if id.begins_with("statue_"):
		if stage != 5 or not key_items.has("破天锤"):
			say("石像", "石阵封住了通往荷池的路，需要破阵之物。" if stage < 6 else "石阵已破。")
			return
		if flags.has(id):
			say("石像", "这尊石像已被击碎。")
			return
		flags[id] = true
		var count := 0
		for index in range(1, 7):
			if flags.has("statue_%d" % index): count += 1
		if count == 6:
			stage = 6
			key_items.erase("破天锤")
		say("旁白", "石像应声碎裂。已破除 %d / 6 尊石像。%s" % [count, "通往荷池的道路显现了。" if count == 6 else ""])
		return
	if id == "sailor":
		if stage < 5: say("张四", "今天风浪不小。要出海寻药，先把事情准备妥当。")
		elif stage == 16: activate("depart")
		elif stage == 17: say("张四", "余杭篇已经完成。苏州之行将在下一章节继续。")
		else: travel("island", "shore")
		return
	if id == "return_boat":
		travel("dock", "boat")
		return
	if id == "palace_gate" and stage < 7:
		say("旁白", "荷池后有一条通往宫门的小路，先去池边看看。")
		return
	if id == "palace_gate":
		travel("palace")
		return
	if id == "herbs":
		if flags.has("herbs"): say("药篓", "这里的药草已经采过了。")
		else:
			flags["herbs"] = true
			add_item("金创药", "heal_hp", 100, 2)
			say("旁白", "获得金创药 ×2。")
		return
	if id == "vendor":
		if gold < 20: say("药贩", "一份金创药二十文，你的盘缠还不够。")
		else:
			gold -= 20
			add_item("金创药", "heal_hp", 100, 1)
			say("药贩", "收你二十文。金创药已放入背包，剩余 %d 文。" % gold)
		return
	if id == "rest":
		for member in GameData.party:
			member.hp = member.max_hp
			member.mp = member.max_mp
		say("旁白", "稍作歇息，队伍体力与真气已恢复。")
		return
	if id == "aunt":
		var next_event: String = {0: "wine", 3: "illness", 9: "medicine", 14: "farewell"}.get(stage, "")
		if not next_event.is_empty(): activate(next_event)
		else: say("李大娘", "路上留心，先把眼前的事办好。\n" + objective())
		return
	if id == "miao":
		var next_event: String = {1: "guests", 4: "aid", 11: "rescue"}.get(stage, "")
		if not next_event.is_empty(): activate(next_event)
		else: say("苗人头领", "我们还有事商量，你先去忙吧。")
		return
	if id == "elder":
		activate("last_words" if stage >= 12 else "granny", "姥姥", "宫内一片寂静。")
		return
	if not _data.events.has(id):
		say(speaker, fallback if not fallback.is_empty() else objective())
		return
	var event: Dictionary = _data.events[id]
	if stage != int(event.stage):
		say(speaker, fallback if not fallback.is_empty() else objective())
		return
	for item in event.get("take", []):
		if not key_items.has(item):
			say("旁白", "还缺少「%s」。%s" % [item, objective()])
			return
	_pending_event = id
	play_lines(event.lines)

func play_lines(lines: Array) -> void:
	var parsed: Array = []
	for line in lines: parsed.append({"speaker": str(line[0]), "text": str(line[1])})
	DialogueSystem.start_dialogue(parsed)

func _finish_dialogue() -> void:
	if _pending_event.is_empty(): return
	var id := _pending_event
	_pending_event = ""
	var event: Dictionary = _data.events[id]
	if stage != int(event.stage): return
	if event.has("battle"):
		_battle_event = id
		var host := get_tree().current_scene.get_node_or_null("ChapterBattle")
		if host: host.start(event.battle)
		else:
			_battle_event = ""
			say("旁白", "战斗场景未就绪，请重新与苗人交互。")
		return
	_commit(id)

func _commit(id: String) -> void:
	var event: Dictionary = _data.events[id]
	if stage != int(event.stage): return
	for item in event.get("take", []): key_items.erase(item)
	for item in event.get("give", []): key_items[item] = 1
	flags[id] = true
	stage = int(event.next)
	if id == "rescue":
		GameData.recruit_zhao_linger()
		gold += 60
	if id == "sword": sync_skills()
	if id == "letter": add_item("金创药", "heal_hp", 100, 3)

func finish_battle(victory: bool) -> void:
	var id := _battle_event
	_battle_event = ""
	if id.is_empty(): return
	if victory:
		_commit(id)
		play_lines(_data.events[id].get("after", [["旁白", "战斗结束。"]]))
	else:
		# A story loss has an explicit retry path and cannot lock the chapter.
		for member in GameData.party:
			member.hp = member.max_hp
			member.mp = member.max_mp
		say("旁白", "暂退到门边整顿。恢复体力后，可以再次与苗人交战。")

func add_item(item_name: String, effect: String, value: int, count: int) -> void:
	for item in GameData.inventory:
		if item.item_name == item_name:
			item.count += count
			return
	GameData.inventory.append(GameData.Item.new(item_name, effect, value, count))

func sync_skills() -> void:
	if not flags.get("sword", false) or GameData.party.is_empty(): return
	var hero = GameData.party[0]
	if not hero.skills.any(func(skill): return skill.skill_name == "御剑术"):
		hero.skills.append(GameData.Skill.new("御剑术", 8, 1.5, "attack", "single_enemy", "酒剑仙传授的御剑之术", 0.8))

func travel(location: String, spawn := "entry") -> void:
	if _changing or not LOCATIONS.has(location): return
	_changing = true
	pending_spawn = spawn
	GameData.current_state = GameData.GameState.PAUSED
	if location == "island":
		await _play_boat_transition()
	var error := get_tree().change_scene_to_file(LOCATIONS[location])
	if error != OK:
		pending_spawn = ""
		GameData.current_state = GameData.GameState.EXPLORE
		push_error("无法进入场景: " + location)
	_changing = false

func travel_path(scene_path: String, spawn := "entry") -> void:
	for location in LOCATIONS:
		if LOCATIONS[location] == scene_path:
			travel(location, spawn)
			return
	push_warning("未注册的场景路径，拒绝跨图切换: " + scene_path)

func _build_scene_transition() -> void:
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "SceneTransition"
	_transition_layer.layer = 120
	_transition_fade = ColorRect.new()
	_transition_fade.color = Color(0.015, 0.035, 0.055, 0.0)
	_transition_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_layer.add_child(_transition_fade)
	get_tree().root.call_deferred("add_child", _transition_layer)

func _play_boat_transition() -> void:
	if not is_instance_valid(_transition_fade): return
	_transition_fade.color = Color(0.015, 0.035, 0.055, 0.0)
	_transition_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var title := Label.new()
	title.text = "出 海"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_fade.add_child(title)
	var tween := create_tween()
	tween.tween_property(_transition_fade, "color:a", 1.0, 0.55)
	tween.tween_interval(1.4)
	tween.tween_property(_transition_fade, "color:a", 0.0, 0.65)
	await tween.finished
	title.queue_free()
	_transition_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if not scene: return
	if scene != _seen_scene:
		_seen_scene = scene
		_nearest = null
		if LOCATIONS.values().has(scene.scene_file_path):
			_install_bridge(scene)
			var marker := scene.get_node_or_null("Spawns/" + pending_spawn) as Node3D if not pending_spawn.is_empty() else null
			var player := get_tree().get_first_node_in_group("player") as Node3D
			if marker and player: player.global_position = marker.global_position
		pending_spawn = ""
	var playable := LOCATIONS.values().has(scene.scene_file_path)
	_quest.visible = playable and GameData.current_state == GameData.GameState.EXPLORE
	_quest.text = "余杭旧梦  ·  " + objective() + "\nB 背包  ·  Q 行囊与见闻  ·  Esc 设置"
	_hint.visible = false
	_nearest = null
	if not playable or GameData.current_state != GameData.GameState.EXPLORE: return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player: return
	var best := INF
	for point in get_tree().get_nodes_in_group("story_interactions"):
		if not point.available(): continue
		var distance: float = point.distance_to(player)
		if distance <= point.radius and distance < best:
			best = distance
			_nearest = point
	if _nearest:
		_hint.text = "[ E ]  " + _nearest.display_name
		_hint.visible = true

func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed("quest_journal") and not get_tree().paused:
		if _journal.visible:
			_journal.hide()
			GameData.current_state = _journal_previous_state
		elif GameData.current_state == GameData.GameState.EXPLORE and get_tree().get_first_node_in_group("player"):
			_journal_previous_state = GameData.current_state
			GameData.current_state = GameData.GameState.PAUSED
			_journal_label.text = "余杭旧梦\n\n" + objective() + "\n\n关键物品：" + ("、".join(key_items.keys()) if not key_items.is_empty() else "无") + "\n盘缠：%d 文\n\n见闻：\n" % gold
			for id in _data.events:
				if flags.get(id, false): _journal_label.text += "· " + str(_data.objectives[int(_data.events[id].stage)]) + "\n"
			_journal_label.text += "\nQ 收起"
			_journal.show()
		get_viewport().set_input_as_handled()
	if GameData.current_state == GameData.GameState.EXPLORE and event.is_action_pressed("interact") and is_instance_valid(_nearest):
		get_viewport().set_input_as_handled()
		_nearest.interact()

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 15
	add_child(layer)
	_quest = Label.new()
	_quest.position = Vector2(24, 18)
	_quest.add_theme_font_size_override("font_size", 17)
	_quest.add_theme_constant_override("outline_size", 5)
	layer.add_child(_quest)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-250, -70)
	_hint.size = Vector2(500, 36)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 24)
	_hint.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hint)
	_journal = PanelContainer.new()
	_journal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_journal.position = Vector2(-380, -270)
	_journal.size = Vector2(760, 540)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15262bed")
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_journal.add_theme_stylebox_override("panel", style)
	layer.add_child(_journal)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 480)
	_journal.add_child(scroll)
	_journal_label = Label.new()
	_journal_label.add_theme_font_size_override("font_size", 19)
	_journal_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_journal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scroll.add_child(_journal_label)
	for label in [_quest, _hint, _journal_label]:
		label.add_theme_font_override("font", preload("res://assets/fonts/font.ttf"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_journal.hide()

func _install_bridge(scene: Node) -> void:
	if scene.has_node("ChapterLinks"): return
	var path: String = scene.scene_file_path
	var links := Node3D.new()
	links.name = "ChapterLinks"
	scene.add_child(links)
	if path == LOCATIONS.inn:
		_bridge_point(links, "厨房", Vector3(2, 5, -8), "kitchen")
		_bridge_point(links, "客房", Vector3(-3, 5, -8), "guestroom")
		_bridge_point(links, "下楼 · 渔村", Vector3(0, 5, 28), "town", "inn_return")
	elif path == LOCATIONS.town:
		_bridge_point(links, "余杭集市", Vector3(4, 0, 2), "market")
		_bridge_point(links, "余杭集市", Vector3(4, 0, 2), "market")
		_bridge_point(links, "林道尽头 · 十里坡", Vector3(25, 0, 27), "temple")
	elif path == LOCATIONS.bedroom:
		_bridge_point(links, "客栈厨房", Vector3(-4, 1, 3), "kitchen")

func _bridge_point(parent: Node3D, title: String, position: Vector3, location: String, spawn := "entry") -> void:
	var point := Node3D.new()
	point.set_script(preload("res://scripts/story/story_interaction.gd"))
	point.name = location
	point.position = position
	point.set("display_name", title)
	point.set("target_location", location)
	point.set("target_spawn", spawn)
	parent.add_child(point)
	var sign := Label3D.new()
	sign.text = title + "  [E]"
	sign.position.y = 2.5
	sign.font = preload("res://assets/fonts/font.ttf")
	sign.font_size = 36
	sign.pixel_size = 0.012
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	point.add_child(sign)
