## 通用怪物场景脚本：每种怪物共用，具体数值由战斗数据库配置。
extends Node3D

@export var enemy_name: String = "怪物"
@export var base_hp: int = 100
@export var base_attack: int = 20
@export var base_defense: int = 10
@export var base_speed: int = 15

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _ready() -> void:
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(&"idle"):
		sprite.play(&"idle")

