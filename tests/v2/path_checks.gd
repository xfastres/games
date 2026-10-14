extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_open_shortest()
	_test_wall_detour()
	_test_same_endpoints()
	_test_no_diagonal()
	_test_unreachable()
	_test_enemies_are_not_solids()
	_test_wall_removed()
	_test_two_spawns()
	_test_cache_invalidation()
	if _failures.is_empty():
		print("V2_PATH_PASS")
		quit(0)
		return
	print("V2_PATH_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_open_shortest() -> void:
	var planned := FwPathGrid.shortest_to(Vector2i(0, 0), {Vector2i(5, 0): true}, {}, 8, 3)
	_expect(planned.ok, str(planned.error))
	_expect(planned.length == 5, "open length %s path %s" % [str(planned.length), str(planned.path)])
	_expect(_endpoint(planned) == Vector2i(5, 0), "open endpoint %s" % str(_endpoint(planned)))
	_expect(_legal(planned, {}, 8, 3), "open path left the grid")
	var castle := FwPathGrid.plan(Vector2i(5, 0), [Vector2i(0, 0)], {}, 8, 1)
	_expect(castle.ok and castle.length == 4, "castle approach %s" % str(castle.length))
	_expect(_endpoint(castle) == Vector2i(1, 0), "approach endpoint %s" % str(_endpoint(castle)))
	_expect(castle.terminal == "attack_castle" and castle.terminal_cell == Vector2i(0, 0), "castle terminal %s" % str(castle))
	_expect(not _contains(castle, Vector2i(0, 0)), "approach entered the castle")


func _test_wall_detour() -> void:
	var blocked := {Vector2i(2, 1): true}
	var planned := FwPathGrid.shortest_to(Vector2i(4, 1), {Vector2i(0, 1): true}, blocked, 5, 3)
	_expect(planned.ok, str(planned.error))
	_expect(planned.length == 6, "detour length %s path %s" % [str(planned.length), str(planned.path)])
	_expect(_endpoint(planned) == Vector2i(0, 1), "detour endpoint")
	_expect(not _contains(planned, Vector2i(2, 1)), "path entered the wall")
	_expect(planned.length > 4, "detour was not longer than the blocked line")
	_expect(blocked.size() == 1 and blocked.has(Vector2i(2, 1)), "search wrote into the blocked map")


func _test_same_endpoints() -> void:
	var first := FwPathGrid.shortest_to(Vector2i(0, 0), {Vector2i(2, 2): true}, {}, 4, 4)
	var second := FwPathGrid.shortest_to(Vector2i(0, 0), {Vector2i(2, 2): true}, {}, 4, 4)
	_expect(first.ok and first.length == 4, "equal length %s" % str(first.length))
	_expect(_same(first, second), "repeat search changed %s / %s" % [str(first.path), str(second.path)])
	_expect(_orthogonal(first), "equal path was not orthogonal %s" % str(first.path))


func _test_no_diagonal() -> void:
	var planned := FwPathGrid.shortest_to(Vector2i(0, 0), {Vector2i(2, 2): true}, {}, 3, 3)
	_expect(FwPathGrid.diagonal_mode() == AStarGrid2D.DIAGONAL_MODE_NEVER, "diagonal mode")
	_expect(planned.ok and planned.length == 4, "diagonal shortcut length %s path %s" % [str(planned.length), str(planned.path)])
	_expect(_orthogonal(planned), "diagonal step %s" % str(planned.path))


func _test_unreachable() -> void:
	var blocked := {Vector2i(1, 0): true, Vector2i(2, 0): true}
	var planned := FwPathGrid.shortest_to(Vector2i(0, 0), {Vector2i(3, 0): true}, blocked, 4, 1)
	_expect(not planned.ok, "sealed lane was treated as reachable %s" % str(planned.path))
	_expect(str(planned.error).find("找不到") >= 0, "missing unreachable error %s" % str(planned.error))
	var outside := FwPathGrid.plan(Vector2i(-1, 0), [Vector2i(0, 0)], {}, 4, 1)
	_expect(not outside.ok and str(outside.error).find("地图外") >= 0, "outside %s" % str(outside.error))
	var no_castle := FwPathGrid.plan(Vector2i(1, 0), [], {}, 4, 1)
	_expect(not no_castle.ok and str(no_castle.error).find("城堡") >= 0, "no castle %s" % str(no_castle.error))


func _test_enemies_are_not_solids() -> void:
	var blocked := {Vector2i(2, 0): true}
	var planned := FwPathGrid.shortest_to(Vector2i(0, 0), {Vector2i(3, 0): true}, blocked, 4, 2)
	_expect(planned.ok, str(planned.error))
	_expect(_contains(planned, Vector2i(1, 0)) or _contains(planned, Vector2i(0, 1)), "path had no walkable detour %s" % str(planned.path))
	_expect(not _contains(planned, Vector2i(2, 0)), "wall became walkable")
	var through_crowd := FwPathGrid.shortest_to(Vector2i(0, 0), {Vector2i(3, 0): true}, {}, 4, 1)
	_expect(through_crowd.ok and _contains(through_crowd, Vector2i(1, 0)) and _contains(through_crowd, Vector2i(2, 0)), "standing enemies were treated as walls %s" % str(through_crowd.path))


func _test_wall_removed() -> void:
	var blocked := {Vector2i(2, 0): true}
	var before := FwPathGrid.plan(Vector2i(4, 0), [Vector2i(0, 0)], blocked, 5, 3)
	blocked.erase(Vector2i(2, 0))
	var after := FwPathGrid.plan(Vector2i(4, 0), [Vector2i(0, 0)], blocked, 5, 3)
	_expect(before.ok and after.ok, "replan %s / %s" % [str(before.error), str(after.error)])
	_expect(before.terminal == "attack_blocker" or before.length > after.length, "blocked plan did not react %s" % str(before))
	_expect(after.terminal == "attack_castle" and after.length == 3, "open replan length %s path %s" % [str(after.length), str(after.path)])
	_expect(not _contains(after, Vector2i(0, 0)), "replan entered castle")


func _test_two_spawns() -> void:
	var castle: Array[Vector2i] = [Vector2i(0, 3), Vector2i(1, 3), Vector2i(0, 4), Vector2i(1, 4)]
	var north := FwPathGrid.plan(Vector2i(15, 2), castle, {}, 16, 8)
	var south := FwPathGrid.plan(Vector2i(15, 5), castle, {}, 16, 8)
	_expect(north.ok and south.ok, "spawns %s / %s" % [str(north.error), str(south.error)])
	_expect(north.length == 14 and south.length == 14, "spawn lengths %s %s" % [str(north.length), str(south.length)])
	_expect(_touches_castle(_endpoint(north), castle) and _touches_castle(_endpoint(south), castle), "endpoints %s %s" % [str(_endpoint(north)), str(_endpoint(south))])
	for cell in castle:
		_expect(not _contains(north, cell) and not _contains(south, cell), "spawn path entered castle %s" % str(cell))


func _test_cache_invalidation() -> void:
	var paths := FwPathGrid.new()
	var castle: Array[Vector2i] = [Vector2i(0, 0)]
	var blocked := {Vector2i(1, 0): true}
	var first := paths.approach(Vector2i(3, 0), castle, blocked, 4, 1)
	var second := paths.approach(Vector2i(3, 0), castle, {}, 4, 1)
	_expect(_same(first, second), "cache missed before invalidation")
	_expect(first.terminal == "attack_blocker", "cached terminal %s" % str(first.terminal))
	paths.invalidate()
	var third := paths.approach(Vector2i(3, 0), castle, {}, 4, 1)
	_expect(third.terminal == "attack_castle" and third.length == 2, "invalidated path %s" % str(third))
	_expect(paths.epoch == 1, "epoch %s" % str(paths.epoch))


func _endpoint(plan: Dictionary) -> Vector2i:
	var path: Array = plan.path
	return path[path.size() - 1]


func _contains(plan: Dictionary, cell: Vector2i) -> bool:
	for step in plan.path:
		if step == cell:
			return true
	return false


func _same(left: Dictionary, right: Dictionary) -> bool:
	var a: Array = left.path
	var b: Array = right.path
	if a.size() != b.size():
		return false
	for index in a.size():
		if a[index] != b[index]:
			return false
	return true


func _orthogonal(plan: Dictionary) -> bool:
	var path: Array = plan.path
	for index in range(1, path.size()):
		var step: Vector2i = path[index] - path[index - 1]
		if absi(step.x) + absi(step.y) != 1:
			return false
	return true


func _legal(plan: Dictionary, blocked: Dictionary, columns: int, rows: int) -> bool:
	var path: Array = plan.path
	for step in path:
		var cell := step as Vector2i
		if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows or blocked.has(cell):
			return false
	return _orthogonal(plan)


func _touches_castle(cell: Vector2i, castle: Array[Vector2i]) -> bool:
	for castle_cell in castle:
		if absi(cell.x - castle_cell.x) + absi(cell.y - castle_cell.y) == 1:
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
