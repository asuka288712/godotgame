## 对话系统自动加载单例
extends Node

signal dialogue_line(speaker:String,text:String)
signal dialogue_finished
signal advance_requested(line_index: int)
signal dialogue_line_finished(line_index: int)

var _lines:Array=[]
var _index:int=0
var _active:bool=false
var _advance_locked := false

func start_dialogue(lines:Array)->void:
	if lines.is_empty():return
	_lines=lines;_index=0;_active=true
	GameData.current_state=GameData.GameState.DIALOGUE
	_emit_current()

func advance()->void:
	if not _active:return
	if _advance_locked:
		advance_requested.emit(_index)
		return
	_index+=1
	if _index>=_lines.size():_end_dialogue()
	else:_emit_current()

func set_advance_locked(locked: bool) -> void:
	_advance_locked = locked

func unlock_and_advance() -> void:
	_advance_locked = false
	advance()

func unlock_advance() -> void:
	_advance_locked = false

func notify_line_finished() -> void:
	if _active:
		dialogue_line_finished.emit(_index)

func is_active()->bool:return _active

func _emit_current()->void:
	var line:Dictionary=_lines[_index]
	dialogue_line.emit(line.get("speaker",""),line.get("text",""))

func _end_dialogue()->void:
	_active=false;_lines.clear();_index=0;_advance_locked=false
	GameData.current_state=GameData.GameState.EXPLORE
	dialogue_finished.emit()

# Scene changes discard dialogue without waking old cutscene coroutines.
func reset_dialogue() -> void:
	_active = false
	_lines.clear()
	_index = 0
	_advance_locked = false
