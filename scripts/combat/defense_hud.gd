class_name DefenseHud
extends Node

var match_node: Node
var _font: Font
var _gold_label: Label
var _castle_label: Label
var _wave_label: Label
var _message_label: Label
var _build_buttons: Dictionary = {}
var _start_button: Button
var _overlay: Control
var _result_title: Label
var _result_detail: Label


func build(board: Node) -> void:
	match_node = board
	_font = UiFont.make()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.07, 0.08, 0.94)
	panel.position = Vector2.ZERO
	panel.size = Vector2(1280, 132)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	_add_icon(layer, Vector2(16, 8), "res://assets/sprites/ui/icons/icon_gold.png")
	_add_icon(layer, Vector2(250, 8), "res://assets/sprites/ui/icons/icon_health.png")
	_gold_label = _make_label(Vector2(46, 8), 22, Color("f3e2a5"), Vector2(190, 28))
	_castle_label = _make_label(Vector2(280, 8), 22, Color("f0c2b2"), Vector2(250, 28))
	_wave_label = _make_label(Vector2(560, 8), 22, Color("d7eccf"), Vector2(280, 28))
	for label in [_gold_label, _castle_label, _wave_label]:
		layer.add_child(label)

	var button_x := 16.0
	var buildings: Array = board.get("config").buildings
	for definition in buildings:
		var button := _make_button("%s（%d 金）" % [definition.display_name, definition.cost], Vector2(button_x, 42), Vector2(188, 32))
		button.name = "Build_" + str(definition.id).replace(".", "_")
		var building_id := str(definition.id)
		button.pressed.connect(_select.bind(building_id))
		_apply_button_icon(button, str(definition.icon_path))
		_build_buttons[building_id] = button
		layer.add_child(button)
		button_x += 196.0

	_start_button = _make_button("开始波次", Vector2(640, 42), Vector2(150, 32))
	_start_button.name = "StartWave"
	_start_button.pressed.connect(func(): match_node.start_next_wave())
	layer.add_child(_start_button)

	var restart := _make_button("重新开始", Vector2(804, 42), Vector2(140, 32))
	restart.name = "Restart"
	restart.pressed.connect(func(): match_node.restart())
	layer.add_child(restart)

	_message_label = _make_label(Vector2(16, 80), 16, Color("d7eccf"), Vector2(1240, 22))
	layer.add_child(_message_label)
	var help := _make_label(Vector2(16, 104), 14, Color("c5d0c0"), Vector2(1240, 22))
	help.text = "左键放置所选建筑，右键取消选择。深红色格子是出兵点。城墙挡住去路；无路可走时敌人会攻击城墙。弓箭塔自动射击。"
	layer.add_child(help)

	_overlay = _build_overlay()
	layer.add_child(_overlay)
	refresh()


func refresh() -> void:
	if match_node == null or _gold_label == null:
		return
	_gold_label.text = str(match_node.gold_text())
	_castle_label.text = str(match_node.castle_text())
	_wave_label.text = str(match_node.wave_text())
	_message_label.text = str(match_node.status_message)
	var failed := str(match_node.status_message).begins_with("无法") \
		or str(match_node.status_message).begins_with("金币不足") \
		or str(match_node.status_message).begins_with("请先")
	_message_label.add_theme_color_override("font_color", Color("ff8f8f") if failed else Color("d7eccf"))
	var selected := str(match_node.selected_id)
	for building_id in _build_buttons.keys():
		var button: Button = _build_buttons[building_id]
		button.modulate = Color(1.25, 1.16, 0.72) if building_id == selected else Color.WHITE
	_start_button.text = str(match_node.start_button_text())
	_start_button.disabled = not bool(match_node.can_start_wave())


func show_outcome(title: String, detail: String) -> void:
	if _overlay == null:
		return
	_overlay.visible = true
	_result_title.text = title
	_result_detail.text = detail


func _select(building_id: String) -> void:
	var error := str(match_node.select_building_id(building_id))
	if error != "":
		push_error(error)


func _build_overlay() -> Control:
	var overlay := Control.new()
	overlay.name = "OutcomeOverlay"
	overlay.visible = false
	overlay.position = Vector2.ZERO
	overlay.size = Vector2(1280, 720)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.04, 0.05, 0.78)
	dim.position = Vector2.ZERO
	dim.size = Vector2(1280, 720)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(dim)

	_result_title = _make_label(Vector2(240, 250), 42, Color("f6f1e4"), Vector2(800, 56))
	_result_title.name = "ResultTitle"
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(_result_title)

	_result_detail = _make_label(Vector2(240, 320), 20, Color("d5ddd0"), Vector2(800, 40))
	_result_detail.name = "ResultDetail"
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay.add_child(_result_detail)

	var restart := _make_button("重新开始", Vector2(520, 390), Vector2(240, 48))
	restart.name = "OutcomeRestart"
	restart.add_theme_font_size_override("font_size", 22)
	restart.pressed.connect(func(): match_node.restart())
	overlay.add_child(restart)
	return overlay


func _add_icon(parent: Node, icon_position: Vector2, path: String) -> void:
	var loaded: Variant = load(path)
	if not (loaded is Texture2D):
		push_error("界面图标无法加载：%s" % path)
		return
	var icon := TextureRect.new()
	icon.texture = loaded
	icon.position = icon_position
	icon.size = Vector2(26, 26)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(icon)


func _apply_button_icon(button: Button, path: String) -> void:
	if path == "":
		return
	var loaded: Variant = load(path)
	if not (loaded is Texture2D):
		push_error("建造按钮图标无法加载：%s" % path)
		return
	button.icon = loaded
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 20)
	button.add_theme_constant_override("icon_max_height", 20)


func _make_label(label_position: Vector2, font_size: int, color: Color, label_size: Vector2) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String, button_position: Vector2, button_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = button_position
	button.size = button_size
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 16)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button
