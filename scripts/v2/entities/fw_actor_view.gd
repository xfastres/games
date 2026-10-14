class_name FwActorView
extends Node2D

## 没有逐帧素材时保持一张静态图。状态名可以切换，但不会复制同一张图冒充动画。
const EXPECTED_ACTIONS: PackedStringArray = ["idle", "walk", "attack", "hurt", "death"]

var state := "idle"
var uses_frame_animation := false
var missing_actions: PackedStringArray = []
var _sprite: Sprite2D


func setup_static(texture: Texture2D) -> String:
	if texture == null:
		return "角色贴图为空"
	uses_frame_animation = false
	missing_actions = EXPECTED_ACTIONS.duplicate()
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -texture.get_height() * 0.5)
	add_child(_sprite)
	return ""


func set_state(next_state: String) -> void:
	if next_state not in EXPECTED_ACTIONS:
		push_error("未知动作：%s" % next_state)
		return
	state = next_state


func set_facing_left(facing_left: bool) -> void:
	if _sprite == null:
		return
	_sprite.flip_h = facing_left


func foot_local_y() -> float:
	return 0.0
