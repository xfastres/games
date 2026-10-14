class_name FwPathGrid
extends RefCounted

## 全局四方向最短路。只使用 AStarGrid2D 的格子编号。
## 敌人占格不会传进这里，也不能被写成固体点。
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]

var epoch := 0
var _cache: Dictionary = {}


static func diagonal_mode() -> int:
	return AStarGrid2D.DIAGONAL_MODE_NEVER


func invalidate() -> void:
	epoch += 1
	_cache.clear()


func approach(
	start: Vector2i,
	castle_cells: Array[Vector2i],
	blocked: Dictionary,
	columns: int,
	rows: int
) -> Dictionary:
	var key := "%s|%s|%d|%d" % [start, castle_cells, columns, rows]
	if _cache.has(key):
		return _copy(_cache[key])
	var planned := plan(start, castle_cells, blocked, columns, rows)
	_cache[key] = _copy(planned)
	return _copy(planned)


static func plan(
	start: Vector2i,
	castle_cells: Array[Vector2i],
	blocked: Dictionary,
	columns: int,
	rows: int
) -> Dictionary:
	var before := blocked.size()
	var planned := _plan_uncached(start, castle_cells, blocked, columns, rows)
	if blocked.size() != before:
		return _fail("寻路改写了阻挡表")
	return planned


static func shortest_to(
	start: Vector2i,
	goals: Dictionary,
	blocked: Dictionary,
	columns: int,
	rows: int
) -> Dictionary:
	if not _inside(start, columns, rows):
		return _fail("起点位于地图外 (%d, %d)" % [start.x, start.y])
	if goals.is_empty():
		return _fail("没有可到达的目标")
	var before := blocked.size()
	var path := _shortest(start, goals, blocked, {}, columns, rows, false)
	if blocked.size() != before:
		return _fail("寻路改写了阻挡表")
	if path.is_empty():
		return _fail("找不到通往目标的路线 (%d, %d)" % [start.x, start.y])
	if path.size() == 1:
		return _attack("", start, start)
	return _move(path, "", path[path.size() - 1])


static func _plan_uncached(
	start: Vector2i,
	castle_cells: Array[Vector2i],
	blocked: Dictionary,
	columns: int,
	rows: int
) -> Dictionary:
	if not _inside(start, columns, rows):
		return _fail("敌人位于地图外 (%d, %d)" % [start.x, start.y])
	if castle_cells.is_empty():
		return _fail("城堡没有可攻击的格子")
	var castle := _cell_set(castle_cells)
	if castle.has(start):
		return _fail("敌人出现在城堡格子 (%d, %d)" % [start.x, start.y])
	if _adjacent_to_any(start, castle):
		return _attack("attack_castle", _touching(start, castle), start)

	var goals := {}
	for castle_cell in castle_cells:
		for direction in DIRECTIONS:
			var neighbor: Vector2i = castle_cell + direction
			if castle.has(neighbor) or blocked.has(neighbor) or not _inside(neighbor, columns, rows):
				continue
			goals[neighbor] = true
	if not goals.is_empty():
		var walk := _shortest(start, goals, blocked, castle, columns, rows, false)
		if not walk.is_empty():
			if walk.size() == 1:
				return _attack("attack_castle", _touching(start, castle), start)
			var goal: Vector2i = walk[walk.size() - 1]
			return _move(walk, "attack_castle", _touching(goal, castle))

	var breach := _shortest(start, castle, blocked, {}, columns, rows, true)
	if breach.size() < 2:
		return _fail("找不到通往城堡的路线 (%d, %d)" % [start.x, start.y])
	var walkable: Array[Vector2i] = [breach[0]]
	for index in range(1, breach.size()):
		var step: Vector2i = breach[index]
		if castle.has(step):
			if walkable.size() == 1:
				return _attack("attack_castle", step, start)
			return _move(walkable, "attack_castle", step)
		if blocked.has(step):
			if walkable.size() == 1:
				return _attack("attack_blocker", step, start)
			return _move(walkable, "attack_blocker", step)
		walkable.append(step)
	return _fail("找不到通往城堡的路线 (%d, %d)" % [start.x, start.y])


