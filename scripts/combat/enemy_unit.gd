class_name EnemyUnit
extends Node2D

const BOARD_METHODS: Array[String] = [
	"query_action",
	"try_begin_step",
	"finish_step",
	"cancel_step",
	"is_path_blocked",
	"cell_center",
	"combat_enabled",
	"apply_castle_damage",
	"blocker_at",
	"notify_enemy_died",
	"route_plan",
	"route_epoch",
	"sync_enemy_cell",
	"world_to_cell",
	"enemies_near",
]
## 局部间距。全局路线由棋盘上的 AStarGrid2D 给出，这里不把别人写进固体格，也不用刚体互撞。
const BODY_GAP := 48.0

var definition: EnemyDefinition
var board: Node
var health: HealthPool
var current_cell := Vector2i.ZERO
var alive := true
var combat_enabled := true
var distance_moved := 0.0
var max_stall := 0.0
var presentation: EnemyPresentation

var _attack_wait := 0.0
var _reported_route_error := false
var _texture: Texture2D
var _mode := ""
var _goal_cell := Vector2i.ZERO
var _attack_cell := Vector2i.ZERO
var _epoch := -1
var _stall := 0.0
var _hurt_left := 0.0
var _facing_left := false
var _velocity := Vector2.ZERO


func setup(board_node: Node, enemy_definition: EnemyDefinition, cell: Vector2i) -> String:
	if board_node == null or enemy_definition == null:
		return "敌人缺少棋盘或定义"
	for method_name in BOARD_METHODS:
		if not board_node.has_method(method_name):
			return "棋盘缺少方法：%s" % method_name
	board = board_node
	definition = enemy_definition
	current_cell = cell
	health = HealthPool.new(enemy_definition.max_health)
	if health.init_error != "":
		return health.init_error
	health.changed.connect(func(_current, _maximum): queue_redraw())
	global_position = board.cell_center(cell)
	z_index = 5
	texture_filter = TEXTURE_FILTER_NEAREST
	_texture = _load_sprite(definition.sprite_path)
	presentation = EnemyPresentation.new()
	presentation.name = "Presentation"
	add_child(presentation)
	set_meta("enemy_id", definition.id)
	_add_label()
	add_to_group("defense_enemy")
	queue_redraw()
	return ""


func set_combat_enabled(enabled: bool) -> void:
	combat_enabled = enabled
	_velocity = Vector2.ZERO
	if enabled:
		_epoch = -1


func apply_damage(amount: int) -> String:
	if not alive:
		return "目标已经摧毁"
	if health == null:
		return "敌人没有生命值"
	var error := health.apply_damage(amount)
	if error != "":
		return error
	if health.current == 0:
		_show_state("death")
		_die()
		return ""
	_show_state("hurt")
	_hurt_left = 0.18
	return ""


func reached_contact() -> bool:
	return alive and (_mode == "attack_castle" or _mode == "attack_blocker")


func _die() -> void:
	if not alive:
		return
	alive = false
	combat_enabled = false
	remove_from_group("defense_enemy")
	var reward := definition.gold_reward
	board.notify_enemy_died(self, reward)
	queue_free()


func _physics_process(delta: float) -> void:
	if not alive or board == null:
		return
	if _hurt_left > 0.0:
		_hurt_left = maxf(_hurt_left - delta, 0.0)
	if not combat_enabled or not bool(board.combat_enabled()):
		_velocity = Vector2.ZERO
		_show_motion()
		return
	var epoch := int(board.route_epoch())
	if epoch != _epoch or _mode == "":
		_epoch = epoch
		_choose_action()
	if _mode == "move":
		_move_along(delta)
	elif _mode == "attack_castle":
		_velocity = Vector2.ZERO
		if _hurt_left <= 0.0:
			_show_state("attack")
		_attack(delta, "castle", Vector2i.ZERO)
	elif _mode == "attack_blocker":
		_velocity = Vector2.ZERO
		if _hurt_left <= 0.0:
			_show_state("attack")
		_attack(delta, "blocker", _attack_cell)
	else:
		_velocity = Vector2.ZERO
		_show_motion()


