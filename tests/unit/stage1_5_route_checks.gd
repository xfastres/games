extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_open_shortest()
	_test_wall_detour()
	_test_equal_paths()
	_test_blocked_target()
	_test_unreachable()
	_test_enemies_are_not_static_obstacles()
	await _test_wall_destroyed_replans()
	if _failures.is_empty():
		print("STAGE15_ROUTE_PASS")
		quit(0)
		return
	print("STAGE15_ROUTE_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_open_shortest() -> void:
	var goals := {Vector2i(5, 0): true}
	var planned := GridRoute.shortest_to(Vector2i(0, 0), goals, {}, 6, 1)
	_expect(planned.ok, str(planned.error))
	_expect(planned.length == 5, "open length %s" % str(planned.length))
	_expect(_endpoint(planned) == Vector2i(5, 0), "open endpoint %s" % str(_endpoint(planned)))
	_expect(_legal(planned, {}, 6, 1), "open path illegal %s" % str(planned.path))
	var castle := GridRoute.plan(Vector2i(5, 0), [Vector2i(0, 0)], {}, 6, 1)
	_expect(castle.ok and castle.length == 4, "castle approach length %s" % str(castle.length))
	_expect(_endpoint(castle) == Vector2i(1, 0), "approach should stop beside the castle, got %s" % str(_endpoint(castle)))
	_expect(castle.terminal == "attack_castle", "terminal %s" % str(castle.terminal))
	_expect(_legal(castle, {}, 6, 1), "castle path illegal")


func _test_wall_detour() -> void:
	var blocked := {Vector2i(2, 1): true}
	var before := blocked.size()
	var planned := GridRoute.shortest_to(Vector2i(4, 1), {Vector2i(0, 1): true}, blocked, 5, 3)
	_expect(planned.ok, str(planned.error))
	_expect(planned.length == 6, "detour length %s path %s" % [str(planned.length), str(planned.path)])
	_expect(_endpoint(planned) == Vector2i(0, 1), "detour endpoint")
	_expect(_legal(planned, blocked, 5, 3), "detour entered a wall %s" % str(planned.path))
	_expect(not _contains(planned, Vector2i(2, 1)), "path should walk around the wall")
	_expect(blocked.size() == before and not blocked.has(Vector2i(4, 1)), "path search wrote into the blocked map")
	var straight := absi(4 - 0) + absi(1 - 1)
	_expect(planned.length > straight, "wall path should be longer than the blocked line")


func _test_equal_paths() -> void:
	var first := GridRoute.shortest_to(Vector2i(0, 0), {Vector2i(2, 2): true}, {}, 3, 3)
	var second := GridRoute.shortest_to(Vector2i(0, 0), {Vector2i(2, 2): true}, {}, 3, 3)
	var expected: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)
	]
	_expect(first.ok and first.length == 4, "equal path length %s" % str(first.length))
	_expect(_same_path(first, expected), "stable path %s" % str(first.path))
	_expect(_same_path(second, expected), "second search changed the tie break")
	var alternate: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2)
	]
	_expect(alternate.size() - 1 == first.length, "south-edge route is the same length")
	_expect(not _same_path(first, alternate), "tie break should pick one route, not both")


func _test_blocked_target() -> void:
	var blocked := {Vector2i(1, 0): true}
	var far := GridRoute.plan(Vector2i(3, 0), [Vector2i(0, 0)], blocked, 4, 1)
	_expect(far.ok and far.kind == "move" and far.cell == Vector2i(2, 0), "approach blocked target %s" % str(far))
	_expect(far.terminal == "attack_blocker" and far.terminal_cell == Vector2i(1, 0), "terminal blocker %s" % str(far))
	_expect(far.length == 1 and _legal(far, blocked, 4, 1), "blocked approach path %s" % str(far.path))
	var hit := GridRoute.plan(Vector2i(2, 0), [Vector2i(0, 0)], blocked, 4, 1)
	_expect(hit.ok and hit.kind == "attack_blocker" and hit.cell == Vector2i(1, 0), "attack blocked cell %s" % str(hit))
	_expect(hit.length == 0, "already at the wall should not invent a walk")