static func _shortest(
	start: Vector2i,
	goals: Dictionary,
	blocked: Dictionary,
	impassable: Dictionary,
	columns: int,
	rows: int,
	allow_blocked: bool
) -> Array[Vector2i]:
	var grid := _make_grid(columns, rows, blocked, impassable, goals, allow_blocked, start)
	var found := false
	var best := Vector2i(-99999, -99999)
	var best_path: Array[Vector2i] = []
	var best_dist := 999999
	var best_row := 999999
	for raw in goals.keys():
		var goal := raw as Vector2i
		if goal == start:
			var stayed: Array[Vector2i] = [start]
			if _prefer_goal(true, 0, absi(goal.y - start.y), goal, best_dist, best_row, best):
				found = true
				best = goal
				best_path = stayed
				best_dist = 0
				best_row = absi(goal.y - start.y)
			continue
		if not grid.is_in_boundsv(goal) or grid.is_point_solid(goal):
			continue
		var id_path := grid.get_id_path(start, goal)
		if id_path.is_empty():
			continue
		var path := _cells_from_ids(id_path)
		if not _orthogonal(path):
			continue
		var steps := path.size() - 1
		var row_delta := absi(goal.y - start.y)
		if not _prefer_goal(found, steps, row_delta, goal, best_dist, best_row, best):
			continue
		found = true
		best = goal
		best_path = path
		best_dist = steps
		best_row = row_delta
	return best_path


static func _make_grid(
	columns: int,
	rows: int,
	blocked: Dictionary,
	impassable: Dictionary,
	goals: Dictionary,
	allow_blocked: bool,
	start: Vector2i
) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, columns, rows)
	grid.cell_size = Vector2(1, 1)
	grid.offset = Vector2.ZERO
	grid.diagonal_mode = diagonal_mode()
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	for raw in blocked.keys():
		var cell := raw as Vector2i
		if not grid.is_in_boundsv(cell) or impassable.has(cell):
			continue
		if goals.has(cell) or allow_blocked:
			continue
		grid.set_point_solid(cell, true)
	for raw in impassable.keys():
		var cell := raw as Vector2i
		if grid.is_in_boundsv(cell):
			grid.set_point_solid(cell, true)
	if grid.is_in_boundsv(start) and not impassable.has(start):
		grid.set_point_solid(start, false)
	return grid


static func _prefer_goal(
	found: bool,
	steps: int,
	row_delta: int,
	goal: Vector2i,
	best_dist: int,
	best_row: int,
	best: Vector2i
) -> bool:
	if not found or steps < best_dist:
		return true
	if steps == best_dist and row_delta < best_row:
		return true
	if steps == best_dist and row_delta == best_row and (goal.y < best.y or (goal.y == best.y and goal.x < best.x)):
		return true
	return false


static func _orthogonal(path: Array[Vector2i]) -> bool:
	for index in range(1, path.size()):
		var step := path[index] - path[index - 1]
		if absi(step.x) + absi(step.y) != 1:
			return false
	return true


static func _cells_from_ids(id_path: PackedVector2Array) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	path.resize(id_path.size())
	for index in id_path.size():
		var point: Vector2 = id_path[index]
		path[index] = Vector2i(int(point.x), int(point.y))
	return path


static func _cell_set(cells: Array[Vector2i]) -> Dictionary:
	var result := {}
	for cell in cells:
		result[cell] = true
	return result


static func _adjacent_to_any(cell: Vector2i, cells: Dictionary) -> bool:
	for direction in DIRECTIONS:
		if cells.has(cell + direction):
			return true
	return false


static func _touching(cell: Vector2i, cells: Dictionary) -> Vector2i:
	for direction in DIRECTIONS:
		var neighbor: Vector2i = cell + direction
		if cells.has(neighbor):
			return neighbor
	return cell


static func _inside(cell: Vector2i, columns: int, rows: int) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows


static func _move(path: Array[Vector2i], terminal: String, terminal_cell: Vector2i) -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"kind": "move",
		"cell": path[1],
		"path": path,
		"length": path.size() - 1,
		"terminal": terminal,
		"terminal_cell": terminal_cell,
	}


static func _attack(kind: String, cell: Vector2i, start: Vector2i) -> Dictionary:
	var path: Array[Vector2i] = [start]
	return {
		"ok": true,
		"error": "",
		"kind": kind,
		"cell": cell,
		"path": path,
		"length": 0,
		"terminal": kind,
		"terminal_cell": cell,
	}


static func _fail(message: String) -> Dictionary:
	var empty: Array[Vector2i] = []
	return {
		"ok": false,
		"error": message,
		"kind": "",
		"cell": Vector2i.ZERO,
		"path": empty,
		"length": -1,
		"terminal": "",
		"terminal_cell": Vector2i.ZERO,
	}


static func _copy(plan: Dictionary) -> Dictionary:
	var path: Array[Vector2i] = []
	for cell in plan.path:
		path.append(cell)
	return {
		"ok": plan.ok,
		"error": plan.error,
		"kind": plan.kind,
		"cell": plan.cell,
		"path": path,
		"length": plan.length,
		"terminal": plan.terminal,
		"terminal_cell": plan.terminal_cell,
	}
