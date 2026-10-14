extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	print("V2_CROWD_PHYSICS_HZ %d" % Engine.physics_ticks_per_second)
	await _test_twenty_move()
	await _test_front_stops_then_dies()
	await _test_wall_opens()
	if _failures.is_empty():
		print("V2_CROWD_PASS")
		quit(0)
		return
	print("V2_CROWD_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_twenty_move() -> void:
	var session := await _open()
	if session == null:
		return
	var spawned := 0
	for x in range(4, 24):
		if session.spawn_enemy_at(Vector2i(x, 0), "base.raider") == "":
			spawned += 1
	_expect(spawned == 20, "spawned %d" % spawned)
	var start_sum := _sum_x(session)
	var sample := await _simulate(session, 240, func() -> bool: return false)
	var moved := start_sum - _sum_x(session)
	print("V2_CROWD_TWENTY min_gap=%s overlap=%s max_step=%s moved=%s frames=%s alive=%d" % [
		str(sample.min_gap), str(sample.overlap_frames), str(sample.max_step), str(moved), str(sample.frames), session.living_enemies().size()
	])
	_expect(session.living_enemies().size() == 20, "alive %d" % session.living_enemies().size())
	_expect(moved > 8.0, "queue did not advance %s" % str(moved))
	_expect(int(sample.overlap_frames) == 0, "overlap frames %s min_gap %s" % [str(sample.overlap_frames), str(sample.min_gap)])
	_expect(float(sample.min_gap) >= 30.0, "min gap %s" % str(sample.min_gap))
	_expect(float(sample.max_step) < 8.0, "step too large %s" % str(sample.max_step))
	_expect(session.blocked_count() == 1, "enemies were written into the blocked map")
	session.free()


func _test_front_stops_then_dies() -> void:
	var session := await _open()
	if session == null:
		return
	for x in range(6, 10):
		session.spawn_enemy_at(Vector2i(x, 0), "base.raider")
	await _simulate(session, 5, func() -> bool: return false)
	var front := _enemy_at(session, 6)
	if front == null:
		_fail("front enemy missing")
		session.free()
		return
	front.set_hold(true)
	var held_x := front.current_cell.x
	var held := await _simulate(session, 90, func() -> bool: return false)
	var behind := _eastern_neighbors(session, front)
	print("V2_CROWD_HOLD min_gap=%s front_x=%s" % [str(held.min_gap), str(front.current_cell.x)])
	_expect(front.current_cell.x == held_x, "held enemy moved")
	_expect(behind, "rear enemy passed the held front")
	_expect(float(held.min_gap) >= 30.0, "hold gap %s" % str(held.min_gap))
	var rear_before := _sum_x(session)
	front.apply_damage(front.health.current)
	var resumed := await _simulate(session, 180, func() -> bool:
		return _sum_x(session) < rear_before - 0.5
	)
	print("V2_CROWD_RESUME frames=%s sum=%s" % [str(resumed.frames), str(_sum_x(session))])
	_expect(_sum_x(session) < rear_before - 0.5, "rear did not advance after the front died")
	_expect(int(resumed.overlap_frames) == 0, "resume overlap %s" % str(resumed.overlap_frames))
	session.free()


func _test_wall_opens() -> void:
	var session := await _open()
	if session == null:
		return
	session.select_building("base.wall")
	var placed: Dictionary = session.place_at_cell(Vector2i(6, 0))
	_expect(placed.ok, str(placed.error))
	for x in range(8, 11):
		session.spawn_enemy_at(Vector2i(x, 0), "base.raider")
	var structure: FwStructure = session._structures[Vector2i(6, 0)]
	var health_before := structure.health.current
	var opened := await _simulate(session, 1400, func() -> bool:
		return not session.is_cell_blocked(Vector2i(6, 0)) and _min_x(session) < 6
	)
	print("V2_CROWD_WALL frames=%s min_x=%s blocked=%s" % [str(opened.frames), str(_min_x(session)), str(session.is_cell_blocked(Vector2i(6, 0)))])
	_expect(health_before == 100, "wall health %d" % health_before)
	_expect(not session.is_cell_blocked(Vector2i(6, 0)), "wall remained blocked")
	_expect(_min_x(session) < 6, "enemies did not pass the demolished wall, min_x %s" % str(_min_x(session)))
	_expect(int(opened.overlap_frames) == 0, "wall overlap %s min_gap %s" % [str(opened.overlap_frames), str(opened.min_gap)])
	session.free()


func _open() -> FwMatch:
	var session := FwMatch.new()
	session.match_path = "res://data/v2/corridor_match.json"
	root.add_child(session)
	await process_frame
	if not session.ready_ok:
		_fail(session.status_message)
		session.free()
		return null
	return session


func _simulate(session: FwMatch, budget: int, done: Callable) -> Dictionary:
	var overlap_frames := 0
	var min_gap := 10000.0
	var max_step := 0.0
	var frames := 0
	var previous := {}
	for _frame in budget:
		await physics_frame
		frames += 1
		var gap := _min_gap(session)
		if gap < 5000.0:
			min_gap = minf(min_gap, gap)
			if gap < 22.0:
				overlap_frames += 1
		for enemy in session.living_enemies():
			var id := enemy.get_instance_id()
			if previous.has(id):
				max_step = maxf(max_step, enemy.global_position.distance_to(previous[id]))
			previous[id] = enemy.global_position
		if bool(done.call()):
			break
	return {
		"frames": frames,
		"overlap_frames": overlap_frames,
		"min_gap": min_gap,
		"max_step": max_step,
	}


func _sum_x(session: FwMatch) -> float:
	var total := 0.0
	for enemy in session.living_enemies():
		total += enemy.global_position.x
	return total


func _min_x(session: FwMatch) -> int:
	var best := 99
	for enemy in session.living_enemies():
		best = mini(best, enemy.current_cell.x)
	return best


func _min_gap(session: FwMatch) -> float:
	var enemies := session.living_enemies()
	var best := 10000.0
	for index in enemies.size():
		for other in range(index + 1, enemies.size()):
			best = minf(best, enemies[index].global_position.distance_to(enemies[other].global_position))
	return best


func _enemy_at(session: FwMatch, x: int) -> FwEnemy:
	for enemy in session.living_enemies():
		if enemy.current_cell.x == x:
			return enemy
	return null


func _eastern_neighbors(session: FwMatch, front: FwEnemy) -> bool:
	var found := false
	for enemy in session.living_enemies():
		if enemy == front:
			continue
		found = true
		if enemy.global_position.x < front.global_position.x - 8.0:
			return false
	return found


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	_failures.append(message)
