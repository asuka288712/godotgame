## Shared low-angle exploration framing. Keep headroom for roofs and trees.
##
## 正交取景框是一块固定大小的斜面：它的下缘必须始终留在地面之上，否则画面底部
## 会直接露出天空（村庄里就是那条一直不消失的蓝色横带）。尺寸越大、俯角越平，
## 下缘就越低，所以取景参数需要满足：
##     FOCUS_OFFSET.y + CAMERA_OFFSET.y >= GROUND_CLEARANCE + VIEW_SIZE * cos(俯角) / 2
## camera_offset() 会按当前参数补足相机高度，以后调整取景参数也不会再次穿帮。
extends RefCounted

# 视野略收窄：平角镜头下视野越大，取景框下缘越低，越容易看到地面以下。
const VIEW_SIZE := 18.0
const FAR_CLIP := 2000.0
# 把取景中心略微推向角色前方，让画面下半区保留更多可走区域。
const FOCUS_OFFSET := Vector3(0, 4.5, 3.0)
# 更平的三分之四角度，接近八方旅人的地图镜头。
const CAMERA_OFFSET := Vector3(0, 5.5, 17.0)
# 取景框下缘与地面之间要求的最小余量，避免底部露出天空。
const GROUND_CLEARANCE := 1.4

static func follow(camera: Camera3D, player: Node3D, weight: float) -> void:
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_SIZE
	camera.far = FAR_CLIP
	var focus := player.global_position + FOCUS_OFFSET
	camera.global_position = camera.global_position.lerp(focus + camera_offset(), clampf(weight, 0, 1))
	camera.look_at(focus, Vector3.UP)

## 在保持俯角与取景中心不变的前提下，把相机抬到足够高，让地面铺满画面下缘。
static func camera_offset() -> Vector3:
	var pitch_cos := CAMERA_OFFSET.z / Vector2(CAMERA_OFFSET.y, CAMERA_OFFSET.z).length()
	var required_height := GROUND_CLEARANCE + VIEW_SIZE * 0.5 * pitch_cos - FOCUS_OFFSET.y
	return Vector3(CAMERA_OFFSET.x, maxf(CAMERA_OFFSET.y, required_height), CAMERA_OFFSET.z)
