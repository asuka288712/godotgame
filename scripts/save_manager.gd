## Versioned local saves. Decode all data before touching the live session.
extends Node

const SCENES := ["res://scenes/xyr/lixiaoyao_room.tscn", "res://scenes/lijiakezhan.tscn", "res://scenes/main.tscn", "res://scenes/chapter/inn_guestroom.tscn", "res://scenes/chapter/inn_kitchen.tscn", "res://scenes/chapter/yuhang_market.tscn", "res://scenes/chapter/yuhang_dock.tscn", "res://scenes/chapter/xianling_island.tscn", "res://scenes/chapter/shuiyue_palace.tscn", "res://scenes/chapter/mountain_temple.tscn"]
const STATS := ["level", "hp", "max_hp", "mp", "max_mp", "attack", "defense", "speed"]
var collected_items: Dictionary = {}
var last_error := ""
var save_directory := "user://"

func path_for(slot: int) -> String:
	return save_directory.path_join("save_%d.json" % clampi(slot, 1, 3))

func read_slot(slot: int) -> Dictionary:
	if not FileAccess.file_exists(path_for(slot)): return {}
	var value = JSON.parse_string(FileAccess.get_file_as_string(path_for(slot)))
	return value if value is Dictionary else {}

func _item_data(item) -> Dictionary:
	return {"name": item.item_name, "effect": item.effect_type, "value": item.value, "count": item.count, "slot": item.equipment_slot, "bonus": item.stat_bonus}

func save_slot(slot: int) -> bool:
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not scene or not player or scene.scene_file_path not in SCENES or GameData.current_state != GameData.GameState.EXPLORE:
		last_error = "请在探索状态下存档。"
		return false
	var members: Array = []
	for member in GameData.party:
		var data := {"name": member.char_name, "stats": {}, "equipment": {}}
		for stat in STATS: data.stats[stat] = member.get(stat)
		data.stats["experience"] = member.experience
		for key in member.equipment:
			data.equipment[key] = _item_data(member.equipment[key]) if member.equipment[key] else null
		members.append(data)
	var items: Array = []
	for item in GameData.inventory: items.append(_item_data(item))
	var pos := player.global_position
	var data := {"version": 3, "story": StoryManager.snapshot(), "time": Time.get_datetime_string_from_system().replace("T", " "), "scene": scene.scene_file_path, "position": [pos.x, pos.y, pos.z], "party": members, "inventory": items, "opening_finished": GameData.opening_intro_finished, "collected": collected_items}
	var temp := path_for(slot) + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if not file:
		last_error = "无法写入存档，请检查磁盘空间。"
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(temp, path_for(slot)) != OK:
		last_error = "存档写入失败，原存档已保留。"
		return false
	return true

func _valid_item(data) -> bool:
	if not data is Dictionary: return false
	if not data.get("name") is String or not data.get("effect") is String: return false
	if not data.get("bonus") is Dictionary or data.get("slot") not in ["", "weapon", "armor", "accessory"]: return false
	for stat in data.bonus:
		if stat not in ["attack", "defense", "speed"] or not _number(data.bonus[stat]): return false
	return _number(data.get("value")) and _number(data.get("count")) and data.count >= 0

func _number(value) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and absf(float(value)) < 10000000

func valid_save(data: Dictionary) -> bool:
	if (data.get("version") != 1 and data.get("version") != 2 and data.get("version") != 3) or data.get("scene") not in SCENES: return false
	if data.get("version") == 3 and not StoryManager.valid_snapshot(data.get("story")): return false
	if not data.get("opening_finished") is bool or not data.get("collected") is Dictionary: return false
	if not data.get("position") is Array or data.position.size() != 3: return false
	for axis in data.position:
		if not _number(axis): return false
	if not data.get("inventory") is Array or not data.get("party") is Array or data.party.is_empty() or data.party.size() > 2: return false
	for item in data.inventory:
		if not _valid_item(item): return false
	var names: Array = []
	for member in data.party:
		if not member is Dictionary or member.get("name") not in ["李逍遥", "赵灵儿"] or member.name in names: return false
		names.append(member.name)
		if not member.get("stats") is Dictionary or not member.get("equipment") is Dictionary: return false
		for stat in STATS:
			if not _number(member.stats.get(stat)) or member.stats[stat] < 0: return false
		var xp = member.stats.get("experience", 0)
		if not _number(xp) or xp < 0 or xp != int(xp): return false
		if member.stats.level < 1 or member.stats.level > GameData.MAX_LEVEL or member.stats.level != int(member.stats.level): return false
		if member.stats.level == GameData.MAX_LEVEL and xp != 0: return false
		if member.stats.level < GameData.MAX_LEVEL and xp >= GameData.experience_required(int(member.stats.level)): return false
		if data.version >= 2 and not member.stats.has("experience"): return false
		if member.stats.max_hp < 1 or member.stats.hp > member.stats.max_hp or member.stats.mp > member.stats.max_mp: return false
		for key in ["weapon", "armor", "accessory"]:
			if not member.equipment.has(key): return false
			if member.equipment[key] != null and (not _valid_item(member.equipment[key]) or member.equipment[key].slot != key): return false
	return names[0] == "李逍遥"

func _decode_item(data: Dictionary):
	return GameData.Item.new(data.name, data.effect, int(data.value), int(data.count), data.slot, data.bonus)

func apply_save(data: Dictionary) -> void:
	GameData.party.clear()
	GameData.inventory.clear()
	GameData._init_party()
	if data.party.size() == 2: GameData.recruit_zhao_linger()
	for index in data.party.size():
		var member = GameData.party[index]
		var saved: Dictionary = data.party[index]
		for stat in STATS: member.set(stat, int(saved.stats[stat]))
		member.experience = int(saved.stats.get("experience", 0))
		for key in member.equipment:
			member.equipment[key] = _decode_item(saved.equipment[key]) if saved.equipment[key] != null else null
	for item in data.inventory: GameData.inventory.append(_decode_item(item))
	GameData.opening_intro_finished = data.opening_finished
	collected_items = data.collected.duplicate()
	StoryManager.restore(data.get("story", {}))

func reset_game() -> void:
	GameData.party.clear()
	GameData.inventory.clear()
	GameData._init_party()
	GameData._init_inventory()
	GameData.opening_intro_finished = false
	collected_items.clear()
	StoryManager.reset_story()
