## 游戏数据自动加载单例 — 管理角色数据、背包、输入映射和全局状态
extends Node

const SCENE_TITLE_FONT := preload("res://assets/fonts/font.ttf")

enum GameState { EXPLORE, DIALOGUE, BATTLE, BATTLE_TRANSITION, PAUSED }

# ======================== 数据类 ========================
class CharStats:
	var char_name: String
	var level: int
	var hp: int; var max_hp: int
	var mp: int; var max_mp: int
	var attack: int; var defense: int; var speed: int
	var skills: Array
	var portrait_color: Color
	var equipment: Dictionary = {"weapon": null, "armor": null, "accessory": null}
	func _init(n:String,lv:int,h:int,m:int,a:int,d:int,s:int,sk:Array,c:Color):
		char_name=n;level=lv;hp=h;max_hp=h;mp=m;max_mp=m
		attack=a;defense=d;speed=s;skills=sk;portrait_color=c

class Skill:
	var skill_name: String
	var mp_cost: int; var power: float
	var type: String; var target_type: String; var description: String
	# 从行动点到释放点所需的读条时间。0 表示立即行动（普攻、道具、防御）。
	var cast_time: float
	func _init(n:String,c:int,p:float,t:String,tt:String,desc:String,cast:float=0.0):
		skill_name=n;mp_cost=c;power=p;type=t;target_type=tt;description=desc;cast_time=cast

class Item:
	var item_name: String; var effect_type: String
	var value: int; var count: int
	var equipment_slot: String
	var stat_bonus: Dictionary
	func _init(n:String,e:String,v:int,c:int,slot:String="",bonus:Dictionary={}):
		item_name=n;effect_type=e;value=v;count=c
		equipment_slot=slot;stat_bonus=bonus

# ======================== 全局状态 ========================
var current_state: GameState = GameState.EXPLORE
var party: Array = []
var inventory: Array = []
var opening_intro_finished := false
var _scene_title_layer: CanvasLayer

func _ready() -> void:
	_setup_input_map()
	_init_party()
	_init_inventory()

func _setup_input_map() -> void:
	_bind("move_up",KEY_W);_bind("move_up",KEY_UP)
	_bind("move_down",KEY_S);_bind("move_down",KEY_DOWN)
	_bind("move_left",KEY_A);_bind("move_left",KEY_LEFT)
	_bind("move_right",KEY_D);_bind("move_right",KEY_RIGHT)
	_bind("interact",KEY_E)
	_bind("jump",KEY_SPACE);_bind("jump",KEY_J)
	_bind("confirm",KEY_ENTER)
	_bind("cancel",KEY_ESCAPE)
	_bind("toggle_map",KEY_M)
	_bind("debug_battle",KEY_F1)

func _bind(action:String,key:Key)->void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev:=InputEventKey.new();ev.physical_keycode=key
	InputMap.action_add_event(action,ev)

func _init_party()->void:
	var xy:Array=[
		Skill.new("御剑术",8,1.5,"attack","single_enemy","以真气御剑攻击单个敌人",0.8),
		Skill.new("天师符法",15,0.0,"debuff","single_enemy","天师符咒使单个敌人进入易伤状态",0.7),
		Skill.new("气疗术",8,75.0,"heal","single_ally","恢复单个同伴 75 点生命",0.6),
	]
	# 李逍遥速度为赵灵儿两倍；行动条的节奏由这里的基础 speed 决定。
	party.append(CharStats.new("李逍遥",12,280,60,45,30,40,xy,Color(0.25,0.45,0.85)))

func recruit_zhao_linger() -> void:
	if party.any(func(member): return member.char_name == "赵灵儿"):
		return
	var lr:Array=[
		Skill.new("回梦",10,2.0,"heal","single_ally","以灵力恢复同伴大量生命",0.7),
		Skill.new("灵血咒",15,150.0,"heal","single_ally","恢复单个同伴 150 点生命",0.8),
		Skill.new("雷咒",14,2.2,"attack","single_enemy","召唤雷电劈向单个敌人",0.9),
		Skill.new("炎咒",16,2.5,"attack","single_enemy","召唤烈焰焚烧单个敌人",0.9),
		Skill.new("流星火雨",25,5.0,"attack","single_enemy","召唤流星火雨轰击单个敌人",2.0),
		Skill.new("土咒",12,1.9,"attack","single_enemy","召唤土灵冲击单个敌人",0.8),
		Skill.new("风卷残云",12,1.8,"attack","all_enemies","召唤狂风攻击全体敌人",1.0),
	]
	party.append(CharStats.new("赵灵儿",11,220,80,35,25,20,lr,Color(0.95,0.75,0.85)))

func equip_item(member: CharStats, item: Item) -> bool:
	if item.equipment_slot.is_empty() or item.count <= 0:
		return false
	var previous: Item = member.equipment.get(item.equipment_slot)
	if previous:
		previous.count += 1
		if not inventory.has(previous):
			inventory.append(previous)
	item.count -= 1
	if item.count <= 0:
		inventory.erase(item)
	member.equipment[item.equipment_slot] = item
	return true

func unequip_item(member: CharStats, slot: String) -> void:
	var item: Item = member.equipment.get(slot)
	if not item:
		return
	item.count += 1
	if not inventory.has(item):
		inventory.append(item)
	member.equipment[slot] = null

func get_stat(member: CharStats, stat_name: String) -> int:
	var total: int = member.get(stat_name)
	for equipped in member.equipment.values():
		if equipped:
			total += int(equipped.stat_bonus.get(stat_name, 0))
	return total

func show_scene_title(scene_name: String) -> void:
	if _scene_title_layer and is_instance_valid(_scene_title_layer):
		_scene_title_layer.queue_free()
	_scene_title_layer = CanvasLayer.new()
	_scene_title_layer.layer = 20
	get_tree().root.add_child(_scene_title_layer)
	var label := Label.new()
	label.text = scene_name
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -420.0
	label.offset_top = 82.0
	label.offset_right = 420.0
	label.offset_bottom = 154.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", SCENE_TITLE_FONT)
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color(1.0, 0.87, 0.48))
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.03, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 3)
	label.add_theme_constant_override("shadow_offset_y", 3)
	_scene_title_layer.add_child(label)
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_scene_title_layer.queue_free)

func _init_inventory()->void:
	inventory.append(Item.new("金创药","heal_hp",100,5))
	inventory.append(Item.new("还神丹","heal_mp",50,3))
	inventory.append(Item.new("天仙玉露","heal_hp",300,1))
	inventory.append(Item.new("木剑","equipment",0,1,"weapon",{"attack": 8}))
	inventory.append(Item.new("布衣","equipment",0,2,"armor",{"defense": 5}))
	inventory.append(Item.new("青玉佩","equipment",0,1,"accessory",{"speed": 6}))
