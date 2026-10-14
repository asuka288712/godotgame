## Integrates real scenes, E interactions, dialogue, combat callbacks and save/load.
extends Node
var failures := 0
var scene_paths: Array = []
func check(ok: bool, description: String) -> void:
	if ok: print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()
func settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().create_timer(0.06).timeout
func finish_dialogue() -> void:
	for attempt in range(35):
		if not DialogueSystem.is_active(): break
		DialogueSystem.advance()
	check(not DialogueSystem.is_active(), "dialogue finishes")
	await settle()
func press_e() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_E
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_E
	Input.parse_input_event(event)
func go(location: String) -> void:
	StoryManager.travel(location)
	await settle()
	check(get_tree().current_scene.scene_file_path == StoryManager.LOCATIONS[location], "travel to " + location)
	check(get_tree().current_scene.has_node("UILayer/InventoryUI"), "inventory in " + location)
func use(id: String) -> void:
	var point = get_tree().current_scene.get_node("World/Interactions/" + id)
	var player = get_tree().get_first_node_in_group("player")
	player.global_position = point.global_position + Vector3(0, 0.1, 1.8)
	await settle()
	press_e()
	await settle()
func event(id: String, expected: int) -> void:
	await use(id)
	await finish_dialogue()
	check(StoryManager.stage == expected, id + " advances to %d" % expected)
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/chapter-" + name + ".png")
func roundtrip() -> void:
	var before := StoryManager.snapshot()
	check(SaveManager.save_slot(1), "save current chapter")
	var data := SaveManager.read_slot(1)
	check(SaveManager.valid_save(data), "v3 chapter save validates")
	GlobalMenu._load(1)
	await settle()
	check(StoryManager.snapshot() == before, "load restores exact chapter and items")
func run() -> void:
	get_tree().current_scene = null
	SaveManager.save_directory = "/tmp/xianjian-chapter-test"
	DirAccess.make_dir_recursive_absolute(SaveManager.save_directory)
	SaveManager.reset_game()
	GameData.opening_intro_finished = true
	check(not GameData.party[0].skills.any(func(skill): return skill.skill_name == "御剑术"), "sword lesson starts locked")
	# The reusable shell must load independently of its gameplay variant.
	var base = load("res://scenes/chapter/inn_room_base.tscn").instantiate()
	check(base.get_child_count() > 10, "reusable room contains editable geometry")
	base.free()
	for location in ["bedroom", "inn", "town"]:
		await go(location)
		var bridge = get_tree().current_scene.get_node("ChapterLinks")
		check(bridge.get_child_count() > 0, "legacy scene has new exits: " + location)
		var point = bridge.get_child(0)
		var destination: String = point.target_location
		var player = get_tree().get_first_node_in_group("player")
		player.global_position = point.global_position + Vector3(0, 0.1, 0.5)
		await settle()
		press_e()
		await settle()
		check(get_tree().current_scene.scene_file_path == StoryManager.LOCATIONS[destination], "E enters chapter from " + location)
	await go("kitchen")
	await capture("kitchen")
	await event("aunt", 1)
	await go("guestroom")
	await capture("guestroom")
	await event("miao", 2)
	await go("market")
	await capture("market")
	await event("beggar", 3)
	await go("kitchen")
	await event("aunt", 4)
	await go("guestroom")
	await event("miao", 5)
	await go("dock")
	await capture("dock")
	await use("sailor")
	check(get_tree().current_scene.scene_file_path == StoryManager.LOCATIONS.island, "boat reaches island")
	await capture("island")
	await use("palace_gate")
	await finish_dialogue()
	check(get_tree().current_scene.scene_file_path == StoryManager.LOCATIONS.island, "palace locked before meeting")
	for index in range(1, 7):
		await use("statue_%d" % index)
		await finish_dialogue()
		if index == 3: await roundtrip()
	check(StoryManager.stage == 6, "six unique statues unlock pond")
	await event("pond", 7)
	await use("palace_gate")
	await capture("palace")
	await event("elder", 8)
	await event("night", 9)
	await roundtrip()
	var player = get_tree().get_first_node_in_group("player")
	player.global_position.y = -8
	await settle()
	check(player.global_position.y > -1, "falling off shore returns to safe spawn")
	await finish_dialogue()
	check(StoryManager.key_items.has("紫金丹"), "elixir survives load")
	await go("kitchen")
	await event("aunt", 10)
	await go("temple")
	await capture("temple")
	await event("sword", 11)
	check(GameData.party[0].skills.any(func(skill): return skill.skill_name == "御剑术"), "lesson unlocks sword skill")
	await go("guestroom")
	await use("miao")
	await finish_dialogue()
	check(GameData.current_state == GameData.GameState.BATTLE, "rescue starts real battle")
	# Defeat first: the stage must not advance, and the event must remain retryable.
	for member in BattleSystem.combat_party: member.hp = 0
	BattleSystem._check_end()
	await get_tree().create_timer(0.9).timeout
	await finish_dialogue()
	check(StoryManager.stage == 11 and GameData.party[0].hp > 0, "defeat recovers and permits retry")
	await use("miao")
	await finish_dialogue()
	for enemy in BattleSystem.battle_enemies: enemy.hp = 0
	BattleSystem._check_end()
	await get_tree().create_timer(0.5).timeout
	get_tree().current_scene.get_node("UILayer/BattleUI").victory_continue_requested.emit()
	await finish_dialogue()
	check(StoryManager.stage == 12 and GameData.party.size() == 2, "rescue win recruits Linger once")
	await go("palace")
	await event("elder", 13)
	await event("burial", 14)
	await roundtrip()
	check(GameData.party[0].skills.any(func(skill): return skill.skill_name == "御剑术"), "learned skill survives load")
	await go("kitchen")
	await event("aunt", 15)
	await go("guestroom")
	await event("letter", 16)
	await go("dock")
	await event("sailor", 17)
	await roundtrip()
	await use("sailor")
	await finish_dialogue()
	check(StoryManager.stage == 17, "chapter ending is idempotent")
	var corrupted := StoryManager.snapshot()
	corrupted.stage = 1000
	check(not StoryManager.valid_snapshot(corrupted), "corrupt chapter is rejected")
	SaveManager.reset_game()
	check(StoryManager.stage == 0 and StoryManager.key_items.is_empty(), "new game resets chapter")
	print("CHAPTER_FAILURES=", failures)
	get_tree().quit(failures)
