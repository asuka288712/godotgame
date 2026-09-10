extends ColorRect

func _ready() -> void:
	# 编辑器中隐藏全屏后处理，避免遮挡场景预览；运行时启用滤镜
	visible = not Engine.is_editor_hint()
