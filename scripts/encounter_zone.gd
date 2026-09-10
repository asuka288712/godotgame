## 遇敌区域 — Area3D, 玩家踩入后概率触发战斗
extends Area3D

@export var enemy_pool: PackedStringArray = PackedStringArray(["蛇妖", "蛤蟆怪"])
@export var encounter_chance: float = 0.15
@export var cooldown: float = 8.0

var _in_zone: bool = false
var _cooldown_timer: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D: _in_zone = true

func _on_body_exited(body: Node) -> void:
	if body is CharacterBody3D: _in_zone = false

func _process(delta: float) -> void:
	if _cooldown_timer > 0.0: _cooldown_timer -= delta
	if not _in_zone: return
	if GameData.current_state != GameData.GameState.EXPLORE: return
	if _cooldown_timer > 0.0: return
	if randf() < encounter_chance * delta * 2.0: _trigger_encounter()

func _trigger_encounter() -> void:
	_cooldown_timer = cooldown
	var count: int = randi_range(1, 2)
	var names: Array = []
	for i in range(count): names.append(enemy_pool[randi() % enemy_pool.size()])
	BattleSystem.start_battle(names)
