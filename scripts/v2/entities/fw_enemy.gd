class_name FwEnemy
extends CharacterBody2D

## 沿逻辑路径平滑移动。前方间距只影响速度，不写入寻路固体格。
## 中心距离可以短暂降到约 34 像素；低于 22 像素视为重叠失败。
const SLOW_DISTANCE := 48.0
const STOP_DISTANCE := 34.0

var definition: EnemyDefinition
var session: Node
var health: HealthPool
var current_cell := Vector2i.ZERO
var alive := true
var hold := false
var view: FwActorView

var _attack_wait := 0.0
var _hurt_left := 0.0
var _reported := false
var _epoch := -1
var _path: Array[Vector2i] = []
var _path_index := 0
var _travel := ""
var _terminal := ""
var _terminal_cell := Vector2i.ZERO
var _reward_sent := false


func setup(match_node: Node, enemy_definition: EnemyDefinition, cell: Vector2i) -> String:
	if match_node == null or enemy_definition == null:
		return "敌人缺少对局或定义"
	if enemy_definition.max_health < 1 or enemy_definition.move_speed <= 0.0:
		return "敌人定义无效：%s" % enemy_definition.id
	session = match_node
	definition = enemy_definition
	current_cell = cell
	health = HealthPool.new(enemy_definition.max_health)
	if health.init_error != "":
		return health.init_error
	global_position = session.cell_to_world(cell)
	motion_mode = MOTION_MODE_FLOATING
	collision_layer = FwMatch.DETECT_LAYER
	collision_mask = 0
	return ""


func _ready() -> void:
	add_to_group("fw_enemy")
	if definition == null:
		return
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)
	view = FwActorView.new()
	view.name = "View"
	add_child(view)
	var texture := load(definition.sprite_path) as Texture2D
	var view_error := view.setup_static(texture)
	if view_error != "":
		push_error(view_error)
	set_meta("enemy_id", definition.id)


func set_hold(value: bool) -> void:
	hold = value
	if hold:
		velocity = Vector2.ZERO


func is_combat_target() -> bool:
	return alive and not hold


func remaining_cells() -> int:
	return maxi(_path.size() - _path_index, 0)


func apply_damage(amount: int) -> String:
	if not alive or health == null:
		return "目标已经摧毁"
	var error := health.apply_damage(amount)
	if error != "":
		return error
	if health.current == 0:
		if view != null:
			view.set_state("death")
		_die()
		return ""
	if view != null:
		view.set_state("hurt")
	_hurt_left = 0.18
	return ""


func _physics_process(delta: float) -> void:
	if not alive or definition == null or session == null:
		return
	if _hurt_left > 0.0:
		_hurt_left = maxf(_hurt_left - delta, 0.0)
	if hold or not session.combat_enabled():
		velocity = Vector2.ZERO
		move_and_slide()
		_sync_cell()
		_update_view()
		return
	_refresh_path()
	if _travel == "stuck" or _travel.begins_with("attack"):
		velocity = Vector2.ZERO
		move_and_slide()
		if _travel.begins_with("attack"):
			_tick_attack(delta)
		_sync_cell()
		_update_view()
		return
	_advance_waypoint()
	if _travel.begins_with("attack"):
		velocity = Vector2.ZERO
		move_and_slide()
		_tick_attack(delta)
		_sync_cell()
		_update_view()
		return
	var target := _waypoint()
	var offset := target - global_position
	var scale := _crowd_speed_scale()
	if offset.length_squared() < 0.01 or scale <= 0.0:
		velocity = Vector2.ZERO
	else:
		velocity = offset.normalized() * definition.move_speed * scale
	_reject_blocked_step(delta)
	if velocity.length() > definition.move_speed:
		velocity = velocity.normalized() * definition.move_speed
	move_and_slide()
	_sync_cell()
	_update_view()


