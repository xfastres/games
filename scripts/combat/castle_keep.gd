class_name CastleKeep
extends Node2D

signal destroyed

const SPRITE_PATH := "res://assets/sprites/buildings/castle.png"

var health: HealthPool
var _size := Vector2.ZERO
var _texture: Texture2D


func setup(world_position: Vector2, size_px: Vector2, max_health: int) -> String:
	if max_health < 1:
		return "城堡生命无效"
	if size_px.x < 16.0 or size_px.y < 16.0:
		return "城堡尺寸无效：%s" % size_px
	position = world_position
	_size = size_px
	health = HealthPool.new(max_health)
	if health.init_error != "":
		return health.init_error
	health.depleted.connect(_on_depleted, CONNECT_ONE_SHOT)
	health.changed.connect(func(_current, _maximum): queue_redraw())
	z_index = 2
	texture_filter = TEXTURE_FILTER_NEAREST
	var loaded: Variant = load(SPRITE_PATH)
	if loaded is Texture2D:
		_texture = loaded
	else:
		push_error("城堡图片无法加载：%s" % SPRITE_PATH)
	_add_label()
	queue_redraw()
	return ""


func apply_damage(amount: int) -> String:
	if health == null:
		return "城堡没有生命值"
	return health.apply_damage(amount)


func _on_depleted() -> void:
	destroyed.emit()


func _add_label() -> void:
	var label := Label.new()
	label.text = "城堡"
	label.position = Vector2(4, -28)
	label.size = Vector2(_size.x - 8, 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiFont.make())
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("fff4d8"))
	add_child(label)


func _draw() -> void:
	if _texture != null:
		var tex_size := _texture.get_size()
		var scale := _size.x / tex_size.x
		var draw_size := tex_size * scale
		var origin := Vector2((_size.x - draw_size.x) * 0.5, _size.y - draw_size.y)
		draw_texture_rect(_texture, Rect2(origin, draw_size), false)
	else:
		draw_rect(Rect2(Vector2.ZERO, _size), Color("6e522c"))
		draw_rect(Rect2(8, 8, _size.x - 16, _size.y - 16), Color("8d6a3a"))
	var fraction := 1.0
	if health != null and health.maximum > 0:
		fraction = float(health.current) / float(health.maximum)
	var bar_y := 8.0
	if _texture != null:
		var tex_size := _texture.get_size()
		var scale := _size.x / tex_size.x
		bar_y = _size.y - tex_size.y * scale - 10.0
	draw_rect(Rect2(8, bar_y, _size.x - 16, 6), Color(0.12, 0.08, 0.05))
	draw_rect(Rect2(8, bar_y, (_size.x - 16) * clampf(fraction, 0.0, 1.0), 6), Color("d24b3a"))
