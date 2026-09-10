## 探索 HUD — 显示队伍基本状态和提示信息
extends Control

@onready var _party_panel: VBoxContainer = $PartyPanel
@onready var _hint_label: Label = $HintLabel
@onready var _battle_overlay: ColorRect = $BattleOverlay

var _font: Font
var _party_labels: Array = []

func _ready() -> void:
	_setup_font()
	BattleSystem.battle_started.connect(_on_battle_started)
	BattleSystem.battle_ended.connect(_on_battle_ended)
	# 动态创建队伍标签
	for p in GameData.party:
		var lbl := Label.new()
		lbl.text = "%s  HP:%d/%d  MP:%d/%d" % [p.char_name, p.hp, p.max_hp, p.mp, p.max_mp]
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.85, 1, 0.85))
		_party_panel.add_child(lbl)
		_party_labels.append(lbl)
	_hint_label.add_theme_font_override("font", _font)
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.8, 0.7))

func _setup_font() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["PingFang SC","Noto Sans CJK SC","Microsoft YaHei","SimHei","WenQuanYi Micro Hei","Noto Sans","Arial"])

func _process(_delta: float) -> void:
	if GameData.current_state == GameData.GameState.EXPLORE:
		visible = true
		# Party HP/MP belongs to the battle UI. Keep the exploration HUD limited
		# to movement hints so the top-left corner stays clear outside combat.
		_party_panel.visible = false
	else:
		visible = false

func _update_party_display() -> void:
	for i in range(min(GameData.party.size(), _party_labels.size())):
		var p = GameData.party[i]
		_party_labels[i].text = "%s  HP:%d/%d  MP:%d/%d" % [p.char_name, p.hp, p.max_hp, p.mp, p.max_mp]

func _on_battle_started(_enemies: Array) -> void:
	var tw := create_tween()
	tw.tween_property(_battle_overlay, "color:a", 1.0, 0.3)
	tw.tween_property(_battle_overlay, "color:a", 0.0, 0.3)

func _on_battle_ended(_victory: bool) -> void:
	pass