func _refresh_path() -> void:
	var epoch := int(session.path_epoch())
	if epoch == _epoch:
		return
	var was := _travel
	_epoch = epoch
	var planned: Dictionary = session.plan_from(current_cell)
	if not planned.ok:
		_travel = "stuck"
		velocity = Vector2.ZERO
		if not _reported:
			_reported = true
			session.report_path_error(str(planned.error))
		return
	_reported = false
	_path.clear()
	for cell in planned.path:
		_path.append(cell)
	_path_index = 0
	_terminal = str(planned.terminal)
	_terminal_cell = planned.terminal_cell
	_travel = str(planned.kind)
	if _travel.begins_with("attack") and not was.begins_with("attack"):
		_attack_wait = definition.attack_interval


func _advance_waypoint() -> void:
	var castle_point: Vector2 = session.castle_point()
	var here := global_position.distance_squared_to(castle_point)
	while _path_index < _path.size():
		var center: Vector2 = session.cell_to_world(_path[_path_index])
		var passed := center.distance_squared_to(castle_point) > here + 16.0
		if global_position.distance_to(center) > 5.0 and not passed:
			return
		_path_index += 1
	if _terminal.begins_with("attack"):
		if not _travel.begins_with("attack"):
			_attack_wait = definition.attack_interval
		_travel = _terminal


func _waypoint() -> Vector2:
	if _path_index >= _path.size():
		return global_position
	return session.cell_to_world(_path[_path_index])


func _crowd_speed_scale() -> float:
	var scale := 1.0
	var castle_point: Vector2 = session.castle_point()
	var mine := global_position.distance_squared_to(castle_point)
	for node in get_tree().get_nodes_in_group("fw_enemy"):
		var other := node as FwEnemy
		if other == null or other == self or not other.alive:
			continue
		var distance := global_position.distance_to(other.global_position)
		if distance >= SLOW_DISTANCE:
			continue
		if other.global_position.distance_squared_to(castle_point) >= mine:
			continue
		if distance <= STOP_DISTANCE:
			return 0.0
		scale = minf(scale, (distance - STOP_DISTANCE) / (SLOW_DISTANCE - STOP_DISTANCE))
	return scale


func _reject_blocked_step(delta: float) -> void:
	if velocity == Vector2.ZERO:
		return
	var next: Vector2 = global_position + velocity * delta
	var cell: Variant = session.world_to_cell(next)
	if cell == null:
		velocity = Vector2.ZERO
		return
	var next_cell := cell as Vector2i
	if next_cell != current_cell and session.is_cell_blocked(next_cell):
		velocity = Vector2.ZERO


func _tick_attack(delta: float) -> void:
	_attack_wait -= delta
	if _attack_wait > 0.0:
		return
	_attack_wait = definition.attack_interval
	if _terminal == "attack_castle" or _travel == "attack_castle":
		var error := str(session.apply_castle_damage(definition.contact_damage))
		if error != "":
			push_error(error)
		return
	if _terminal == "attack_blocker" or _travel == "attack_blocker":
		var error := str(session.apply_blocker_damage(_terminal_cell, definition.contact_damage))
		if error != "":
			push_error(error)


func _sync_cell() -> void:
	var cell: Variant = session.world_to_cell(global_position)
	if cell != null:
		current_cell = cell


func _update_view() -> void:
	if view == null:
		return
	if velocity.x < -1.0:
		view.set_facing_left(true)
	elif velocity.x > 1.0:
		view.set_facing_left(false)
	if _hurt_left > 0.0:
		view.set_state("hurt")
	elif _travel.begins_with("attack"):
		view.set_state("attack")
	elif velocity.length() > 5.0:
		view.set_state("walk")
	else:
		view.set_state("idle")


func _die() -> void:
	if _reward_sent:
		return
	_reward_sent = true
	alive = false
	velocity = Vector2.ZERO
	collision_layer = 0
	if session != null:
		session.notify_enemy_died(self)
	queue_free()
