extends SceneTree

var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func settle() -> void:
	for index in range(4):
		await process_frame
	await physics_frame

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await settle()
	var scene := current_scene
	var trees := scene.get_node("World/VillageVegetation/Forest/Trees")
	check(trees.get_child_count() == 36, "36 forest trees instantiated")
	check(scene.get_node("World/VillageVegetation/GroundPlants").get_child_count() == 213, "213 ground props instantiated")
	check(scene.get_node("World/VillageVegetation/Forest/Trail").get_child_count() == 13, "continuous forest trail instantiated")
	var player := scene.get_node("World/Player") as CharacterBody3D
	var waypoints := [Vector3(12,0.06,0),Vector3(12,0.06,6),Vector3(16,0.06,10),Vector3(20,0.06,12),Vector3(22,0.06,17),Vector3(24,0.06,23),Vector3(25,0.06,27)]
	var clear := true
	for index in range(waypoints.size() - 1):
		player.global_position = waypoints[index]
		await physics_frame
		if player.test_move(player.global_transform, waypoints[index + 1] - waypoints[index]):
			clear = false
	check(clear, "player collider can traverse all forest trail segments")
	var tree := trees.get_child(0) as StaticBody3D
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.15
	query.shape = sphere
	query.transform.origin = tree.global_position + Vector3.UP
	check(not scene.get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "tree trunk physically blocks movement")
	var gate := scene.get_node("ChapterLinks/temple")
	check(gate.position == Vector3(25,0,27), "Shilipo entrance is at forest trail end")
	gate.interact()
	await settle()
	check(current_scene.scene_file_path.ends_with("mountain_temple.tscn"), "forest entrance reaches Shilipo")
	current_scene.get_node("World/Interactions/market").interact()
	await settle()
	check(current_scene.scene_file_path.ends_with("main.tscn"), "Shilipo returns to village")
	player = current_scene.get_node("World/Player")
	check(player.global_position.distance_to(Vector3(24,0.1,23)) < 0.25, "return places hero inside forest away from exit")
	var market: Node = load("res://scenes/chapter/yuhang_market.tscn").instantiate()
	check(not market.has_node("World/Interactions/temple"), "market has no shortcut to Shilipo")
	market.free()
	print("FOREST CHECKS COMPLETE: ", failures, " failures")
	quit(failures)
