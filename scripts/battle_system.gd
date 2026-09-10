## 战斗系统自动加载单例 — 回合制战斗核心逻辑
extends Node

signal battle_started(enemies:Array)
signal battle_ended(victory:bool)
signal turn_changed(character,is_party:bool)
signal action_gauges_updated(entries:Array)
signal action_executed(desc:String)
signal damage_dealt(target_name:String,amount:int,is_heal:bool)
signal attack_missed(target_name:String)
signal cast_interrupted(target_name:String)
signal attack_animation_requested(attacker_name:String,target_name:String)
signal lightning_strike_requested(target_name:String)
signal elemental_spell_requested(spell_name: String, target_name: String)
signal zhao_magic_cast_requested(target_name:String)
signal zhao_magic_cast_finished
signal sword_slash_requested(attacker_name:String,target_name:String)
signal attack_sfx_requested(attacker_name:String)
signal yujian_magic_cast_requested
signal yujian_sword_rain_requested(target_name:String)
signal yujian_magic_cast_finished
signal tianshi_fufa_requested(target_name:String)
signal healing_effect_requested(target_name:String)
signal li_skill_shout_requested
signal wind_skill_requested(caster_name:String,target_name:String)
signal request_player_action

enum BState{STARTING,WAITING,SELECT_COMMAND,SELECT_SKILL,SELECT_ITEM,SELECT_TARGET,EXECUTING,ENEMY_TURN,VICTORY,DEFEAT}

var state:BState=BState.STARTING
var turn_order:Array=[]
var current_turn:int=0
var selected_action:String=""
var selected_skill=null
var selected_item=null
var battle_enemies:Array=[]
var combat_party: Array = []
var _defending:Dictionary={}
var _vulnerable: Dictionary = {}
const ATB_FILL_RATE := 0.28
# 行动点偏右：准备跑到 60，法术再从 60 读到 100 才会释放。
const ACTION_POINT := 60.0
var _action_gauges: Array[float] = []
enum ActorState { PREPARING, READY, CASTING, ACTING, DEAD }
var _actor_states: Array[ActorState] = []
var _ready_party_queue: Array[int] = []
var _active_menu_actor := -1
var _attack_targets: Dictionary = {}
# Lets the UI distinguish a voluntary retreat from a defeat, while retaining
# the existing battle_ended signal used by the arena and scene controller.
var did_escape: bool = false

var _enemy_db:Dictionary={
	"蘑菇怪":{"hp":90,"mp":0,"atk":18,"def":8,"spd":12,"color":Color(0.48,0.72,0.42)},
	"死士":{"hp":160,"mp":0,"atk":32,"def":18,"spd":19,"color":Color(0.55,0.48,0.52)},
	"蛇妖":{"hp":120,"mp":0,"atk":25,"def":15,"spd":25,"color":Color(0.3,0.7,0.3)},
	"蛤蟆怪":{"hp":180,"mp":0,"atk":30,"def":20,"spd":9,"color":Color(0.5,0.6,0.2)},
	"蜜蜂精":{"hp":80,"mp":10,"atk":20,"def":10,"spd":32,"color":Color(0.9,0.8,0.1)},
}

func start_battle(enemy_names:Array, party_override:Array=[])->void:
	GameData.current_state=GameData.GameState.BATTLE
	state=BState.STARTING;battle_enemies.clear();_defending.clear();_vulnerable.clear();did_escape=false
	# 复制列表而非角色数据：战斗伤血仍写回角色，但结束清理不会误删全局队伍。
	combat_party = party_override.duplicate() if not party_override.is_empty() else GameData.party.duplicate()
	var duplicate_counts: Dictionary = {}
	for ename in enemy_names:
		var t:Dictionary=_enemy_db.get(ename,_enemy_db["蛇妖"])
		duplicate_counts[ename] = int(duplicate_counts.get(ename, 0)) + 1
		var display_name: String = ename if duplicate_counts[ename] == 1 else "%s#%d" % [ename, duplicate_counts[ename]]
		battle_enemies.append(GameData.CharStats.new(display_name,1,t.hp,t.mp,t.atk,t.def,t.spd,[],t.color))
	_build_turn_order()
	_action_gauges.resize(turn_order.size()); _action_gauges.fill(0.0)
	_actor_states.resize(turn_order.size()); _actor_states.fill(ActorState.PREPARING)
	_ready_party_queue.clear(); _active_menu_actor = -1; _attack_targets.clear()
	_set_opening_gauge_order()
	battle_started.emit(battle_enemies)
	await get_tree().create_timer(0.6).timeout
	_begin_turn()

