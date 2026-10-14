class_name FwProjectile
extends Node2D

var speed := 700.0
var damage := 1
var target: Node2D
var _hit := false
var _sprite: Sprite2D


func launch(from: Vector2, victim: Node2D, amount: int, projectile_speed: float, texture: Texture2D) -> void:
	global_position = from
	target = victim
	damage = amount
	speed = projectile_speed
	if texture != null:
		_sprite = Sprite2D.new()
		_sprite.texture = texture
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var height := texture.get_height()
		if height > 18.0:
			_sprite.scale = Vector2(18.0 / height, 18.0 / height)
		add_child(_sprite)


func _physics_process(delta: float) -> void:
	if _hit or target == null or not is_instance_valid(target):
		queue_free()
		return
	if target.has_method("is_combat_target") and not target.is_combat_target():
		queue_free()
		return
	var dest := target.global_position + Vector2(0, -16)
	var offset := dest - global_position
	if offset.length_squared() < 0.001:
		_impact()
		return
	if _sprite != null:
		_sprite.rotation = offset.angle()
	var step := speed * delta
	if offset.length() <= step:
		global_position = dest
		_impact()
		return
	global_position += offset.normalized() * step


func _impact() -> void:
	if _hit:
		return
	_hit = true
	if target != null and is_instance_valid(target) and target.has_method("apply_damage"):
		target.apply_damage(damage)
	queue_free()
