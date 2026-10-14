## Run: Godot --path . res://tests/global_menu_smoke.tscn
extends Node

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else: print("PASS: " + message)

func _ready() -> void:
	# This node survives scene changes while exercising real scene integration.
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("run_checks")

func press_escape() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = false
	Input.parse_input_event(event)

func screenshot(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/" + file + ".png")

func run_checks() -> void:
	get_tree().current_scene = null
	SaveManager.save_directory = "/tmp/xianjian-ui-smoke"
	DirAccess.make_dir_recursive_absolute(SaveManager.save_directory)
	GlobalMenu._change_scene(GlobalMenu.TITLE_SCENE, {})
	await get_tree().create_timer(0.7).timeout
	check(GlobalMenu.is_title(), "title screen opens")
	await screenshot("xianjian-title")
	GlobalMenu.new_game()
	await get_tree().create_timer(0.3).timeout
	check(DialogueSystem.is_active(), "new game starts opening dialogue")
	press_escape()
	await get_tree().process_frame
	check(get_tree().paused, "global menu pauses cutscene")
	GlobalMenu._show_slots(true)
	check(not SaveManager.save_slot(1), "saving is blocked during dialogue")
	GlobalMenu.close_menu()
	await get_tree().create_timer(0.3).timeout
	check(not get_tree().paused and DialogueSystem.is_active(), "closing menu restores dialogue")
	GameData.opening_intro_finished = true
	GlobalMenu._change_scene(SaveManager.SCENES[0], {})
	await get_tree().process_frame
	var player := get_tree().get_first_node_in_group("player") as Node3D
	check(player != null, "loaded room has player")
	player.global_position = Vector3(1, 0.2, 2)
	GameData.recruit_zhao_linger()
	GameData.party[0].hp = 123
	GameData.equip_item(GameData.party[0], GameData.inventory[3])
	GameData.equip_item(GameData.party[0], GameData.inventory[3])
	SaveManager.collected_items["example:Fruit"] = true
	GlobalMenu.open_menu()
	await get_tree().create_timer(0.4).timeout
	await screenshot("xianjian-pause")
	check(SaveManager.save_slot(1), "exploration save succeeds while menu pauses tree")
	var saved := SaveManager.read_slot(1)
	check(SaveManager.valid_save(saved), "serialized save validates")
	GlobalMenu._show_slots(false)
	await get_tree().create_timer(0.3).timeout
	await screenshot("xianjian-saves")
	GlobalMenu.show_audio()
	await get_tree().create_timer(0.3).timeout
	await screenshot("xianjian-audio")
	GlobalMenu._set_volume(0, "Music", false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "zero volume mutes music")
	GlobalMenu._set_volume(0.5, "Music", false)
	check(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "raising volume unmutes music")
	GameData.party[0].hp = 1
	GlobalMenu._load(1)
	await get_tree().process_frame
	check(GameData.party.size() == 2 and GameData.party[0].hp == 123, "load restores party and health")
	check(GameData.party[0].equipment.weapon.item_name == "木剑", "load restores equipment")
	GameData.unequip_item(GameData.party[0], "armor")
	var armor = GameData.inventory.filter(func(item): return item.item_name == "布衣")
	check(armor.size() == 1 and armor[0].count == 2, "stacked equipment count survives save/load/unequip")
	check(SaveManager.collected_items.has("example:Fruit"), "load restores pickups")
	player = get_tree().get_first_node_in_group("player") as Node3D
	check(player.global_position.distance_to(Vector3(1, 0.2, 2)) < 0.1, "load restores position")
	var broken := saved.duplicate(true)
	broken.party[0].stats.hp = "invalid"
	check(not SaveManager.valid_save(broken), "malformed save is rejected")
	GlobalMenu._change_scene(SaveManager.SCENES[2], {})
	await get_tree().create_timer(0.3).timeout
	var inventory = get_tree().current_scene.get_node("UILayer/InventoryUI")
	inventory.open()
	await get_tree().create_timer(0.5).timeout
	press_escape()
	await get_tree().process_frame
	check(get_tree().paused and inventory.visible, "Escape opens global menu over inventory")
	press_escape()
	await get_tree().create_timer(0.3).timeout
	check(not get_tree().paused and GameData.current_state == GameData.GameState.PAUSED, "closing settings preserves inventory state")
	inventory.close()
	await get_tree().create_timer(0.4).timeout
	check(GameData.current_state == GameData.GameState.EXPLORE, "inventory close restores exploration")
	BattleSystem.start_battle(["蘑菇怪"])
	GlobalMenu.open_menu()
	await get_tree().create_timer(0.8).timeout
	check(BattleSystem.state == BattleSystem.BState.STARTING, "battle startup timer remains paused")
	GlobalMenu._change_scene(GlobalMenu.TITLE_SCENE, {})
	await get_tree().create_timer(0.8).timeout
	check(GlobalMenu.is_title() and BattleSystem.turn_order.is_empty(), "returning to title cancels pending battle action")
	GlobalMenu.new_game()
	await get_tree().create_timer(0.2).timeout
	check(GameData.party.size() == 1 and GameData.inventory.size() == 6 and SaveManager.collected_items.is_empty(), "new game resets session")
	print("UI_SMOKE_FAILURES=", failures)
	get_tree().quit(failures)