func _build_turn_order()->void:
	turn_order.clear()
	for i in range(combat_party.size()):
		turn_order.append({"stats":combat_party[i],"is_party":true,"idx":i})
	for i in range(battle_enemies.size()):
		turn_order.append({"stats":battle_enemies[i],"is_party":false,"idx":i})
	# 实际行动顺序由独立跑条决定；仅在开场按速度预排位置。

func _set_opening_gauge_order() -> void:
	# 战斗开场不从零齐跑：按速度预排在行动点前，最快者最接近行动点。
	var indexes: Array[int] = []
	for index in range(turn_order.size()):
		indexes.append(index)
	indexes.sort_custom(func(a: int, b: int): return GameData.get_stat(turn_order[a].stats, "speed") > GameData.get_stat(turn_order[b].stats, "speed"))
	var last_rank := maxi(indexes.size() - 1, 1)
	for rank in range(indexes.size()):
		# 整体向起点后退，开场仍有速度先后，但不会立刻有人贴近行动点。
		var progress := lerpf(3.0, ACTION_POINT - 10.0, 1.0 - float(rank) / float(last_rank))
		_action_gauges[indexes[rank]] = progress

func _process(delta: float) -> void:
	# 选菜单时保留传统回合制的停顿，确认指令后（攻击/施法演出期间）恢复全体跑条。
	var selecting_command := state in [BState.SELECT_COMMAND, BState.SELECT_SKILL, BState.SELECT_ITEM, BState.SELECT_TARGET]
	# STARTING 的开场展示期只显示预排位置，不推进；避免菜单刚弹出又被初始化状态覆盖。
	if GameData.current_state == GameData.GameState.BATTLE and state not in [BState.STARTING, BState.VICTORY, BState.DEFEAT] and not selecting_command:
		_update_action_gauges(delta)

func _update_action_gauges(delta: float) -> void:
	for index in range(turn_order.size()):
		var stats = turn_order[index].stats
		if stats.hp <= 0:
			_actor_states[index] = ActorState.DEAD
			continue
		var actor_state := _actor_states[index]
		if actor_state == ActorState.PREPARING:
			_action_gauges[index] = minf(ACTION_POINT, _action_gauges[index] + GameData.get_stat(stats, "speed") * ATB_FILL_RATE * delta)
			if _action_gauges[index] >= ACTION_POINT:
				_actor_states[index] = ActorState.READY
				if turn_order[index].is_party:
					_ready_party_queue.append(index)
				else:
					_start_enemy_action(index)
		elif actor_state == ActorState.CASTING:
			_action_gauges[index] = minf(100.0, _action_gauges[index] + float(_cast_speeds.get(index, GameData.get_stat(stats, "speed") * ATB_FILL_RATE)) * delta)
			if _action_gauges[index] >= 100.0:
				_actor_states[index] = ActorState.ACTING
				_finish_cast(index)
	_emit_action_gauges()
	_try_open_next_party_menu()

func _emit_action_gauges() -> void:
	var entries: Array = []
	for index in range(turn_order.size()):
		var entry: Dictionary = turn_order[index]
		entries.append({
			"id": index,
			"character": entry.stats,
			"is_party": entry.is_party,
			"progress": _action_gauges[index] if index < _action_gauges.size() else 0.0,
			"actor_state": _actor_states[index] if index < _actor_states.size() else ActorState.DEAD,
		})
	action_gauges_updated.emit(entries)

func _begin_turn()->void:
	state = BState.WAITING

func _try_open_next_party_menu() -> void:
	if _active_menu_actor >= 0 or _ready_party_queue.is_empty() or state in [BState.VICTORY, BState.DEFEAT]:
		return
	while not _ready_party_queue.is_empty():
		var index: int = _ready_party_queue.pop_front()
		if index < 0 or index >= turn_order.size() or _actor_states[index] != ActorState.READY:
			continue
		current_turn = index; _active_menu_actor = index
		var t: Dictionary = turn_order[index]
		_defending.erase(t.stats.char_name)
		selected_action = ""; selected_skill = null; selected_item = null
		state = BState.SELECT_COMMAND
		turn_changed.emit(t.stats, true); request_player_action.emit()
		return

