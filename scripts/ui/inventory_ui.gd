## Exploration inventory + equipment overlay. It is toggled by Main after no nearby NPC uses E.
extends Control

const UI_FONT := preload("res://assets/fonts/font.ttf")
const ITEM_ATLAS := preload("res://assets/sucai/tilemap/RPG_Fantasy_Starter_Pack.png")
const MOUSE_FRUIT_ICON := preload("res://assets/sprite/items/鼠儿果.png")
const PLAYER_SCENE := preload("res://scenes/player.tscn")
const LINGER_SCENE := preload("res://scenes/zhao_linger.tscn")
# 图集为 512×512 的 8×8 格；每格正好是 64 像素。
const ICON_SIZE := 64
const CATEGORY_ART := {
	"全部": preload("res://assets/ui/inventory/inventory_1.png"),
	"药品": preload("res://assets/ui/inventory/inventory_2.png"),
	"装备": preload("res://assets/ui/inventory/inventory_3.png"),
	"素材": preload("res://assets/ui/inventory/inventory_4.png"),
	"技能书": preload("res://assets/ui/inventory/inventory_5.png"),
}
const CATEGORIES := ["全部", "药品", "装备", "素材", "技能书"]

@onready var _inventory_window: Control = $Window
@onready var _equipment_window: Control = $EquipmentWindow
@onready var _artwork: TextureRect = $Window/Artwork
@onready var _item_grid: GridContainer = $Window/ItemGrid
@onready var _category_buttons: Control = $Window/CategoryButtons
@onready var _detail_label: Label = $Window/DetailLabel
@onready var _party_tabs: Control = $Window/PartyTabs
@onready var _selected_item_icon: TextureRect = $Window/SelectedItemIcon
@onready var _equipment_slots: Control = $EquipmentWindow/EquipmentSlots
@onready var _character_preview: AnimatedSprite2D = $EquipmentWindow/CharacterPreview
@onready var _member_name: Label = $EquipmentWindow/MemberName
@onready var _stats_label: Label = $EquipmentWindow/StatsLabel
@onready var _category_all: Button = $Window/CategoryButtons/All
@onready var _category_medicine: Button = $Window/CategoryButtons/Medicine
@onready var _category_equipment: Button = $Window/CategoryButtons/Equipment
@onready var _category_material: Button = $Window/CategoryButtons/Material
@onready var _category_skill_book: Button = $Window/CategoryButtons/SkillBook
@onready var _li_xiaoyao_tab: Button = $Window/PartyTabs/LiXiaoyao
@onready var _zhao_linger_tab: Button = $Window/PartyTabs/ZhaoLinger
@onready var _weapon_slot: Button = $EquipmentWindow/EquipmentSlots/WeaponSlot
@onready var _armor_slot: Button = $EquipmentWindow/EquipmentSlots/ArmorSlot
@onready var _accessory_slot: Button = $EquipmentWindow/EquipmentSlots/AccessorySlot

var _selected_party_index := 0
var _selected_category := "全部"
var _selected_item = null
var _selected_skill = null
var _inventory_rest_position := Vector2.ZERO
var _equipment_rest_position := Vector2.ZERO
var _transition: Tween
var _is_closing := false

# RPG Fantasy Starter Pack 图集中，对应当前六种初始道具的格子。
var _item_icon_cells := {
	"金创药": Vector2i(5, 3), # 红色药瓶
	"还神丹": Vector2i(6, 3), # 蓝色药瓶
	"天仙玉露": Vector2i(7, 3), # 绿色药瓶
	"木剑": Vector2i(3, 0),
	"布衣": Vector2i(2, 0), # 旅行背包，作为防具图标
	"青玉佩": Vector2i(5, 4), # 青色晶石饰品
}
var _item_icon_regions := {
	# 鼠儿果原图的有效内容在左上角，背包中也只显示果子本身。
	"鼠儿果": Rect2(0, 0, 42, 36),
}

func _ready() -> void:
	visible = false
	_inventory_rest_position = _inventory_window.position
	_equipment_rest_position = _equipment_window.position
	_category_all.pressed.connect(_select_category.bind("全部"))
	_category_medicine.pressed.connect(_select_category.bind("药品"))
	_category_equipment.pressed.connect(_select_category.bind("装备"))
	_category_material.pressed.connect(_select_category.bind("素材"))
	_category_skill_book.pressed.connect(_select_category.bind("技能书"))
	_li_xiaoyao_tab.pressed.connect(_select_party_member.bind(0))
	_zhao_linger_tab.pressed.connect(_select_zhao_linger)
	_weapon_slot.pressed.connect(_unequip.bind("weapon"))
	_armor_slot.pressed.connect(_unequip.bind("armor"))
	_accessory_slot.pressed.connect(_unequip.bind("accessory"))

func toggle() -> void:
	if _is_closing:
		return
	if visible:
		close()
	else:
		open()