func _choose_action() -> void:
	var plan: Dictionary = board.route_plan(current_cell)
	if not bool(plan.get("ok", false)):
		_mode = "stuck"
		if not _reported_route_error:
			_reported_route_error = true
			push_error(str(plan.get("error", "敌人寻路失败")))
		return
	_reported_route_error = false
	var kind := str(plan.get("kind", ""))
	if kind == "move":
		_mode = "move"
		_goal_cell = plan.cell
		return
	if kind == "attack_castle" or kind == "attack_blocker":
		_mode = kind
		_attack_cell = plan.cell
		return
	_mode = "stuck"
	if not _reported_route_error:
		_reported_route_error = true
		push_error("未知敌人行动：%s" % kind)


func _move_along(delta: float) -> void:
	if bool(board.is_path_blocked(_goal_cell)):
		_epoch = -1
		return
	var dest: Vector2 = board.cell_center(_goal_cell)
	var to := dest - global_position
	var distance := to.length()
	if distance <= 6.0:
		_arrive()
		return
	var forward := to / distance
	var speed := float(definition.move_speed)
	var blocked_ahead := false
	var push := Vector2.ZERO
	for raw in board.enemies_near(self, BODY_GAP):
		var other := raw as Node2D
		if other == null:
			continue
		var offset: Vector2 = other.global_position - global_position
		var gap := offset.length()
		if gap < 0.01:
			push += Vector2(float(get_instance_id() % 5) - 2.0, 1.0)
			blocked_ahead = true
			continue
		var away := -offset / gap
		if gap < BODY_GAP:
			push += away * (BODY_GAP - gap)
		if _is_ahead(offset, forward):
			var room := clampf((gap - 44.0) / (BODY_GAP - 44.0), 0.0, 1.0)
			speed = minf(speed, float(definition.move_speed) * room)
			if gap < 46.0:
				blocked_ahead = true
	var velocity := forward * speed + push * 2.0
	if velocity.length() > definition.move_speed:
		velocity = velocity.limit_length(definition.move_speed)
	velocity = _limit_ahead(velocity, forward, delta)
	var stepped := _step_unblocked(velocity * delta)
	_velocity = stepped / delta if delta > 0.0 else Vector2.ZERO
	distance_moved += stepped.length()
	if _velocity.length() < 8.0:
		_stall += delta
		max_stall = maxf(max_stall, _stall)
	else:
		_stall = 0.0
	_refresh_logic_cell()
	if blocked_ahead and _stall >= 0.35:
		_sidestep()
	_show_motion()


func _step_unblocked(delta_offset: Vector2) -> Vector2:
	var accepted := Vector2.ZERO
	var options: Array[Vector2] = [delta_offset, Vector2(delta_offset.x, 0.0), Vector2(0.0, delta_offset.y)]
	for part in options:
		if part == Vector2.ZERO:
			continue
		var next: Vector2 = global_position + part
		if _position_blocked(next):
			continue
		global_position = next
		accepted = part
		break
	return accepted


func _position_blocked(world_position: Vector2) -> bool:
	var cell_value: Variant = board.world_to_cell(world_position)
	if cell_value == null:
		return true
	return bool(board.is_path_blocked(cell_value))


func _arrive() -> void:
	global_position = board.cell_center(_goal_cell)
	current_cell = _goal_cell
	board.sync_enemy_cell(self, current_cell)
	_stall = 0.0
	_choose_action()


func _limit_ahead(velocity: Vector2, forward: Vector2, delta: float) -> Vector2:
	if delta <= 0.0:
		return Vector2.ZERO
	var next_pos := global_position + velocity * delta
	for raw in board.enemies_near(self, BODY_GAP):
		var other := raw as Node2D
		if other == null:
			continue
		var toward: Vector2 = other.global_position - global_position
		if not _is_ahead(toward, forward):
			continue
		if next_pos.distance_to(other.global_position) >= 36.0:
			continue
		var direction := toward.normalized()
		var closing := (next_pos - global_position).dot(direction)
		if closing > 0.0:
			next_pos -= direction * closing
	return (next_pos - global_position) / delta


func _is_ahead(offset: Vector2, forward: Vector2) -> bool:
	var along := offset.dot(forward)
	if along <= 8.0:
		return false
	return along * along >= offset.length_squared() * 0.45


func _sidestep() -> void:
	var forward: Vector2 = board.cell_center(_goal_cell) - global_position
	var here_length := _route_length(current_cell)
	var best := current_cell
	var best_length := here_length
	var found := false
	for direction in GridRoute.DIRECTIONS:
		var cell: Vector2i = current_cell + direction
		if cell == _goal_cell or bool(board.is_path_blocked(cell)):
			continue
		if board.world_to_cell(board.cell_center(cell)) == null:
			continue
		if _cell_crowded(cell):
			continue
		if Vector2(direction).dot(forward) < -0.1:
			continue
		var length := _route_length(cell)
		if length > here_length + 1:
			continue
		if not found or length < best_length:
			best_length = length
			best = cell
			found = true
	if not found or best == current_cell:
		return
	_goal_cell = best
	_stall = 0.0