func select_command(cmd:String)->void:
	if state!=BState.SELECT_COMMAND:return
	selected_action=cmd
	match cmd:
		"attack":state=BState.SELECT_TARGET
		"skill":state=BState.SELECT_SKILL
		"item":state=BState.SELECT_ITEM
		"defend":_do_defend()
		"escape":escape_battle()

func escape_battle() -> void:
	# Escape is only available from the command menu, before a character has
	# committed an action for this turn.
	if state != BState.SELECT_COMMAND:
		return
	did_escape = true
	state = BState.DEFEAT
	action_executed.emit("队伍成功逃离了战斗！")
	battle_ended.emit(false)

func select_skill(skill)->void:
	if state != BState.SELECT_SKILL:
		return
	selected_action = "skill"
	selected_skill=skill
	if skill.mp_cost>turn_order[current_turn].stats.mp:return
	if skill.target_type in["single_enemy","single_ally"]:
		state=BState.SELECT_TARGET
	else:
		_commit_cast(current_turn, skill, -1, true)

func select_item(item)->void:
	if state != BState.SELECT_ITEM:
		return
	selected_action = "item"
	selected_item=item;state=BState.SELECT_TARGET

func confirm_target(target_idx:int,is_enemy_target:bool=true)->void:
	if _active_menu_actor < 0 or current_turn != _active_menu_actor:
		return
	var actor_index := current_turn
	var attacker=turn_order[actor_index].stats
	_close_player_menu()
	match selected_action:
		"attack":
			if is_enemy_target and target_idx<battle_enemies.size():
				_run_normal_attack(actor_index, target_idx, true)
			elif not is_enemy_target and target_idx < combat_party.size():
				_run_normal_attack(actor_index, target_idx, false)
		"skill":
			_commit_cast(actor_index, selected_skill, target_idx, is_enemy_target)
		"item":
			_use_item_on(target_idx)
			_reset_actor(actor_index)

func _close_player_menu() -> void:
	_active_menu_actor = -1
	state = BState.WAITING

func _commit_cast(actor_index: int, skill, target_idx: int, is_enemy: bool) -> void:
	if skill == null or actor_index < 0 or actor_index >= turn_order.size():
		return
	_close_player_menu()
	# 读条为行动点→100；按技能施法时长换算速度，保证每个法术各自不同。
	if skill.cast_time <= 0.0:
		_actor_states[actor_index] = ActorState.ACTING
		_execute_skill(actor_index, skill, target_idx, is_enemy)
		return
	_actor_states[actor_index] = ActorState.CASTING
	# 使 "cast_time" 大致等于后半段读完所需秒数。
	var speed := GameData.get_stat(turn_order[actor_index].stats, "speed") * ATB_FILL_RATE
	if speed > 0.0:
		# progress 的实际推进由 _update_action_gauges 统一完成；把技能时长折算成临时倍率。
		_cast_speeds[actor_index] = (100.0 - ACTION_POINT) / maxf(skill.cast_time, 0.1)
	_cast_contexts[actor_index] = {"skill": skill, "target_idx": target_idx, "is_enemy": is_enemy}

var _cast_speeds: Dictionary = {}
var _cast_contexts: Dictionary = {}

func _finish_cast(actor_index: int) -> void:
	var context: Dictionary = _cast_contexts.get(actor_index, {})
	_cast_contexts.erase(actor_index); _cast_speeds.erase(actor_index)
	if context.is_empty():
		_reset_actor(actor_index)
		return
	_execute_skill(actor_index, context.skill, int(context.target_idx), bool(context.is_enemy))

