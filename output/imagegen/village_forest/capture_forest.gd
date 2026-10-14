extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for index in range(5):
		await process_frame
	var player := current_scene.get_node("World/Player") as CharacterBody3D
	player.global_position = Vector3(16, 0.06, 10)
	player.velocity = Vector3.ZERO
	for index in range(80):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/village_forest/forest_ingame.png")
	current_scene.set_process(false)
	var camera := current_scene.get_node("Camera") as Camera3D
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 38.0
	camera.global_position = Vector3(15, 28, 45)
	camera.look_at(Vector3(15, 0, 14))
	for index in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://output/imagegen/village_forest/forest_overview.png")
	print("Saved forest ingame and overview captures")
	quit()