func _route_length(cell: Vector2i) -> int:
	var plan: Dictionary = board.route_plan(cell)
	if not bool(plan.get("ok", false)):
		return 999999
	return int(plan.get("length", 999999))


func _cell_crowded(cell: Vector2i) -> bool:
	var center: Vector2 = board.cell_center(cell)
	for raw in board.enemies_near(self, BODY_GAP):
		var other := raw as Node2D
		if other != null and other.global_position.distance_to(center) < 36.0:
			return true
	return false


func _refresh_logic_cell() -> void:
	var cell_value: Variant = board.world_to_cell(global_position)
	if cell_value == null:
		return
	var cell: Vector2i = cell_value
	if cell == current_cell or bool(board.is_path_blocked(cell)):
		return
	current_cell = cell
	board.sync_enemy_cell(self, cell)


func _attack(delta: float, target_kind: String, cell: Vector2i) -> void:
	_attack_wait -= delta
	if _attack_wait > 0.0:
		return
	var error := ""
	if target_kind == "castle":
		error = str(board.apply_castle_damage(definition.contact_damage))
	else:
		var blocker: Node = board.blocker_at(cell)
		if blocker == null:
			_epoch = -1
			return
		error = str(blocker.apply_damage(definition.contact_damage))
	if error == "目标已经摧毁" or error == "战斗已经结束":
		return
	if error != "":
		push_error(error)
		return
	_attack_wait = definition.attack_interval


func _show_motion() -> void:
	if _hurt_left > 0.0:
		return
	if _velocity.x < -4.0:
		_facing_left = true
	elif _velocity.x > 4.0:
		_facing_left = false
	if presentation != null:
		presentation.set_facing_left(_facing_left)
	if _velocity.length() > 8.0:
		_show_state("walk")
	else:
		_show_state("idle")
	queue_redraw()


func _show_state(next_state: String) -> void:
	if presentation == null:
		return
	var before_health := -1
	var before_wait := _attack_wait
	if health != null:
		before_health = health.current
	presentation.set_state(next_state)
	presentation.set_facing_left(_facing_left)
	if health != null and health.current != before_health:
		push_error("动画状态改变了生命值")
	if not is_equal_approx(_attack_wait, before_wait):
		push_error("动画状态改变了攻击冷却")


func _load_sprite(path: String) -> Texture2D:
	if path == "":
		return null
	var loaded: Variant = load(path)
	if loaded is Texture2D:
		return loaded
	push_error("敌人图片无法加载：%s" % path)
	return null


func _sprite_rect() -> Rect2:
	if presentation == null:
		return Rect2(-16, -30, 32, 48)
	return presentation.sprite_rect(_texture)


func _add_label() -> void:
	var label := Label.new()
	label.text = definition.display_name
	var label_y := -34.0
	if _texture != null:
		label_y = _sprite_rect().position.y - 16.0
	label.position = Vector2(-30, label_y)
	label.size = Vector2(60, 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiFont.make())
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color("ffd0c8"))
	add_child(label)


func _draw() -> void:
	var bar_y := -22.0
	if _texture != null:
		var sprite_rect := _sprite_rect()
		if presentation != null and presentation.facing_left:
			sprite_rect.position.x += sprite_rect.size.x
			sprite_rect.size.x = -sprite_rect.size.x
		draw_texture_rect(_texture, sprite_rect, false)
		bar_y = _bar_y()
	else:
		draw_circle(Vector2.ZERO, 14.0, Color("c44536"))
	var fraction := 1.0
	if health != null and health.maximum > 0:
		fraction = float(health.current) / float(health.maximum)
	draw_rect(Rect2(-16, bar_y, 32, 4), Color(0.15, 0.05, 0.05))
	draw_rect(Rect2(-16, bar_y, 32.0 * clampf(fraction, 0.0, 1.0), 4), Color("f0d48a"))


func _bar_y() -> float:
	if _texture == null or presentation == null:
		return -22.0
	return presentation.sprite_rect(_texture).position.y - 6.0