func _run_normal_attack(actor_index: int, target_idx: int, target_is_enemy: bool) -> void:
	if actor_index < 0 or actor_index >= turn_order.size(): return
	var attacker = turn_order[actor_index].stats
	var targets: Array = battle_enemies if target_is_enemy else combat_party
	if target_idx < 0 or target_idx >= targets.size() or targets[target_idx].hp <= 0:
		_reset_actor(actor_index); return
	var target = targets[target_idx]
	_actor_states[actor_index] = ActorState.ACTING
	_attack_targets[actor_index] = {"name": target.char_name, "actor": _find_actor_index(target), "normal": true}
	attack_animation_requested.emit(attacker.char_name, target.char_name)
	await _wait_for_attack_impact(attacker.char_name, target.char_name)
	var arena := get_tree().get_first_node_in_group("battle_arena")
	# 命中帧只检查目标是否仍守在自己的固定站位；已经冲出去攻击的人不会被打中。
	var target_left_home: bool = false
	if arena and arena.has_method("is_battler_at_home"):
		target_left_home = not bool(arena.is_battler_at_home(target.char_name))
	if target_left_home:
		attack_missed.emit(target.char_name)
		action_executed.emit("%s 攻击 %s，但目标已离开原位，攻击落空！" % [attacker.char_name, target.char_name])
	else:
		# 怪物保留冲刺和受击反馈，不套用我方的剑光特效。
		if turn_order[actor_index].is_party:
			attack_sfx_requested.emit(attacker.char_name)
			sword_slash_requested.emit(attacker.char_name, target.char_name)
			if attacker.char_name == "赵灵儿":
				# 赵灵儿的普攻有两段：每段各自播放一次剑光、各结算半段攻击倍率。
				_deal_damage(attacker, target, 0.5)
				await get_tree().create_timer(0.40).timeout
				var still_at_home := not arena or not arena.has_method("is_battler_at_home") or bool(arena.is_battler_at_home(target.char_name))
				if target.hp > 0 and still_at_home:
					sword_slash_requested.emit(attacker.char_name, target.char_name)
					_deal_damage(attacker, target, 0.5)
				elif target.hp > 0:
					attack_missed.emit(target.char_name)
			else:
				_deal_damage(attacker, target, 1.0)
		else:
			_deal_damage(attacker, target, 1.0)
	await _wait_for_attack_finish(attacker.char_name)
	_attack_targets.erase(actor_index)
	_reset_actor(actor_index)

func _find_actor_index(stats) -> int:
	for index in range(turn_order.size()):
		if turn_order[index].stats == stats: return index
	return -1

func _deal_damage(attacker,target,mult:float)->void:
	var def_val:float=GameData.get_stat(target, "defense")
	if _defending.get(target.char_name,false):def_val*=2.0
	var dmg:int=max(1,int(GameData.get_stat(attacker, "attack")*mult-def_val*0.5)+randi_range(-3,3))
	if _vulnerable.has(target.char_name):
		dmg = int(ceil(float(dmg) * 1.35))
	target.hp=max(0,target.hp-dmg)
	damage_dealt.emit(target.char_name,dmg,false)
	action_executed.emit("%s 攻击 %s，造成 %d 伤害！"%[attacker.char_name,target.char_name,dmg])
	_interrupt_cast(target)

func _interrupt_cast(target) -> void:
	var target_index := _find_actor_index(target)
	# 只打断行动点之后、法术尚未释放的读条。技能演出已开始时不再取消。
	if target_index < 0 or target_index >= _actor_states.size() or _actor_states[target_index] != ActorState.CASTING:
		return
	_action_gauges[target_index] = 0.0
	_actor_states[target_index] = ActorState.PREPARING
	_cast_speeds.erase(target_index)
	_cast_contexts.erase(target_index)
	cast_interrupted.emit(target.char_name)
	action_executed.emit("%s 的读条被打断，行动条回到起点！" % target.char_name)
	_emit_action_gauges()

func _deal_heal(caster,target,mult:float)->void:
	var amount:int=max(1,int(GameData.get_stat(caster, "attack")*mult*0.6))
	target.hp=min(target.max_hp,target.hp+amount)
	damage_dealt.emit(target.char_name,amount,true)

func _deal_fixed_heal(target, amount: int) -> void:
	target.hp = min(target.max_hp, target.hp + amount)
	damage_dealt.emit(target.char_name, amount, true)

