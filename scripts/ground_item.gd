## 可复用的地面拾取物。实例化后只需在 Inspector 填写物品资料和图标。
extends Node3D

@export_category("拾取物资料")
@export var item_name: String = "鼠儿果"
@export_enum("heal_hp", "heal_mp", "material", "equipment") var effect_type: String = "heal_hp"
@export var value: int = 50
@export_range(1, 99, 1) var amount: int = 1
# 非装备物品留空；装备填 weapon、armor 或 accessory。
@export var equipment_slot: String = ""
@export var attack_bonus: int = 0
@export var defense_bonus: int = 0
@export var speed_bonus: int = 0

@export_category("场景显示")
@export var interaction_radius: float = 1.8
@export var item_texture: Texture2D
@export var prompt_text: String = "[E] 拾取"

@onready var _sprite: Sprite3D = $ItemSprite
@onready var _prompt: Label3D = $PromptLabel

var _collected := false
var _base_height := 0.0

func _save_key() -> String:
	# current_scene may not yet be assigned while the new scene enters the tree.
	var ancestor: Node = self
	while ancestor.get_parent() and ancestor.get_parent() != get_tree().root:
		ancestor = ancestor.get_parent()
	return ancestor.scene_file_path + ":" + str(ancestor.get_path_to(self))

func _ready() -> void:
	if SaveManager.collected_items.has(_save_key()):
		_collected = true
		hide()
		queue_free()
		return
	add_to_group("ground_items")
	_base_height = _sprite.position.y
	_sprite.texture = item_texture if item_texture else _sprite.texture
	_prompt.text = "%s %s ×%d" % [prompt_text, item_name, amount]
	_prompt.visible = false

func _process(_delta: float) -> void:
	if _collected:
		return
	_sprite.position.y = _base_height + sin(Time.get_ticks_msec() * 0.004) * 0.08
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player:
		return
	_prompt.visible = GameData.current_state == GameData.GameState.EXPLORE and is_in_pickup_range(player.global_position)

func is_in_pickup_range(player_position: Vector3) -> bool:
	var offset := global_position - player_position
	offset.y = 0.0
	return offset.length() <= interaction_radius

func try_pickup(player_position: Vector3) -> bool:
	if _collected or not is_in_pickup_range(player_position):
		return false
	_collected = true
	SaveManager.collected_items[_save_key()] = true
	_prompt.visible = false
	var existing = GameData.inventory.filter(func(item):
		return item.item_name == item_name and item.effect_type == effect_type and item.equipment_slot == equipment_slot
	)
	if not existing.is_empty() and equipment_slot.is_empty():
		existing[0].count += amount
	else:
		var bonus := {"attack": attack_bonus, "defense": defense_bonus, "speed": speed_bonus}
		GameData.inventory.append(GameData.Item.new(item_name, effect_type, value, amount, equipment_slot, bonus))
	_play_pickup_feedback()
	return true

func _play_pickup_feedback() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.22)
	tween.tween_property(_sprite, "position:y", _sprite.position.y + 0.6, 0.22)
	tween.chain().tween_callback(queue_free)
