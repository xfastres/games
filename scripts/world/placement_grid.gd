class_name PlacementGrid
extends RefCounted

var columns: int
var rows: int
var _occupied: Dictionary = {}


func _init(map_columns: int, map_rows: int) -> void:
	columns = map_columns
	rows = map_rows


func occupied_count() -> int:
	return _occupied.size()


func is_occupied(cell: Vector2i) -> bool:
	return _occupied.has(cell)


func occupant(cell: Vector2i) -> String:
	return str(_occupied.get(cell, ""))


func reserve(cell: Vector2i, owner_id: String) -> String:
	if columns < 1 or rows < 1:
		return "无法预留：地图尺寸无效（%d x %d）" % [columns, rows]
	if owner_id.is_empty():
		return "无法预留：占用者 id 为空"
	if not _in_bounds(cell):
		return "无法预留：格子 (%d, %d) 超出地图范围" % [cell.x, cell.y]
	if _occupied.has(cell):
		return "无法预留：格子 (%d, %d) 已被占用" % [cell.x, cell.y]
	_occupied[cell] = owner_id
	return ""


func release(cell: Vector2i) -> String:
	if not _occupied.has(cell):
		return "无法释放：格子 (%d, %d) 没有占用" % [cell.x, cell.y]
	_occupied.erase(cell)
	return ""


func try_place(origin: Vector2i, definition: BuildingDefinition) -> Dictionary:
	if columns < 1 or rows < 1:
		return _fail("无法放置：地图尺寸无效（%d x %d）" % [columns, rows])
	if definition == null:
		return _fail("无法放置：建筑定义为空")
	if definition.footprint_width < 1 or definition.footprint_height < 1:
		return _fail(
			"无法放置：建筑占地无效（%d x %d）"
			% [definition.footprint_width, definition.footprint_height]
		)

	var cells: Array[Vector2i] = []
	for y in definition.footprint_height:
		for x in definition.footprint_width:
			var cell := origin + Vector2i(x, y)
			if not _in_bounds(cell):
				return _fail("无法放置：格子 (%d, %d) 超出地图范围" % [cell.x, cell.y])
			if _occupied.has(cell):
				return _fail("无法放置：格子 (%d, %d) 已被占用" % [cell.x, cell.y])
			cells.append(cell)

	for cell in cells:
		_occupied[cell] = definition.id
	return {"ok": true, "error": "", "cells": cells}


func _in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "cells": []}
