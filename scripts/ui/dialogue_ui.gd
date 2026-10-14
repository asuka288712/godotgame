## 对话框 UI — 底部半透明面板，打字机效果
extends Control

const PORTRAITS: Dictionary = {
	"洪大夫": preload("res://assets/sprite/npc/dys.png"),
	"药贩": preload("res://assets/sprite/npc/dys.png"),
	"张四": preload("res://assets/sprite/npc/zsg.png"),
	"香兰": preload("res://assets/sprite/npc/Xl.png"),
	"赵灵儿": preload("res://assets/sprite/poratait/Linger_b.png"),
	"李大娘": preload("res://assets/sprite/npc/ldn.png"),
	"赵村长": preload("res://assets/sprite/npc/ldn.png"),
	"药铺老板": preload("res://assets/sprite/npc/zsg.png"),
	"李逍遥": preload("res://assets/Xr.png"),
}

const PORTRAIT_COLORS: Dictionary = {
	"香兰": Color(1.0, 0.76, 0.82),
	"赵灵儿": Color(1.0, 0.76, 0.82),
	"李大娘": Color(0.94, 0.78, 0.48),
	"赵村长": Color(0.94, 0.78, 0.48),
	"药铺老板": Color(0.66, 0.88, 0.62),
	"李逍遥": Color(0.58, 0.76, 1.0),
}

@onready var _bg: ColorRect = $BgPanel
@onready var _name_label: Label = $BgPanel/NameLabel
@onready var _text_label: RichTextLabel = $BgPanel/TextLabel
@onready var _continue_hint: Label = $BgPanel/ContinueHint
@onready var _portrait_frame: ColorRect = $PortraitFrame
@onready var _portrait: TextureRect = $PortraitFrame/Portrait
@onready var _portrait_name: Label = $PortraitFrame/PortraitName

var _full_text: String = ""
var _char_index: int = 0
var _typing: bool = false
var _type_speed: float = 0.04
var _type_timer: float = 0.0
var _line_finish_notified := false
var _fade: Tween
var _hint_tween: Tween
var _font: Font

func _ready() -> void:
	visible = false
	_setup_font()
	DialogueSystem.dialogue_line.connect(_on_dialogue_line)
	DialogueSystem.dialogue_finished.connect(_on_dialogue_finished)

func _setup_font() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["PingFang SC","Noto Sans CJK SC","Microsoft YaHei","SimHei","WenQuanYi Micro Hei","Noto Sans","Arial"])
	_name_label.add_theme_font_override("font", _font)
	_name_label.add_theme_font_size_override("font_size", 22)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	_text_label.add_theme_font_override("normal_font", _font)
	_text_label.add_theme_font_size_override("normal_font_size", 20)
	_text_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.9))
	_continue_hint.add_theme_font_override("font", _font)
	_continue_hint.add_theme_font_size_override("font_size", 18)
	_continue_hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.7, 0.6))
	_portrait_name.add_theme_font_override("font", _font)
	_portrait_name.add_theme_font_size_override("font_size", 18)
	_portrait_name.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))

func _on_dialogue_line(speaker: String, text: String) -> void:
	if _fade: _fade.kill()
	if not visible or modulate.a < 1.0:
		preload("res://scripts/ui/ui_motion.gd").reveal(self, 0.22)
	visible = true
	_name_label.text = speaker
	_update_portrait(speaker)
	_full_text = text
	_char_index = 0
	_typing = true
	_text_label.text = ""
	_continue_hint.visible = false
	_type_timer = 0.0
	_line_finish_notified = false

func _update_portrait(speaker: String) -> void:
	var portrait: Texture2D = PORTRAITS.get(speaker)
	_portrait.texture = portrait
	_portrait_frame.visible = portrait != null
	_portrait_name.text = speaker
	_portrait_name.add_theme_color_override("font_color", PORTRAIT_COLORS.get(speaker, Color(1.0, 0.95, 0.82)))

func _on_dialogue_finished() -> void:
	_typing = false
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 0.0, 0.15)
	_fade.tween_callback(hide)

func _process(delta: float) -> void:
	if not visible: return
	if _typing:
		_type_timer += delta
		while _type_timer >= _type_speed and _char_index < _full_text.length():
			_type_timer -= _type_speed
			_char_index += 1
			_text_label.text = "[color=#FFFFFF]" + _full_text.substr(0, _char_index) + "[/color]"
		if _char_index >= _full_text.length():
			_typing = false
			_continue_hint.visible = true
			_notify_line_finished()

func _input(event: InputEvent) -> void:
	if not visible: return
	if not DialogueSystem.is_active(): return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_or_finish_typing()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if not visible: return
	if not DialogueSystem.is_active(): return
	if event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
		_advance_or_finish_typing()
		get_viewport().set_input_as_handled()

func _advance_or_finish_typing() -> void:
	if _typing:
		_char_index = _full_text.length()
		_text_label.text = "[color=#FFFFFF]" + _full_text + "[/color]"
		_typing = false
		_continue_hint.visible = true
		_notify_line_finished()
	else:
		DialogueSystem.advance()

func _notify_line_finished() -> void:
	if _hint_tween: _hint_tween.kill()
	_hint_tween = create_tween().set_loops()
	_hint_tween.tween_property(_continue_hint, "modulate:a", 0.4, 0.7).set_trans(Tween.TRANS_SINE)
	_hint_tween.tween_property(_continue_hint, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	if _line_finish_notified:
		return
	_line_finish_notified = true
	DialogueSystem.notify_line_finished()
