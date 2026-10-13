class_name GridRoute
extends RefCounted

## 四方向移动，代价为 1。不走对角线，因此不存在切墙角。
## 启发距离用曼哈顿距离。等长路径的取舍是稳定的：
## 先选步数最少的目标，再选与起点横向更齐的目标，最后选更小的 y、x。
## 父节点由广度优先搜索的首次到达决定，邻居顺序是东、西、南、北。
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
static func plan(
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
		return _attack("attack_castle", start, start)

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
				return _attack("attack_castle", start, start)
			return _move(walk, "attack_castle", walk[walk.size() - 1])

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


## 在指定目标集合上求最短路径。goals 的键是 Vector2i。
static func shortest_to(
	start: Vector2i,
	goals: Dictionary,
	blocked: Dictionary,
	columns: int,
	rows: int
) -> Dictionary:
	if not _inside(start, columns, rows):
		return _fail("敌人位于地图外 (%d, %d)" % [start.x, start.y])
	if goals.is_empty():
		return _fail("没有可到达的目标")
	var path := _shortest(start, goals, blocked, {}, columns, rows, false)
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
	allow_blocked: bool
) -> Array[Vector2i]:
	var dist := {start: 0}
	var parent := {}
	var queue: Array[Vector2i] = [start]
	var head := 0
	while head < queue.size():
		var current: Vector2i = queue[head]
		head += 1
		for direction in DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if dist.has(neighbor) or not _inside(neighbor, columns, rows):
				continue
			if impassable.has(neighbor):
				continue
			var entering_blocked := blocked.has(neighbor) and not goals.has(neighbor)
			if entering_blocked and not allow_blocked:
				continue
			dist[neighbor] = int(dist[current]) + 1
			parent[neighbor] = current
			queue.append(neighbor)
	var goal := _pick_goal(start, goals, dist)
	if goal.x == -99999:
		var empty: Array[Vector2i] = []
		return empty
	return _reconstruct(parent, goal)


static func _pick_goal(start: Vector2i, goals: Dictionary, dist: Dictionary) -> Vector2i:
	var found := false
	var best := Vector2i(-99999, -99999)
	var best_dist := 999999
	var best_row := 999999
	for raw in goals.keys():
		var goal := raw as Vector2i
		if not dist.has(goal):
			continue
		var steps := int(dist[goal])
		var row_delta := absi(goal.y - start.y)
		var better := false
		if not found or steps < best_dist:
			better = true
		elif steps == best_dist and row_delta < best_row:
			better = true
		elif steps == best_dist and row_delta == best_row and (goal.y < best.y or (goal.y == best.y and goal.x < best.x)):
			better = true
		if better:
			found = true
			best = goal
			best_dist = steps
			best_row = row_delta
	if not found:
		return Vector2i(-99999, -99999)
	return best


static func _reconstruct(parent: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	var guard := 0
	while parent.has(current) and guard < 512:
		current = parent[current]
		path.append(current)
		guard += 1
	path.reverse()
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
