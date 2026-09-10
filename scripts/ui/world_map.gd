## Draws a lightweight world minimap and a full-screen map from world X/Z coordinates.
extends Control

const WORLD_BOUNDS := Rect2(-30.0, -30.0, 60.0, 60.0)
const MAP_FILL := Color(0.07, 0.12, 0.12, 0.92)
const MAP_BORDER := Color(0.86, 0.66, 0.30, 0.95)
const ROAD_COLOR := Color(0.63, 0.48, 0.26, 0.9)
const PLAYER_COLOR := Color(1.0, 0.84, 0.32, 1.0)

var _expanded := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if GameData.current_state != GameData.GameState.EXPLORE:
		return
	if event.is_action_pressed("toggle_map") and not event.is_echo():
		_expanded = not _expanded
		get_viewport().set_input_as_handled()
		queue_redraw()


func _draw() -> void:
	if GameData.current_state != GameData.GameState.EXPLORE:
		return
	if _expanded:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.02, 0.03, 0.72), true)
		var panel_size := Vector2(minf(size.x * 0.72, 760.0), minf(size.y * 0.78, 540.0))
		var panel_rect := Rect2((size - panel_size) * 0.5, panel_size)
		draw_rect(panel_rect.grow(12.0), Color(0.03, 0.06, 0.06, 0.96), true)
		draw_rect(panel_rect.grow(12.0), MAP_BORDER, false, 2.0)
		_draw_map(panel_rect)
		var font := ThemeDB.fallback_font
		draw_string(font, panel_rect.position + Vector2(16, 30), "余 杭 镇 地 图   ·   M 关闭", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1.0, 0.88, 0.58))
	else:
		_draw_map(Rect2(size.x - 188.0, 18.0, 160.0, 160.0), true)


func _draw_map(map_rect: Rect2, circular := false) -> void:
	var center := map_rect.get_center()
	var radius := minf(map_rect.size.x, map_rect.size.y) * 0.5
	if circular:
		draw_circle(center, radius, MAP_FILL)
		draw_arc(center, radius, 0.0, TAU, 64, MAP_BORDER, 2.0, true)
	else:
		draw_rect(map_rect, MAP_FILL, true)
		draw_rect(map_rect, MAP_BORDER, false, 2.0)
	# The two broad roads in the current overworld form a cross at world origin.
	if circular:
		draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), ROAD_COLOR, 10.0)
		draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), ROAD_COLOR, 10.0)
	else:
		draw_rect(Rect2(map_rect.position.x, center.y - 5.0, map_rect.size.x, 10.0), ROAD_COLOR, true)
		draw_rect(Rect2(center.x - 5.0, map_rect.position.y, 10.0, map_rect.size.y), ROAD_COLOR, true)
		for offset in [-20.0, -10.0, 10.0, 20.0]:
			var x := _world_to_map(Vector2(offset, 0.0), map_rect).x
			var y := _world_to_map(Vector2(0.0, offset), map_rect).y
			draw_line(Vector2(x, map_rect.position.y), Vector2(x, map_rect.end.y), Color(0.35, 0.49, 0.42, 0.28), 1.0)
			draw_line(Vector2(map_rect.position.x, y), Vector2(map_rect.end.x, y), Color(0.35, 0.49, 0.42, 0.28), 1.0)
	for building in _get_world_buildings():
		var marker := _world_to_map(Vector2(building.global_position.x, building.global_position.z), map_rect)
		if not circular or marker.distance_to(center) <= radius - 8.0:
			_draw_building_marker(marker)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var marker := _world_to_map(Vector2(player.global_position.x, player.global_position.z), map_rect)
		if not circular or marker.distance_to(center) <= radius - 9.0:
			draw_circle(marker, 6.0, PLAYER_COLOR)
			draw_circle(marker, 9.0, Color(PLAYER_COLOR, 0.24), false, 1.5)


func _get_world_buildings() -> Array[Node3D]:
	var buildings: Array[Node3D] = []
	var world := get_tree().current_scene.get_node_or_null("World")
	if world:
		_collect_buildings(world, buildings)
	return buildings


func _collect_buildings(node: Node, buildings: Array[Node3D]) -> void:
	for child in node.get_children():
		if child is Node3D and String(child.name).to_lower().begins_with("building"):
			buildings.append(child)
		_collect_buildings(child, buildings)


func _draw_building_marker(position: Vector2) -> void:
	var walls := Rect2(position - Vector2(5.0, 1.5), Vector2(10.0, 7.0))
	draw_rect(walls, Color(0.77, 0.60, 0.32, 1.0), true)
	draw_rect(walls, Color(0.21, 0.12, 0.06, 1.0), false, 1.0)
	var roof := PackedVector2Array([position + Vector2(-6.0, -1.5), position + Vector2(0.0, -7.0), position + Vector2(6.0, -1.5)])
	draw_colored_polygon(roof, Color(0.48, 0.18, 0.10, 1.0))


func _world_to_map(world_position: Vector2, map_rect: Rect2) -> Vector2:
	var normalized := (world_position - WORLD_BOUNDS.position) / WORLD_BOUNDS.size
	return map_rect.position + normalized.clamp(Vector2.ZERO, Vector2.ONE) * map_rect.size
