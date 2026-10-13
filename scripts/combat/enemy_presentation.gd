class_name EnemyPresentation
extends Node

## 移动状态只影响绘制。不保存生命、冷却或路径。
## 当前敌人素材是单张静态图，这里不循环同一帧冒充动画。

signal state_changed(next_state: String)

const ACTIONS: PackedStringArray = ["idle", "walk", "attack", "hurt", "death"]
const FOOT_OFFSET := 18.0
const DRAW_HEIGHT := 48.0

var state := "idle"
var facing_left := false
var uses_frame_animation := false
var missing_actions := ACTIONS.duplicate()


func set_state(next_state: String) -> void:
	if next_state == state:
		return
	if next_state not in ACTIONS:
		push_error("未知敌人动画状态：%s" % next_state)
		return
	state = next_state
	state_changed.emit(state)


func set_facing_left(value: bool) -> void:
	facing_left = value


func sprite_rect(texture: Texture2D) -> Rect2:
	var tex_size := texture.get_size()
	var scale := DRAW_HEIGHT / tex_size.y
	var draw_size := tex_size * scale
	# 脚底固定在 FOOT_OFFSET，换状态也不改锚点，避免走路时上下跳。
	return Rect2(Vector2(-draw_size.x * 0.5, FOOT_OFFSET - draw_size.y), draw_size)