func _execute_skill(actor_index: int, skill, target_idx:int,is_enemy:bool)->void:
	if actor_index < 0 or actor_index >= turn_order.size(): return
	if skill != null and skill.target_type in ["all_enemies", "all_allies"]:
		_do_aoe_skill(actor_index, skill)
		return
	var attacker = turn_order[actor_index].stats
	if skill==null:return
	attacker.mp-=skill.mp_cost
	if attacker.char_name == "李逍遥" and skill.skill_name != "御剑术":
		li_skill_shout_requested.emit()
	if skill.type=="heal":
		var target=combat_party[target_idx] if target_idx<combat_party.size() else attacker
		if skill.skill_name == "气疗术" or skill.skill_name == "灵血咒":
			if attacker.char_name == "李逍遥":
				yujian_magic_cast_requested.emit()
				await get_tree().create_timer(1.0).timeout
			else:
				zhao_magic_cast_requested.emit(target.char_name)
				await get_tree().create_timer(1.92).timeout
			healing_effect_requested.emit(target.char_name)
			await get_tree().create_timer(0.38).timeout
			_deal_fixed_heal(target, int(skill.power))
			await get_tree().create_timer(0.57).timeout
			if attacker.char_name == "李逍遥":
				yujian_magic_cast_finished.emit()
			else:
				zhao_magic_cast_finished.emit()
		else:
			_deal_heal(attacker,target,skill.power)
	else:
		if is_enemy and target_idx<battle_enemies.size():
			var target = battle_enemies[target_idx]
			if skill.skill_name == "御剑术":
				yujian_magic_cast_requested.emit()
				# 12 magic frames at 12 fps; the flying sword starts after the cast pose finishes.
				await get_tree().create_timer(1.0).timeout
				yujian_sword_rain_requested.emit(target.char_name)
				# Rising flight + turn downward in the air, then the falling-sword sequence.
				await get_tree().create_timer(1.85).timeout
				_deal_damage(attacker,target,skill.power)
				await get_tree().create_timer(0.34).timeout
				yujian_magic_cast_finished.emit()
			elif skill.skill_name == "天师符法":
				yujian_magic_cast_requested.emit()
				# The spell begins only after Li Xiaoyao's complete magic animation.
				await get_tree().create_timer(1.0).timeout
				tianshi_fufa_requested.emit(target.char_name)
				# Sigil fade-in + six effect frames + flying sword impact.
				await get_tree().create_timer(1.55).timeout
				_vulnerable[target.char_name] = 2
				yujian_magic_cast_finished.emit()
			elif skill.skill_name == "雷咒":
				zhao_magic_cast_requested.emit(target.char_name)
				# 46 magic frames at 24 fps; its final frame stays on screen during impact.
				await get_tree().create_timer(1.92).timeout
				lightning_strike_requested.emit(target.char_name)
				_deal_damage(attacker,target,skill.power)
				await get_tree().create_timer(0.60).timeout
				zhao_magic_cast_finished.emit()
			elif skill.skill_name == "炎咒" or skill.skill_name == "土咒" or skill.skill_name == "流星火雨":
				zhao_magic_cast_requested.emit(target.char_name)
				# Wait for Zhao Linger's complete non-looping magic animation first.
				await get_tree().create_timer(1.92).timeout
				elemental_spell_requested.emit(skill.skill_name, target.char_name)
				await get_tree().create_timer(1.35 if skill.skill_name == "流星火雨" else 0.42).timeout
				_deal_damage(attacker, target, skill.power)
				await get_tree().create_timer(0.60 if skill.skill_name == "流星火雨" else 0.45).timeout
				zhao_magic_cast_finished.emit()
			else:
				# A skill is never silently shown as a normal attack. Skills without
				# their own visual simply apply their result after a short cast beat.
				await get_tree().create_timer(0.35).timeout
			if skill.skill_name not in ["雷咒", "炎咒", "土咒", "流星火雨", "御剑术", "天师符法"]:
				_deal_damage(attacker,target,skill.power)
	action_executed.emit("%s 使用了 %s！"%[attacker.char_name,skill.skill_name])
	_reset_actor(actor_index)

func _do_aoe_skill(actor_index: int, skill)->void:
	var attacker=turn_order[actor_index].stats
	if skill==null:return
	attacker.mp-=skill.mp_cost
	if skill.type=="heal":
		for m in combat_party:
			if m.hp>0:_deal_heal(attacker,m,skill.power)
	elif skill.skill_name == "风卷残云":
		var target_name: String = battle_enemies[0].char_name if not battle_enemies.is_empty() else ""
		zhao_magic_cast_requested.emit(target_name)
		await get_tree().create_timer(1.92).timeout
		wind_skill_requested.emit(attacker.char_name, target_name)
		await get_tree().create_timer(0.95).timeout # 0.65s travel + 0.3s on contact
		for e in battle_enemies:
			if e.hp>0:_deal_damage(attacker,e,skill.power)
		await get_tree().create_timer(0.12).timeout
		zhao_magic_cast_finished.emit()
	else:
		for e in battle_enemies:
			if e.hp>0:_deal_damage(attacker,e,skill.power)
	action_executed.emit("%s 使用了 %s！"%[attacker.char_name,skill.skill_name])
	_reset_actor(actor_index)

