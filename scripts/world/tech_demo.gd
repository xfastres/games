extends Node2D

const VALID_BUILDING_PATH := "res://data/buildings/test_watchpost.json"
const INVALID_SAMPLE_PATH := "res://tests/fixtures/invalid_building_missing_id.json"
const CELL_SIZE := 64
const COLUMNS := 12
const ROWS := 8
const MAP_ORIGIN := Vector2(64, 128)

var grid := PlacementGrid.new(COLUMNS, ROWS)
var definition: BuildingDefinition
var rejection_message := ""
var action_message := "尚未放置建筑。"
var lord: TempLord

var _info_label: Label
var _rejection_label: Label
var _action_label: Label


func _ready() -> void:
	_build_hud()
	var loaded := ContentLoader.load_building(VALID_BUILDING_PATH)
	if not loaded.ok:
		push_error(str(loaded.error))
		action_message = str(loaded.error)
		_refresh_hud()
		return
	definition = loaded.definition
	print("已加载建筑：%s (%s)" % [definition.display_name, definition.id])

	var rejected := ContentLoader.load_building(INVALID_SAMPLE_PATH)
	if rejected.ok:
		rejection_message = "无效配置未被拒绝：%s" % INVALID_SAMPLE_PATH
		push_error(rejection_message)
	else:
		rejection_message = str(rejected.error)
		print("无效配置已拒绝：%s" % rejection_message)

	_spawn_lord()
	_refresh_hud()
	queue_redraw()
	if "--shot" in OS.get_cmdline_user_args():
		_save_preview.call_deferred()


func get_map_rect() -> Rect2:
	return Rect2(MAP_ORIGIN, Vector2(COLUMNS * CELL_SIZE, ROWS * CELL_SIZE))


func world_to_cell(world_position: Vector2) -> Variant:
	var local := world_position - MAP_ORIGIN
	if local.x < 0.0 or local.y < 0.0:
		return null
	var cell := Vector2i(floori(local.x / float(CELL_SIZE)), floori(local.y / float(CELL_SIZE)))
	if cell.x >= COLUMNS or cell.y >= ROWS:
		return null
	return cell


func place_at_world_position(world_position: Vector2) -> Dictionary:
	if definition == null:
		return _reject("无法放置：建筑定义未加载")
	var cell_value: Variant = world_to_cell(world_position)
	if cell_value == null:
		return _reject("无法放置：坐标不在地图网格内")
	var cell := cell_value as Vector2i

	var packed := load(definition.scene_path) as PackedScene
	if packed == null:
		return _reject("无法放置：建筑场景无法加载 %s" % definition.scene_path)
	var marker: Variant = packed.instantiate()
	if not (marker is Node2D) or not marker.has_method("setup"):
		if is_instance_valid(marker):
			marker.free()
		return _reject("无法放置：建筑场景 %s 缺少 setup" % definition.scene_path)

	var size_px := Vector2(definition.footprint_width, definition.footprint_height) * CELL_SIZE
	var setup_error: String = marker.setup(
		MAP_ORIGIN + Vector2(cell) * CELL_SIZE,
		size_px,
		definition.id,
		definition.display_name
	)
	if setup_error != "":
		marker.free()
		return _reject(setup_error)

	var placed: Dictionary = grid.try_place(cell, definition)
	if not placed.ok:
		marker.free()
		return _reject(str(placed.error))
	add_child(marker)
	action_message = "已放置：%s 于格子 (%d, %d)" % [definition.display_name, cell.x, cell.y]
	_refresh_hud()
	return placed


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			place_at_world_position(get_global_mouse_position())
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var map_rect := get_map_rect()
	draw_rect(map_rect, Color("24382a"), true)
	var line_color := Color("6d8a6a")
	var map_end := map_rect.end
	for column in COLUMNS + 1:
		var x := MAP_ORIGIN.x + column * CELL_SIZE
		draw_line(Vector2(x, MAP_ORIGIN.y), Vector2(x, map_end.y), line_color, 1.0)
	for row in ROWS + 1:
		var y := MAP_ORIGIN.y + row * CELL_SIZE
		draw_line(Vector2(MAP_ORIGIN.x, y), Vector2(map_end.x, y), line_color, 1.0)


func _spawn_lord() -> void:
	var packed := load("res://scenes/lord/temp_lord.tscn") as PackedScene
	if packed == null:
		push_error("无法加载临时领主场景 res://scenes/lord/temp_lord.tscn")
		return
	lord = packed.instantiate()
	lord.position = MAP_ORIGIN + Vector2(1.5, 1.5) * CELL_SIZE
	lord.configure(get_map_rect().grow(-18.0))
	add_child(lord)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)

	var panel := ColorRect.new()
	panel.color = Color(0.05, 0.07, 0.08, 0.94)
	panel.position = Vector2.ZERO
	panel.size = Vector2(1280, 116)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(panel)

	var font := UiFont.make()
	_info_label = _make_label(font, Vector2(16, 8), 20, Color("f3f0e6"))
	_rejection_label = _make_label(font, Vector2(16, 36), 16, Color("ffb089"))
	_action_label = _make_label(font, Vector2(16, 60), 16, Color("d7eccf"))
	var help := _make_label(font, Vector2(16, 86), 14, Color("c5d0c0"))
	help.text = "WASD 或方向键移动临时领主。在网格内单击放置建筑；再次单击同一格，或单击网格外，会显示错误。"
	for label in [_info_label, _rejection_label, _action_label, help]:
		layer.add_child(label)
	_refresh_hud()


func _make_label(font: Font, label_position: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = Vector2(1240, font_size + 10)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _refresh_hud() -> void:
	if _info_label == null:
		return
	if definition == null:
		_info_label.text = "建筑定义未加载"
	else:
		_info_label.text = "已加载建筑：%s（%s）" % [definition.display_name, definition.id]
	if rejection_message == "":
		_rejection_label.text = "无效配置样本尚未检查"
	else:
		_rejection_label.text = "无效配置已拒绝：%s" % rejection_message
	_action_label.text = action_message
	var failed := action_message.begins_with("无法")
	_action_label.add_theme_color_override(
		"font_color",
		Color("ff8f8f") if failed else Color("d7eccf")
	)


func _save_preview() -> void:
	var placed := place_at_world_position(get_map_rect().position + Vector2(3 * CELL_SIZE + 4, 3 * CELL_SIZE + 4))
	if not placed.ok:
		push_error(str(placed.error))
		get_tree().quit(1)
		return
	for _frame in 3:
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("无法取得技术验证画面")
		get_tree().quit(1)
		return
	var directory := ProjectSettings.globalize_path("user://")
	var path := directory.path_join("stage0_preview.png")
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("截图保存失败：%s" % error_string(save_error))
		get_tree().quit(1)
		return
	print("STAGE0_SHOT ", path)
	get_tree().quit(0)


func _reject(message: String) -> Dictionary:
	action_message = message
	print(message)
	_refresh_hud()
	return {"ok": false, "error": message, "cells": []}