func open() -> void:
	if _transition:
		_transition.kill()
	_is_closing = false
	visible = true
	GameData.current_state = GameData.GameState.PAUSED
	_refresh()
	preload("res://scripts/ui/ui_motion.gd").reveal(self, 0.24)
	var below_screen := Vector2(0.0, _slide_distance())
	_inventory_window.position = _inventory_rest_position + below_screen
	_equipment_window.position = _equipment_rest_position + below_screen
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_transition.tween_property(_inventory_window, "position", _inventory_rest_position, 0.38)
	_transition.tween_property(_equipment_window, "position", _equipment_rest_position, 0.38).set_delay(0.045)

func close() -> void:
	if _is_closing:
		return
	if _transition:
		_transition.kill()
	_is_closing = true
	var below_screen := Vector2(0.0, _slide_distance())
	_transition = create_tween().set_parallel(true)
	_transition.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	_transition.tween_property(_inventory_window, "position", _inventory_rest_position + below_screen, 0.3)
	_transition.tween_property(_equipment_window, "position", _equipment_rest_position + below_screen, 0.3)
	_transition.chain().tween_callback(_finish_close)

func _finish_close() -> void:
	GameData.current_state = GameData.GameState.EXPLORE
	visible = false
	_is_closing = false
	_inventory_window.position = _inventory_rest_position
	_equipment_window.position = _equipment_rest_position

func _slide_distance() -> float:
	return maxf(get_viewport_rect().size.y, 760.0)

func _refresh() -> void:
	_selected_party_index = clampi(_selected_party_index, 0, max(0, GameData.party.size() - 1))
	_artwork.texture = CATEGORY_ART[_selected_category]
	_refresh_categories()
	_refresh_party_tabs()
	for child in _item_grid.get_children():
		_item_grid.remove_child(child)
		child.queue_free()
	if _selected_category == "技能书":
		_refresh_skill_book()
	else:
		for item in GameData.inventory:
			if _matches_category(item):
				_item_grid.add_child(_make_item_slot(item))
	_refresh_equipment_panel()
	_refresh_selected_item_icon()
	if _item_grid.get_child_count() == 0:
		_detail_label.text = _empty_category_hint()
	elif _selected_category == "技能书":
		_detail_label.text = "选择法术查看说明\n当前显示 %s 已掌握的法术" % GameData.party[_selected_party_index].char_name
	else:
		_detail_label.text = "选择物品查看说明\n装备可穿戴给当前角色"

func _refresh_categories() -> void:
	_category_all.button_pressed = _selected_category == "全部"
	_category_medicine.button_pressed = _selected_category == "药品"
	_category_equipment.button_pressed = _selected_category == "装备"
	_category_material.button_pressed = _selected_category == "素材"
	_category_skill_book.button_pressed = _selected_category == "技能书"

func _select_category(category: String) -> void:
	preload("res://scripts/ui/ui_motion.gd").reveal(_item_grid, 0.18)
	_selected_category = category
	_selected_item = null
	_selected_skill = null
	_refresh()

func _matches_category(item) -> bool:
	match _selected_category:
		"全部": return true
		"药品": return item.effect_type == "heal_hp" or item.effect_type == "heal_mp"
		"装备": return not item.equipment_slot.is_empty()
		"素材": return item.effect_type == "material"
		# “技能书”页不再显示背包道具，而是由 _refresh_skill_book()
		# 根据当前选中的角色生成其已掌握法术。
		"技能书": return false
	return true

func _empty_category_hint() -> String:
	return "%s栏暂时没有物品" % _selected_category

func _make_item_slot(item) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 89)
	button.tooltip_text = item.item_name
	button.flat = true
	button.pressed.connect(_select_item.bind(item))
	var icon_rect := TextureRect.new()
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_rect.offset_left = 13.0
	icon_rect.offset_top = 8.0
	icon_rect.offset_right = -13.0
	icon_rect.offset_bottom = -20.0
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = _icon_for_item(item.item_name)
	button.add_child(icon_rect)
	var amount := Label.new()
	amount.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	amount.offset_left = -34.0
	amount.offset_top = -25.0
	amount.offset_right = -6.0
	amount.offset_bottom = -4.0
	amount.text = "×%d" % item.count
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.add_theme_font_override("font", UI_FONT)
	amount.add_theme_font_size_override("font_size", 16)
	amount.add_theme_color_override("font_color", Color("5b3019"))
	amount.add_theme_color_override("font_outline_color", Color("fff3d2"))
	amount.add_theme_constant_override("outline_size", 2)
	button.add_child(amount)
	return button

func _refresh_skill_book() -> void:
	if GameData.party.is_empty():
		return
	for skill in GameData.party[_selected_party_index].skills:
		_item_grid.add_child(_make_skill_slot(skill))

func _make_skill_slot(skill) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(96, 89)
	button.tooltip_text = "%s\n%s" % [skill.skill_name, skill.description]
	button.flat = true
	button.pressed.connect(_show_skill_detail.bind(skill))
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("5b3019"))
	button.add_theme_color_override("font_hover_color", Color("8a4b22"))
	button.add_theme_color_override("font_pressed_color", Color("70401f"))
	button.add_theme_color_override("font_outline_color", Color("fff3d2"))
	button.add_theme_constant_override("outline_size", 2)
	button.text = "%s\n消耗 %d 真气" % [skill.skill_name, skill.mp_cost]
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return button


