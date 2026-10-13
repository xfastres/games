class_name RangedWeapon
extends Node

var board: Node
var attack_range := 0.0
var attack_interval := 0.0
var attack_damage := 0
var projectile_speed := 0.0
var _size := Vector2.ZERO
var _cooldown := 0.0


func setup(definition: BuildingDefinition, board_node: Node, size_px: Vector2) -> String:
	if definition == null or board_node == null:
		return "远程建筑缺少定义或棋盘"
	if definition.behavior_type != BuildingDefinition.BEHAVIOR_RANGED:
		return "远程组件收到了错误的行为类型：%s" % definition.behavior_type
	if definition.attack_damage < 1:
		return "远程建筑伤害无效"
	if definition.attack_range <= 0.0 or definition.attack_interval <= 0.0 or definition.projectile_speed <= 0.0:
		return "远程建筑的射程、间隔或弹速无效"
	if size_px.x <= 0.0 or size_px.y <= 0.0:
		return "远程建筑尺寸无效"
	board = board_node
	attack_range = definition.attack_range
	attack_interval = definition.attack_interval
	attack_damage = definition.attack_damage
	projectile_speed = definition.projectile_speed
	_size = size_px
	return ""


func _physics_process(delta: float) -> void:
	if board == null or not bool(board.combat_enabled()):
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_cooldown = attack_interval
	_fire(target)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance := attack_range + 1.0
	var origin := _muzzle()
	for node in get_tree().get_nodes_in_group("defense_enemy"):
		if not (node is Node2D) or not bool(node.get("alive")):
			continue
		var unit := node as Node2D
		var distance := origin.distance_to(unit.global_position)
		if distance <= attack_range and distance < best_distance:
			best_distance = distance
			best = unit
	return best


func _fire(target: Node2D) -> void:
	var shot := Projectile.new()
	board.add_child(shot)
	var error := shot.setup(_muzzle(), target, attack_damage, projectile_speed)
	if error != "":
		push_error(error)
		shot.free()


func _muzzle() -> Vector2:
	var parent_node := get_parent() as Node2D
	if parent_node == null:
		return Vector2.ZERO
	return parent_node.global_position + _size * 0.5