func _test_unreachable() -> void:
	var outside := GridRoute.plan(Vector2i(1, 1), [Vector2i(9, 9)], {}, 3, 3)
	_expect(not outside.ok and outside.length < 0 and "找不到" in str(outside.error), "unreachable %s" % str(outside))
	var missing := GridRoute.plan(Vector2i(1, 1), [], {}, 3, 3)
	_expect(not missing.ok and "没有可攻击" in str(missing.error), "no castle %s" % str(missing.error))
	var occupied := GridRoute.plan(Vector2i(0, 0), [Vector2i(0, 0)], {}, 3, 3)
	_expect(not occupied.ok and "城堡格子" in str(occupied.error), "start on castle %s" % str(occupied.error))


func _test_enemies_are_not_static_obstacles() -> void:
	var blocked := {}
	var planned := GridRoute.plan(Vector2i(4, 0), [Vector2i(0, 0)], blocked, 5, 1)
	_expect(planned.ok and planned.length == 3, "empty blocked map length %s" % str(planned.length))
	_expect(blocked.is_empty(), "enemy search must not create blocked cells")


func _test_wall_destroyed_replans() -> void:
	var defense := DefenseMatch.new()
	defense.match_path = "res://tests/fixtures/defense/short_match.json"
	root.add_child(defense)
	await process_frame
	if not defense.ready_ok:
		_fail("short match failed to start")
		defense.free()
		return
	var open: Dictionary = defense.route_plan(Vector2i(7, 1))
	_expect(open.ok and open.length == 6, "open match length %s" % str(open.length))
	var epoch := defense.route_epoch()
	defense.select_building_id("base.short_wall")
	var placed: Dictionary = defense.place_at_cell(Vector2i(4, 1))
	_expect(placed.ok, "place wall %s" % str(placed.error))
	_expect(defense.route_epoch() == epoch + 1, "placing a wall should drop the path cache")
	var around: Dictionary = defense.route_plan(Vector2i(7, 1))
	_expect(around.ok and int(around.length) > int(open.length), "wall should force a longer path %s -> %s" % [str(open.length), str(around.length)])
	_expect(_legal(around, {Vector2i(4, 1): true}, defense.columns, defense.rows), "replanned path entered the wall")
	var wall := defense.blocker_at(Vector2i(4, 1))
	if wall == null:
		_fail("wall missing")
		defense.free()
		return
	var broken := str(wall.apply_damage(100))
	_expect(broken == "", "damage wall %s" % broken)
	await process_frame
	var cleared: Dictionary = defense.route_plan(Vector2i(7, 1))
	_expect(cleared.ok and cleared.length == open.length, "destroyed wall should restore length %s" % str(cleared.length))
	_expect(defense.route_epoch() > epoch + 1, "destroying a wall should drop the path cache")
	_expect(defense.blocker_at(Vector2i(4, 1)) == null, "wall should be gone")
	defense.free()


func _endpoint(planned: Dictionary) -> Vector2i:
	var path: Array = planned.path
	if path.is_empty():
		return Vector2i(-999, -999)
	return path[path.size() - 1]


func _contains(planned: Dictionary, cell: Vector2i) -> bool:
	for raw in planned.path:
		if raw == cell:
			return true
	return false


func _same_path(planned: Dictionary, expected: Array[Vector2i]) -> bool:
	var path: Array = planned.path
	if path.size() != expected.size():
		return false
	for index in expected.size():
		if path[index] != expected[index]:
			return false
	return true


func _legal(planned: Dictionary, blocked: Dictionary, columns: int, rows: int) -> bool:
	var path: Array = planned.path
	if path.is_empty() or int(planned.length) != path.size() - 1:
		return false
	for raw in path:
		var cell := raw as Vector2i
		if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
			return false
		if blocked.has(cell):
			return false
	for index in range(1, path.size()):
		var step: Vector2i = path[index] - path[index - 1]
		if absi(step.x) + absi(step.y) != 1:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