func _icon_for_item(item_name: String) -> Texture2D:
	if _item_icon_regions.has(item_name):
		var cropped := AtlasTexture.new()
		cropped.atlas = MOUSE_FRUIT_ICON
		cropped.region = _item_icon_regions[item_name]
		return cropped
	var cell: Vector2i = _item_icon_cells.get(item_name, Vector2i(0, 0))
	var icon := AtlasTexture.new()
	icon.atlas = ITEM_ATLAS
	icon.region = Rect2(cell.x * ICON_SIZE, cell.y * ICON_SIZE, ICON_SIZE, ICON_SIZE)
	return icon

func _refresh_party_tabs() -> void:
	_li_xiaoyao_tab.button_pressed = _selected_party_index == 0
	_zhao_linger_tab.visible = GameData.party.size() > 1
	_zhao_linger_tab.button_pressed = _selected_party_index == 1

func _refresh_equipment_panel() -> void:
	if GameData.party.is_empty():
		return
	var member = GameData.party[_selected_party_index]
	_member_name.text = "%s  ·  Lv.%d" % [member.char_name, member.level]
	_stats_label.text = "攻击 %d   防御 %d   身法 %d" % [GameData.get_stat(member, "attack"), GameData.get_stat(member, "defense"), GameData.get_stat(member, "speed")]
	_stats_label.text += "\n" + GameData.experience_text(member)
	_refresh_character_preview(member.char_name)
	var slot_buttons := {
		"weapon": _weapon_slot,
		"armor": _armor_slot,
		"accessory": _accessory_slot,
	}
	for slot in slot_buttons:
		var item = member.equipment.get(slot)
		var button: Button = slot_buttons[slot]
		button.tooltip_text = "%s：%s" % [_slot_label(slot), item.item_name if item else "未装备"]
		button.disabled = item == null
		var icon_rect := button.get_node("Icon") as TextureRect
		icon_rect.visible = item != null
		if item:
			icon_rect.texture = _icon_for_item(item.item_name)

func _refresh_character_preview(member_name: String) -> void:
	var character_scene: PackedScene = LINGER_SCENE if member_name == "赵灵儿" else PLAYER_SCENE
	var preview_entity := character_scene.instantiate()
	var source_sprite := preview_entity.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
	if source_sprite and source_sprite.sprite_frames:
		_character_preview.sprite_frames = source_sprite.sprite_frames
		_character_preview.play(&"idle")
	preview_entity.free()

func _select_party_member(index: int) -> void:
	_selected_party_index = index
	_refresh()

func _select_zhao_linger() -> void:
	if GameData.party.size() > 1:
		_select_party_member(1)

func _select_item(item) -> void:
	_selected_item = item
	if not item.equipment_slot.is_empty() and not GameData.party.is_empty():
		var member = GameData.party[_selected_party_index]
		if GameData.equip_item(member, item):
			_refresh()
			_detail_label.text = "%s 已装备给 %s" % [item.item_name, member.char_name]
		return
	_show_item_detail(item)

func _unequip(slot: String) -> void:
	GameData.unequip_item(GameData.party[_selected_party_index], slot)
	_refresh()

func _slot_label(slot: String) -> String:
	match slot:
		"weapon": return "武器"
		"armor": return "防具"
		"accessory": return "饰品"
		"speed": return "身法"
	return slot

func _show_item_detail(item) -> void:
	_selected_item = item
	_selected_skill = null
	_refresh_selected_item_icon()
	if not item.equipment_slot.is_empty():
		var bonus_parts: Array[String] = []
		for stat in item.stat_bonus:
			bonus_parts.append("%s +%d" % [_slot_label(stat) if stat == "speed" else ("攻击" if stat == "attack" else "防御"), item.stat_bonus[stat]])
		_detail_label.text = "%s\n%s\n点击即可装备给 %s" % [item.item_name, "  ".join(bonus_parts), GameData.party[_selected_party_index].char_name]
		return
	var effect := "恢复 %d 点生命" % item.value if item.effect_type == "heal_hp" else "恢复 %d 点灵力" % item.value
	_detail_label.text = "%s\n%s\n持有数量：%d" % [item.item_name, effect, item.count]

func _show_skill_detail(skill) -> void:
	_selected_skill = skill
	_selected_item = null
	_refresh_selected_item_icon()
	_detail_label.text = "%s\n%s\n消耗：%d 真气" % [skill.skill_name, skill.description, skill.mp_cost]

func _refresh_selected_item_icon() -> void:
	_selected_item_icon.visible = _selected_item != null
	if _selected_item != null:
		_selected_item_icon.texture = _icon_for_item(_selected_item.item_name)

func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if not visible:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("toggle_inventory"):
		close()
		get_viewport().set_input_as_handled()
