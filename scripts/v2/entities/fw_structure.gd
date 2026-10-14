class_name FwStructure
extends Node2D

var definition: BuildingDefinition
var origin := Vector2i.ZERO
var cells: Array[Vector2i] = []
var health: HealthPool
var session: Node
var _cooldown := 0.0
var _range: Area2D
var _destroyed := false
var _sprite: Sprite2D


func setup_combat(match_node: Node, building: BuildingDefinition, cell: Vector2i) -> String:
	if match_node == null or building == null:
		return "建筑缺少对局或定义"
	if building.behavior_type != BuildingDefinition.BEHAVIOR_BLOCKER \
			and building.behavior_type != BuildingDefinition.BEHAVIOR_RANGED:
		return "建筑行为不受支持：%s" % building.behavior_type
	session = match_node
	definition = building
	origin = cell
	health = HealthPool.new(building.max_health)
	if health.init_error != "":
		return health.init_error
	for y in building.footprint_height:
		for x in building.footprint_width:
			cells.append(cell + Vector2i(x, y))
	health.depleted.connect(_on_depleted)
	_add_sprite(building.sprite_path)
	if building.behavior_type == BuildingDefinition.BEHAVIOR_RANGED:
		_add_range(building.attack_range)
	return ""


func apply_damage(amount: int) -> String:
	if _destroyed or health == null:
		return "建筑已经摧毁"
	return health.apply_damage(amount)


func _physics_process(delta: float) -> void:
	if _destroyed or definition == null:
		return
	if definition.behavior_type != BuildingDefinition.BEHAVIOR_RANGED:
		return
	if session == null or not session.combat_enabled():
		return
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_cooldown = definition.attack_interval
	_fire(target)


func _nearest_enemy() -> Node:
	if _range == null:
		return null
	var best: Node = null
	var best_distance := definition.attack_range
	for body in _range.get_overlapping_bodies():
		if not body.has_method("is_combat_target") or not body.is_combat_target():
			continue
		var distance := global_position.distance_to(body.global_position)
		if distance > definition.attack_range or distance >= best_distance:
			continue
		best = body
		best_distance = distance
	return best


func _fire(target: Node) -> void:
	var shot := FwProjectile.new()
	shot.name = "Projectile"
	var host: Node = session.projectile_parent()
	host.add_child(shot)
	var texture: Texture2D = null
	if ResourceLoader.exists(FwMatch.ARROW_TEXTURE):
		texture = load(FwMatch.ARROW_TEXTURE)
	shot.launch(global_position + Vector2(0, -28), target, definition.attack_damage, definition.projectile_speed, texture)


func _add_range(radius: float) -> void:
	_range = Area2D.new()
	_range.name = "Range"
	_range.collision_layer = 0
	_range.collision_mask = FwMatch.DETECT_LAYER
	_range.monitorable = false
	_range.monitoring = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	_range.add_child(shape)
	add_child(_range)


func _add_sprite(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("建筑贴图不存在：%s" % path)
		return
	var texture := load(path) as Texture2D
	if texture == null:
		push_error("建筑贴图无法加载：%s" % path)
		return
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.centered = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.position = Vector2(0, -texture.get_height() * 0.5)
	add_child(_sprite)


func _on_depleted() -> void:
	if _destroyed:
		return
	_destroyed = true
	if session != null and session.has_method("notify_structure_destroyed"):
		session.notify_structure_destroyed(self)