func _use_item_on(target_idx:int)->void:
	if selected_item==null or target_idx>=combat_party.size():return
	var target=combat_party[target_idx]
	match selected_item.effect_type:
		"heal_hp":
			target.hp=min(target.max_hp,target.hp+selected_item.value)
			damage_dealt.emit(target.char_name,selected_item.value,true)
		"heal_mp":
			target.mp=min(target.max_mp,target.mp+selected_item.value)
	selected_item.count-=1
	if selected_item.count<=0:GameData.inventory.erase(selected_item)
	action_executed.emit("使用 %s！"%selected_item.item_name)

func _do_defend()->void:
	var cn:String=turn_order[current_turn].stats.char_name
	_defending[cn]=true
	action_executed.emit("%s 进入防御姿态！"%cn)
	_close_player_menu()
	_reset_actor(current_turn)

func _start_enemy_action(actor_index: int) -> void:
	if actor_index < 0 or actor_index >= turn_order.size() or _actor_states[actor_index] != ActorState.READY:
		return
	var enemy=turn_order[actor_index].stats
	var alive:Array=combat_party.filter(func(p):return p.hp>0)
	if alive.is_empty():_check_end();return
	var target=alive[randi()%alive.size()]
	_run_normal_attack(actor_index, combat_party.find(target), false)

func _wait_for_attack_impact(attacker_name: String, target_name: String) -> void:
	var arena := get_tree().get_first_node_in_group("battle_arena")
	if arena and arena.has_signal("attack_impact_reached"):
		while true:
			var payload: Variant = await arena.attack_impact_reached
			if payload is Array and payload.size() >= 2 and payload[0] == attacker_name and payload[1] == target_name:
				return
	else:
		await get_tree().create_timer(1.15).timeout

func _wait_for_attack_finish(attacker_name: String) -> void:
	var arena := get_tree().get_first_node_in_group("battle_arena")
	if arena and arena.has_signal("attack_animation_finished"):
		while true:
			var payload: Variant = await arena.attack_animation_finished
			var finished_name: String = str(payload[0]) if payload is Array else str(payload)
			if finished_name == attacker_name:
				return
	else:
		await get_tree().create_timer(0.40).timeout

func _reset_actor(actor_index: int)->void:
	if _check_end():return
	# 行动结束后仅该角色回起点，其他人保持自己的准备/读条进度。
	if actor_index >= 0 and actor_index < _action_gauges.size():
		_action_gauges[actor_index] = 0.0
		_actor_states[actor_index] = ActorState.PREPARING
	_cast_speeds.erase(actor_index); _cast_contexts.erase(actor_index); _attack_targets.erase(actor_index)
	if _active_menu_actor < 0: state = BState.WAITING
	_emit_action_gauges()

func _after_action()->void:
	_reset_actor(current_turn)

func _new_round()->void:
	current_turn=0;_defending.clear()
	for target_name in _vulnerable.keys().duplicate():
		_vulnerable[target_name] -= 1
		if _vulnerable[target_name] <= 0:
			_vulnerable.erase(target_name)
	_begin_turn()

func is_vulnerable(target_name: String) -> bool:
	return _vulnerable.has(target_name)

func _check_end()->bool:
	if battle_enemies.all(func(e):return e.hp<=0):
		state=BState.VICTORY;battle_ended.emit(true);return true
	if combat_party.all(func(p):return p.hp<=0):
		state=BState.DEFEAT;battle_ended.emit(false);return true
	return false

func end_battle()->void:
	GameData.current_state=GameData.GameState.EXPLORE
	current_turn=0;turn_order.clear();battle_enemies.clear();combat_party.clear();_defending.clear();_vulnerable.clear();_action_gauges.clear();_actor_states.clear();_ready_party_queue.clear();_cast_speeds.clear();_cast_contexts.clear();_attack_targets.clear();_active_menu_actor=-1;did_escape=false
