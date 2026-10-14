class_name FwLogicMap
extends RefCounted

## 逻辑格子的通行状态。只记录城堡和建筑，不记录正在路过的敌人。
var columns: int
var rows: int
var _blocked: Dictionary = {}


func _init(map_columns: int, map_rows: int) -> void:
	columns = map_columns
	rows = map_rows


func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


func set_blocked(cell: Vector2i, blocked: bool) -> String:
	if not inside(cell):
		return "阻挡超出地图 (%d, %d)" % [cell.x, cell.y]
	if blocked:
		_blocked[cell] = true
	else:
		_blocked.erase(cell)
	return ""


func is_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func blocked_cells() -> Dictionary:
	return _blocked.duplicate()


func blocked_count() -> int:
	return _blocked.size()
