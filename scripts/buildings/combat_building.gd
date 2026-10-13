extends Node2D

## Visual and components for a combat building. Behavior comes from the definition, not the building name.

var definition: BuildingDefinition
var occupied_cells: Array[Vector2i] = []
var blocker: Blocker
var board: Node
var _size := Vector2.ZERO
var _texture: Texture2D


func setup_combat(
	world_position: Vector2,
	size_px: Vector2,
	building_definition: BuildingDefinition,
	board_node: Node,
	cells: Array[Vector2i]
) -> String:
	if building_definition == null:
		return "战斗建筑定义为空"
	if board_node == null:
		return "战斗建筑缺少棋盘"
	if cells.is_empty():
		return "战斗建筑没有占用格子"
	if size_px.x <= 16.0 or size_px.y <= 16.0:
		return "战斗建筑尺寸无效：%s" % size_px
	if building_definition.behavior_type != BuildingDefinition.BEHAVIOR_BLOCKER \
			and building_definition.behavior_type != BuildingDefinition.BEHAVIOR_RANGED:
		return "未知行为类型：%s" % building_definition.behavior_type

	position = world_position
	_size = size_px
	definition = building_definition
	occupied_cells = cells.duplicate()
	board = board_node
	set_meta("building_id", definition.id)
	set_meta("display_name", definition.display_name)
	z_index = 2
	texture_filter = TEXTURE_FILTER_NEAREST
	_texture = _load_sprite(definition.sprite_path)

	blocker = Blocker.new()
	var blocker_error := blocker.setup(definition.max_health, definition.id)
	if blocker_error != "":
		return blocker_error
	add_child(blocker)
	blocker.destroyed.connect(_on_destroyed)
	blocker.health.changed.connect(func(_current, _maximum): queue_redraw())

	if definition.behavior_type == BuildingDefinition.BEHAVIOR_RANGED:
		var weapon := RangedWeapon.new()
		var weapon_error := weapon.setup(definition, board_node, size_px)
		if weapon_error != "":
			return weapon_error
		add_child(weapon)

	_add_label()
	add_to_group("combat_building")
	queue_redraw()
	return ""


func apply_damage(amount: int) -> String:
	if blocker == null:
		return "建筑不能受伤"
	return blocker.apply_damage(amount)


func _on_destroyed() -> void:
	if board != null and board.has_method("notify_structure_destroyed"):
		board.notify_structure_destroyed(self)


func _load_sprite(path: String) -> Texture2D:
	if path == "":
		return null
	var loaded: Variant = load(path)
	if loaded is Texture2D:
		return loaded
	push_error("建筑图片无法加载：%s" % path)
	return null


func _sprite_rect() -> Rect2:
	var tex_size := _texture.get_size()
	var scale := _size.x / tex_size.x
	var draw_size := tex_size * scale
	return Rect2(Vector2((_size.x - draw_size.x) * 0.5, _size.y - draw_size.y), draw_size)


func _add_label() -> void:
	var label := Label.new()
	label.text = definition.display_name
	var label_y := _size.y - 18.0
	if _texture != null:
		label_y = _sprite_rect().position.y - 26.0
	label.position = Vector2(2, label_y)
	label.size = Vector2(_size.x - 4, 16)
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiFont.make())
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("f7f4ea"))
	add_child(label)


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, _sprite_rect(), false)
	else:
		var color := Color("8b93a0")
		if definition != null and definition.behavior_type == BuildingDefinition.BEHAVIOR_RANGED:
			color = Color("2f6f4e")
		var margin := 7.0
		draw_rect(Rect2(margin, margin, _size.x - margin * 2.0, _size.y - margin * 2.0), color)
		if definition != null and definition.behavior_type == BuildingDefinition.BEHAVIOR_RANGED:
			draw_circle(_size * 0.5, 10.0, Color("d5e6cf"))
	var fraction := 1.0
	if blocker != null and blocker.health != null and blocker.health.maximum > 0:
		fraction = float(blocker.health.current) / float(blocker.health.maximum)
	var bar_y := 6.0
	if _texture != null:
		bar_y = _sprite_rect().position.y - 8.0
	draw_rect(Rect2(6, bar_y, _size.x - 12, 5), Color(0.08, 0.08, 0.08))
	draw_rect(Rect2(6, bar_y, (_size.x - 12) * clampf(fraction, 0.0, 1.0), 5), Color("e06a4f"))
