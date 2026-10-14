extends ColorRect

@export var enabled := false

func _ready() -> void:
	# 原生景深负责远近虚化；保留这个节点以便日后需要时可在 Inspector 重新启用调色滤镜。
	visible = enabled and not Engine.is_editor_hint()
