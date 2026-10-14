class_name FwCastle
extends Node2D

signal destroyed

var health: HealthPool
var cells: Array[Vector2i] = []
var _sprite: Sprite2D


func setup(max_health: int, footprint: Array[Vector2i], texture: Texture2D) -> String:
	if footprint.is_empty():
		return "城堡没有占格"
	health = HealthPool.new(max_health)
	if health.init_error != "":
		return health.init_error
	cells = footprint.duplicate()
	health.depleted.connect(_on_depleted)
	if texture != null:
		_sprite = Sprite2D.new()
		_sprite.texture = texture
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_sprite.position = Vector2(0, -texture.get_height() * 0.5)
		add_child(_sprite)
	return ""


func _on_depleted() -> void:
	destroyed.emit()
