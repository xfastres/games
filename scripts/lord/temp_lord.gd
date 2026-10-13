class_name TempLord
extends CharacterBody2D

const SPEED := 220.0

var map_bounds := Rect2()
## Non-zero while an automated check is driving the lord. Player input is used otherwise.
var scripted_direction := Vector2.ZERO


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	_ensure_move_actions()


func configure(bounds: Rect2) -> void:
	map_bounds = bounds


func _physics_process(_delta: float) -> void:
	var direction := scripted_direction
	if direction == Vector2.ZERO:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction.limit_length(1.0) * SPEED
	move_and_slide()
	_keep_inside_map()


func _keep_inside_map() -> void:
	if map_bounds.size == Vector2.ZERO:
		return
	global_position.x = clampf(global_position.x, map_bounds.position.x, map_bounds.end.x)
	global_position.y = clampf(global_position.y, map_bounds.position.y, map_bounds.end.y)


func _ensure_move_actions() -> void:
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("move_up", [KEY_W, KEY_UP])
	_bind_keys("move_down", [KEY_S, KEY_DOWN])


func _bind_keys(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
