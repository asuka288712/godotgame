## 回归测试：探索镜头的取景框下缘必须始终留在地面之上。
## 正交取景框是一块斜面，一旦下缘落到地面以下，画面底部就会露出天空
## （村庄里表现为一条一直不消失的蓝色横带）。
## 运行：godot --path . --script res://tests/exploration_camera_ground_fill.gd
extends SceneTree

const ExplorationCamera := preload("res://scripts/exploration_camera.gd")
const OUT_DIR := "res://output/diag"
const SETTLE_FRAMES := 90
# 相机跟随有阻尼，留一点容差；地面在村庄/室内都位于 y≈0。
const TOLERANCE := 0.25

const PLACES := {
	"village_crossroad": Vector3(0.0, 0.05, 0.0),
	"inn_entrance": Vector3(-4.8, 0.05, -3.5),
	"north_road": Vector3(0.0, 0.05, -11.0),
	"forest": Vector3(16.0, 0.05, 10.0),
	"south_edge": Vector3(0.0, 0.05, 26.0),
}

const SCENES := [
	"res://scenes/lijiakezhan.tscn",
	"res://scenes/chapter/inn_guestroom.tscn",
	"res://scenes/chapter/yuhang_market.tscn",
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var failures := 0
	change_scene_to_file("res://scenes/main.tscn")
	for index in range(SETTLE_FRAMES):
		await process_frame
	for place_name in PLACES:
		var player := get_first_node_in_group("player") as CharacterBody3D
		player.global_position = PLACES[place_name]
		player.velocity = Vector3.ZERO
		failures += await _check(place_name, player)
	for scene_path in SCENES:
		change_scene_to_file(scene_path)
		for index in range(SETTLE_FRAMES):
			await process_frame
		var player := get_first_node_in_group("player") as CharacterBody3D
		var scene_name: String = String(scene_path).get_file().get_basename()
		failures += await _check(scene_name, player)
	print("ground_fill: %s" % ("FAIL (%d)" % failures if failures > 0 else "PASS"))
	quit(1 if failures > 0 else 0)

## 等待相机稳定后，用底部中间的射线起点衡量取景框下缘离地面的高度。
func _check(label: String, player: CharacterBody3D) -> int:
	var camera := get_first_node_in_group("player").get_viewport().get_camera_3d()
	for index in range(SETTLE_FRAMES):
		await process_frame
	var viewport_size := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	var bottom_origin := camera.project_ray_origin(Vector2(viewport_size.x * 0.5, viewport_size.y))
	var ground_y := player.global_position.y
	var clearance := bottom_origin.y - ground_y
	var expected := ExplorationCamera.GROUND_CLEARANCE
	var ok := clearance >= expected - TOLERANCE
	var status := "PASS" if ok else "FAIL"
	print("%-22s %s  bottom_edge=%5.2f  clearance=%5.2f (>= %.1f)  size=%.1f" % [
		label, status, bottom_origin.y, clearance, expected, camera.size
	])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/verify_%s.png" % [OUT_DIR, label])
	return 0 if ok else 1
