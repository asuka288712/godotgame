## 挂在 battle_ui.tscn/StatusCardTemplate 上；布局可直接在该场景的 Inspector 调整。
extends Panel

# 后续在此填入你的 PNG 路径，空字符串时使用临时生成的图片血条。
const STATUS_BAR_TEXTURE_PATHS := {
	"under": "",
	"hp": "res://assets/ui/hud/hp.png",
	"mp": "res://assets/ui/hud/mp.png",
}

func setup(battler, is_enemy: bool, font: Font, portrait_paths: Dictionary, statuses: Array = []) -> void:
	_set_panel_style(is_enemy)
	var avatar_frame := $AvatarFrame as Panel
	# 头像不再使用旧的彩色方框，只显示实际头像贴图。
	avatar_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var portrait_source = portrait_paths.get(battler.char_name)
	var avatar := $AvatarFrame/AvatarTexture as TextureRect
	if portrait_source is Texture2D:
		avatar.texture = portrait_source
	elif portrait_source is String and not portrait_source.is_empty():
		avatar.texture = load(portrait_source) as Texture2D
	else:
		avatar.texture = null
	var initial := $AvatarFrame/AvatarInitial as Label
	initial.text = battler.char_name.left(1)
	initial.visible = avatar.texture == null
	_set_label($NameLabel, battler.char_name, font, 17, Color(1.0, 0.85, 0.60) if is_enemy else Color(0.78, 0.95, 1.0))
	_set_resource_bar($HPBar, $HPValue, "精", battler.hp, battler.max_hp, "hp", Color(0.84, 0.22, 0.19), font)
	if has_node("MPBar") and has_node("MPValue"):
		_set_resource_bar($MPBar, $MPValue, "神", battler.mp, battler.max_mp, "mp", Color(0.18, 0.43, 0.82), font)
	_set_statuses(statuses, font)

func _make_head_portrait(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return texture
	var used := image.get_used_rect()
	# 像素尺寸太小的怪物帧直接完整显示，避免误裁掉身体。
	if used.size.x < 128 or used.size.y < 128:
		return texture
	var crop_size := mini(int(used.size.x * 0.80), int(used.size.y * 0.52))
	var crop_x := clampi(used.position.x + int((used.size.x - crop_size) * 0.5), 0, image.get_width() - crop_size)
	var crop_y := clampi(used.position.y, 0, image.get_height() - crop_size)
	var head_image := image.get_region(Rect2i(crop_x, crop_y, crop_size, crop_size))
	return ImageTexture.create_from_image(head_image)

func _set_panel_style(_is_enemy: bool) -> void:
	# 完全取消旧 Panel 的默认深色底；卡片外观只使用 battle_ui.tscn 的 BackgroundArt。
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

func _set_label(label: Label, text_value: String, font: Font, font_size: int, color: Color) -> void:
	label.text = text_value
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)

func _set_resource_bar(bar: TextureProgressBar, label: Label, prefix: String, value: int, maximum: int, texture_key: String, fill_color: Color, font: Font) -> void:
	bar.texture_under = _get_bar_texture("under", Color(0.08, 0.10, 0.12), true)
	bar.texture_progress = _get_bar_texture(texture_key, fill_color)
	bar.nine_patch_stretch = true
	bar.max_value = max(maximum, 1)
	bar.value = clampi(value, 0, maximum)
	_set_label(label, "%s  %d / %d" % [prefix, value, maximum], font, 12, Color(1, 1, 1, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 0.95))
	label.add_theme_constant_override("outline_size", 2)

func _set_statuses(statuses: Array, font: Font) -> void:
	var row := $StatusIcons as Control
	for child in row.get_children():
		child.queue_free()
	if statuses.is_empty():
		return
	for index in range(statuses.size()):
		var status: Dictionary = statuses[index]
		var icon := Button.new()
		icon.flat = true
		icon.position = Vector2(index * 44, 0)
		icon.size = Vector2(40, 40)
		icon.tooltip_text = status.get("description", "状态效果")
		var icon_path: String = status.get("icon_path", "")
		var status_texture := load(icon_path) as Texture2D if not icon_path.is_empty() else null
		if status_texture:
			icon.icon = status_texture
			icon.expand_icon = true
			icon.text = ""
		else:
			icon.text = status.get("symbol", "?")
		icon.add_theme_font_override("font", font)
		icon.add_theme_font_size_override("font_size", 12)
		icon.add_theme_color_override("font_color", status.get("color", Color.WHITE))
		icon.add_theme_color_override("font_hover_color", Color.WHITE)
		row.add_child(icon)

func _get_bar_texture(texture_key: String, color: Color, with_border := false) -> Texture2D:
	var external_path: String = STATUS_BAR_TEXTURE_PATHS.get(texture_key, "")
	if not external_path.is_empty():
		var external_texture := load(external_path) as Texture2D
		if external_texture:
			return external_texture
	var image := Image.create(200, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in range(18):
		for x in range(200):
			var edge_distance: int = mini(mini(x, 199 - x), mini(y, 17 - y))
			if (x < 8 or x > 191) and (y < 8 or y > 9):
				var corner_x: int = 8 if x < 8 else 191
				var corner_y: int = 8 if y < 8 else 9
				if Vector2(x - corner_x, y - corner_y).length() > 8.0:
					continue
			var pixel_color: Color = color.lightened(0.20) if y < 4 else color
			if with_border and edge_distance < 2:
				pixel_color = Color(0.78, 0.69, 0.48)
			image.set_pixel(x, y, pixel_color)
	return ImageTexture.create_from_image(image)
