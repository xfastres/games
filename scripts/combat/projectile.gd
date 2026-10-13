class_name Projectile
extends Node2D

const ARROW_PATH := "res://assets/sprites/projectiles/arrow_projectile.png"
const IMPACT_PATH := "res://assets/sprites/effects/impact_spark.png"
## 箭尖在贴图里指向左下，约 135 度。Godot 的 0 度指向右。
const ARROW_FORWARD := 2.35619

var target: Node2D
var damage := 0
var speed := 0.0
var active := false
var _sprite: Sprite2D
var _impact_texture: Texture2D


func setup(from_position: Vector2, target_node: Node2D, hit_damage: int, travel_speed: float) -> String:
	if target_node == null or not is_instance_valid(target_node):
		return "投射物没有目标"
	if hit_damage < 1:
		return "投射物伤害无效"
	if travel_speed <= 0.0:
		return "投射物速度无效"
	target = target_node
	damage = hit_damage
	speed = travel_speed
	active = true
	global_position = from_position
	z_index = 4
	texture_filter = TEXTURE_FILTER_NEAREST
	_sprite = _make_arrow()
	var impact: Variant = load(IMPACT_PATH)
	if impact is Texture2D:
		_impact_texture = impact
	else:
		push_error("命中特效无法加载：%s" % IMPACT_PATH)
	add_to_group("defense_projectile")
	face_target()
	queue_redraw()
	return ""


func _physics_process(delta: float) -> void:
	if not active:
		return
	if not is_instance_valid(target) or not bool(target.get("alive")):
		# The target died before impact, so this shot does not deal damage.
		queue_free()
		return
	global_position = global_position.move_toward(target.global_position, speed * delta)
	face_target()
	if global_position.distance_to(target.global_position) > 8.0:
		queue_redraw()
		return
	if target.has_method("apply_damage"):
		var error: String = target.apply_damage(damage)
		if error != "" and error != "目标已经摧毁":
			push_error(error)
		else:
			_spawn_impact()
	else:
		push_error("投射物目标不能受伤")
	queue_free()


func face_target() -> void:
	if _sprite == null or target == null or not is_instance_valid(target):
		return
	var direction := target.global_position - global_position
	if direction.length_squared() < 0.01:
		return
	_sprite.rotation = direction.angle() - ARROW_FORWARD


func _make_arrow() -> Sprite2D:
	var loaded: Variant = load(ARROW_PATH)
	if not (loaded is Texture2D):
		push_error("箭矢图片无法加载：%s" % ARROW_PATH)
		return null
	var sprite := Sprite2D.new()
	sprite.texture = loaded
	sprite.centered = true
	sprite.texture_filter = TEXTURE_FILTER_NEAREST
	var length := maxf(loaded.get_width(), loaded.get_height())
	var scale := 28.0 / length
	sprite.scale = Vector2(scale, scale)
	add_child(sprite)
	return sprite


func _spawn_impact() -> void:
	if _impact_texture == null:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return
	var flash := Sprite2D.new()
	flash.texture = _impact_texture
	flash.centered = true
	flash.texture_filter = TEXTURE_FILTER_NEAREST
	flash.scale = Vector2(0.55, 0.55)
	flash.z_index = 6
	parent_node.add_child(flash)
	flash.global_position = global_position
	var tween := flash.create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.16)
	tween.finished.connect(flash.queue_free)


func _draw() -> void:
	if _sprite != null:
		return
	draw_circle(Vector2.ZERO, 4.0, Color("f0d48a"))
