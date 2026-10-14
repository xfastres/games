class_name FwHud
extends CanvasLayer

var session: Node
var _gold: Label
var _castle: Label
var _wave: Label
var _status: Label
var _buttons: HBoxContainer


func build(match_node: Node) -> void:
	session = match_node
	layer = 20
	var font := UiFont.make()
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.color = Color(0.07, 0.08, 0.1, 0.94)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 68
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bar)

	_gold = _label(font, Vector2(16, 8))
	_castle = _label(font, Vector2(180, 8))
	_wave = _label(font, Vector2(420, 8))
	_status = _label(font, Vector2(16, 36))
	_status.custom_minimum_size = Vector2(760, 24)
	bar.add_child(_gold)
	bar.add_child(_castle)
	bar.add_child(_wave)
	bar.add_child(_status)

	_buttons = HBoxContainer.new()
	_buttons.position = Vector2(820, 14)
	_buttons.add_theme_constant_override("separation", 8)
	bar.add_child(_buttons)
	for building in session.building_choices():
		var button := Button.new()
		button.text = "%s %d" % [building.display_name, building.cost]
		button.focus_mode = Control.FOCUS_NONE
		var building_id := str(building.id)
		button.pressed.connect(func() -> void: session.select_building(building_id))
		_buttons.add_child(button)
	var start := Button.new()
	start.name = "StartWave"
	start.text = "开始波次"
	start.focus_mode = Control.FOCUS_NONE
	start.pressed.connect(func() -> void: session.start_next_wave())
	_buttons.add_child(start)
	var restart := Button.new()
	restart.text = "重新开始"
	restart.focus_mode = Control.FOCUS_NONE
	restart.pressed.connect(func() -> void: session.restart())
	_buttons.add_child(restart)
	refresh()


func refresh() -> void:
	if session == null or _gold == null:
		return
	_gold.text = session.gold_text()
	_castle.text = session.castle_text()
	_wave.text = session.wave_text()
	_status.text = session.status_text()


func _process(_delta: float) -> void:
	refresh()


func _label(font: Font, position: Vector2) -> Label:
	var label := Label.new()
	label.position = position
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86))
	return label
