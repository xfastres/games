extends Node2D

## Shared placeholder visual. The building id and size come from data, not from this script.

func setup(world_position: Vector2, size_px: Vector2, building_id: String, display_name: String) -> String:
	if size_px.x <= 16.0 or size_px.y <= 16.0:
		return "建筑占位尺寸无效：%s" % size_px
	if building_id.is_empty() or display_name.is_empty():
		return "建筑占位缺少 id 或名称"
	position = world_position
	set_meta("building_id", building_id)
	set_meta("display_name", display_name)

	var visual := Polygon2D.new()
	var margin := 8.0
	visual.polygon = PackedVector2Array([
		Vector2(margin, margin),
		Vector2(size_px.x - margin, margin),
		Vector2(size_px.x - margin, size_px.y - margin),
		Vector2(margin, size_px.y - margin),
	])
	visual.color = Color("8d5a2b")
	add_child(visual)

	var label := Label.new()
	label.text = display_name
	label.position = Vector2(4, size_px.y * 0.5 - 10)
	label.size = Vector2(size_px.x - 8, 20)
	label.clip_text = true
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", UiFont.make())
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("fff6e8"))
	add_child(label)
	add_to_group("placed_building")
	return ""
