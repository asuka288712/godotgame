extends Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	else: print("PASS: ", message)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	run.call_deferred()
func press_b() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	event.pressed = true
	Input.parse_input_event(event)
	event = InputEventKey.new()
	event.physical_keycode = KEY_B
	Input.parse_input_event(event)
func run() -> void:
	get_tree().current_scene = null
	SaveManager.save_directory = "/tmp/xianjian-progression-test"
	DirAccess.make_dir_recursive_absolute(SaveManager.save_directory)
	SaveManager.reset_game()
	GameData.opening_intro_finished = true
	for path in SaveManager.SCENES:
		GlobalMenu._change_scene(path, {})
		await get_tree().process_frame
		await get_tree().process_frame
		var inventory = get_tree().current_scene.get_node_or_null("UILayer/InventoryUI")
		check(inventory != null, "inventory exists: " + path)
		press_b()
		await get_tree().create_timer(0.5).timeout
		check(inventory.visible and GameData.current_state == GameData.GameState.PAUSED, "B opens: " + path)
		press_b()
		await get_tree().create_timer(0.4).timeout
		check(not inventory.visible and GameData.current_state == GameData.GameState.EXPLORE, "B closes: " + path)
	var member = GameData.party[0]
	var old_hp: int = member.max_hp
	GameData.award_experience(member, 374)
	check(member.level == 12 and member.experience == 374, "experience below threshold")
	GameData.award_experience(member, 401)
	check(member.level == 14 and member.experience == 0 and member.max_hp == old_hp + 48, "multiple levels and growth")
	GameData.award_experience(member, 31)
	check(SaveManager.save_slot(1), "save progression")
	var data := SaveManager.read_slot(1)
	check(SaveManager.valid_save(data), "v2 validates")
	SaveManager.apply_save(data)
	check(GameData.party[0].level == 14 and GameData.party[0].experience == 31, "restore experience")
	var legacy := data.duplicate(true)
	legacy.version = 1
	legacy.party[0].stats.erase("experience")
	check(SaveManager.valid_save(legacy), "v1 compatibility")
	SaveManager.apply_save(legacy)
	check(GameData.party[0].experience == 0, "v1 starts with zero experience")
	member = GameData.party[0]
	member.level = 98
	member.hp = 0
	GameData.award_experience(member, 100000)
	check(member.level == 99 and member.experience == 0 and member.hp == 0, "level cap and unconscious state")
	SaveManager.reset_game()
	GameData.opening_intro_finished = true
	GameData.party[0].experience = 300
	BattleSystem.start_battle(["蘑菇怪", "蜜蜂精"])
	for enemy in BattleSystem.battle_enemies: enemy.hp = 0
	BattleSystem._check_end()
	check(GameData.party[0].experience == 75 and GameData.party[0].level == 13, "victory gives monster experience")
	BattleSystem._check_end()
	check(GameData.party[0].experience == 75 and GameData.party[0].level == 13, "victory rewards once")
	await get_tree().create_timer(0.4).timeout
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/xianjian-progression.png")
	GlobalMenu._change_scene(GlobalMenu.TITLE_SCENE, {})
	print("PROGRESSION_FAILURES=", failures)
	get_tree().quit(failures)
