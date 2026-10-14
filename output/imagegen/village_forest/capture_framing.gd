extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for index in range(8):
		await process_frame
	var player := current_scene.get_node("World/Player") as CharacterBody3D
	var camera := current_scene.get_node("Camera") as Camera3D
	for place in [Vector3(0, 0.06, 0), Vector3(16, 0.06, 10), Vector3(24, 0.06, 23)]:
		player.global_position = place
		player.velocity = Vector3.ZERO
		preload("res://scripts/exploration_camera.gd").follow(camera, player, 1.0)
		for index in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		var label := "village" if place.x == 0 else ("forest" if place.x == 16 else "forest_edge")
		root.get_texture().get_image().save_png("res://output/imagegen/village_forest/framing_" + label + ".png")
		print("CAPTURE: ", label, " size=", camera.size)
	quit()
