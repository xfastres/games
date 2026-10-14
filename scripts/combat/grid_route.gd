class_name GridRoute
extends RefCounted

## 四方向网格最短路。步数由 AStarGrid2D 计算，敌人不会被写进固体格。
## 攻击城堡、攻击阻挡和无路时的错误仍由本文件决定。
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(-1, 0),
	Vector2i(0, 1),
	Vector2i(0, -1),
]


## 给战斗用的下一步。路径细节在 plan()。
static func choose(
	start: Vector2i,
	castle_cells: Array[Vector2i],
	blocked: Dictionary,
	columns: int,
	rows: int
) -> Dictionary:
	var planned := plan(start, castle_cells, blocked, columns, rows)
	return {
		"ok": planned.ok,
		"error": planned.error,
		"kind": planned.kind,
		"cell": planned.cell,
	}


## 返回从起点到城堡的最短可走路径。走不到时 ok 为 false，并带明确错误。
## path 只含可走格子，不含要攻击的墙或城堡。length 是步数，不是数组长度。
## cell_size 只写入 AStarGrid2D 的格子像素配置。搜索使用格子编号，不使用世界坐标。
static func plan(
	start: Vector2i,
	castle_cells: Array[Vector2i],
	blocked: Dictionary,
	columns: int,
	rows: int,
	cell_size: int = 1
) -> Dictionary:
	if not _inside(start, columns, rows):
		return _fail("敌人位于地图外 (%d, %d)" % [start.x, start.y])
	if castle_cells.is_empty():
		return _fail("城堡没有可攻击的格子")
	var castle := _cell_set(castle_cells)
	if castle.has(start):
		return _fail("敌人出现在城堡格子 (%d, %d)" % [start.x, start.y])
	if _adjacent_to_any(start, castle):
		return _attack("attack_castle", start, start)

	var goals := {}
	for castle_cell in castle_cells:
		for direction in DIRECTIONS:
			var neighbor: Vector2i = castle_cell + direction
			if castle.has(neighbor) or blocked.has(neighbor) or not _inside(neighbor, columns, rows):
				continue
			goals[neighbor] = true
	if not goals.is_empty():
		var walk := _shortest(start, goals, blocked, castle, columns, rows, false, cell_size)
		if not walk.is_empty():
			if walk.size() == 1:
				return _attack("attack_castle", start, start)
			return _move(walk, "attack_castle", walk[walk.size() - 1])

	var breach := _shortest(start, castle, blocked, {}, columns, rows, true, cell_size)
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


## 在指定目标集合上求最短路径。goals 的键是 Vector2i。
static func shortest_to(
	start: Vector2i,
	goals: Dictionary,
	blocked: Dictionary,
	columns: int,
	rows: int,
	cell_size: int = 1
) -> Dictionary:
	if not _inside(start, columns, rows):
		return _fail("敌人位于地图外 (%d, %d)" % [start.x, start.y])
	if goals.is_empty():
		return _fail("没有可到达的目标")
	var path := _shortest(start, goals, blocked, {}, columns, rows, false, cell_size)
	if path.is_empty():
		return _fail("找不到通往目标的路线 (%d, %d)" % [start.x, start.y])
	if path.size() == 1:
		return _attack("", start, start)
	return _move(path, "", path[path.size() - 1])


static func _shortest(
	start: Vector2i,
	goals: Dictionary,
	blocked: Dictionary,
	impassable: Dictionary,
	columns: int,
	rows: int,
	allow_blocked: bool,
	cell_size: int
) -> Array[Vector2i]:
	var grid := _make_grid(columns, rows, blocked, impassable, goals, allow_blocked, start, cell_size)
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


## 区域、格子像素和固体格都设在这一张网格上。调用方传入的 blocked 不会被修改。
static func _make_grid(
	columns: int,
	rows: int,
	blocked: Dictionary,
	impassable: Dictionary,
	goals: Dictionary,
	allow_blocked: bool,
	start: Vector2i,
	cell_size: int
) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, columns, rows)
	var pixels := maxi(cell_size, 1)
	grid.cell_size = Vector2(pixels, pixels)
	grid.offset = Vector2.ZERO
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
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
