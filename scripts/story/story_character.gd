## Reuses the project's character scenes without their original NPC/recruitment logic.
## Tool preview makes existing art visible while editing chapter scenes.
@tool
extends Node3D

@export var character_scene: PackedScene
@export var character_texture: Texture2D
@export_range(0.5, 4.0, 0.05) var character_height := 1.9
var animated: AnimatedSprite3D

func _ready() -> void:
	animated = AnimatedSprite3D.new()
	animated.name = "CharacterArt"
	animated.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	animated.shaded = true
	animated.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	animated.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var frames: SpriteFrames
	if character_scene:
		var source := character_scene.instantiate()
		var sprite := source.get_node_or_null("AnimatedSprite3D") as AnimatedSprite3D
		if sprite: frames = sprite.sprite_frames
		source.free()
	elif character_texture:
		frames = SpriteFrames.new()
		frames.add_animation(&"idle")
		frames.add_frame(&"idle", character_texture)
	if not frames or not frames.has_animation(&"idle") or frames.get_frame_count(&"idle") == 0:
		animated.free()
		return
	animated.sprite_frames = frames
	var texture := frames.get_frame_texture(&"idle", 0)
	var image: Image
	if texture is AtlasTexture:
		# AtlasTexture.get_image() blits before decompressing VRAM imports.
		# Decompress the source first so alpha bounds work in the real renderer.
		image = texture.atlas.get_image()
		if image.is_compressed(): image.decompress()
		image = image.get_region(Rect2i(texture.region))
	else:
		image = texture.get_image()
		if image.is_compressed(): image.decompress()
	var bounds := image.get_used_rect()
	if bounds.size.y <= 0: bounds = Rect2i(Vector2i.ZERO, image.get_size())
	animated.pixel_size = character_height / maxf(bounds.size.y, 1.0)
	animated.position.y = (bounds.end.y - texture.get_height() * 0.5) * animated.pixel_size
	animated.offset.x = texture.get_width() * 0.5 - bounds.get_center().x
	add_child(animated)
	animated.play(&"idle")

func face_motion(motion: Vector3) -> void:
	if not is_instance_valid(animated): return
	var animation: StringName = &"idle"
	if motion.length_squared() > 0.001:
		animation = &"walk" if absf(motion.x) >= absf(motion.z) else (&"walku" if motion.z < 0 else &"walkd")
		if absf(motion.x) > 0.05: animated.flip_h = motion.x < 0
	if animated.sprite_frames.has_animation(animation) and animated.animation != animation:
		animated.play(animation)
