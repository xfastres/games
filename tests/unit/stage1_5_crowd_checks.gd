extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	print("CROWD_PHYSICS_HZ %d" % Engine.physics_ticks_per_second)
	await _test_static_frames()
	await _test_ten_from_one_spawn()
	await _test_twenty_in_corridor()
	await _test_hold_then_death()
	await _test_wall_opens_for_group()
	await _test_castle_cluster()
	await _test_head_on_cross()
	await _test_junction()
	if _failures.is_empty():
		print("STAGE15_CROWD_PASS")
		quit(0)
		return
	print("STAGE15_CROWD_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_static_frames() -> void:
	var defense := await _open("res://tests/fixtures/defense/crowd_match.json")
	if defense == null:
		return
	var enemy := _spawn(defense, Vector2i(8, 2))
	if enemy == null:
		_close(defense)
		return
	var presentation := enemy.presentation
	_expect(presentation != null and not presentation.uses_frame_animation, "static sprite was reported as a frame animation")
	for action in ["idle", "walk", "attack", "hurt", "death"]:
		_expect(presentation.missing_actions.has(action), "missing action not recorded: %s" % action)
	var texture := load("res://assets/sprites/characters/enemies/goblin.png") as Texture2D
	_expect(texture != null and texture.get_width() == 42 and texture.get_height() == 51, "goblin sheet size")
	var idle_rect := presentation.sprite_rect(texture)
	presentation.set_state("walk")
	var walk_rect := presentation.sprite_rect(texture)
	presentation.set_state("attack")
	var attack_rect := presentation.sprite_rect(texture)
	_expect(idle_rect.position.y == walk_rect.position.y and walk_rect.position.y == attack_rect.position.y, "foot anchor moved between states")
	_expect(is_equal_approx(idle_rect.size.y, EnemyPresentation.DRAW_HEIGHT), "draw height %s" % str(idle_rect.size.y))
	var health_before := enemy.health.current
	enemy._attack_wait = 1.25
	presentation.set_state("hurt")
	_expect(enemy.health.current == health_before, "state change altered health")
	_expect(is_equal_approx(enemy._attack_wait, 1.25), "state change altered attack cooldown")
	_expect(defense._blocked.size() == 1, "spawn wrote an enemy into the blocked map")
	_close(defense)


func _test_ten_from_one_spawn() -> void:
	var defense := await _open("res://tests/fixtures/defense/crowd_match.json")
	if defense == null:
		return
	var started: Dictionary = defense.start_next_wave()
	_expect(started.ok, "start ten %s" % str(started.error))
	var sample := await _simulate(defense, 1200, func() -> bool:
		return defense.alive_enemies == 10 and _contact(defense) >= 3 and _max_cell_x(defense) <= 10
	)
	_report("ten", defense, sample)
	_expect(defense.alive_enemies == 10, "ten alive %d" % defense.alive_enemies)
	_expect(_contact(defense) >= 3, "ten contact %d" % _contact(defense))
	_expect(_max_cell_x(defense) <= 10, "ten still far max_x %d" % _max_cell_x(defense))
	_expect(int(sample.overlap_frames) == 0, "ten overlap frames %s min_gap %s" % [str(sample.overlap_frames), str(sample.min_gap)])
	_expect(float(sample.min_gap) >= 30.0, "ten min gap %s" % str(sample.min_gap))
	_close(defense)


func _test_twenty_in_corridor() -> void:
	var defense := await _open("res://tests/fixtures/defense/crowd_corridor.json")
	if defense == null:
		return
	var spawned := 0
	for x in range(4, 24):
		if _spawn(defense, Vector2i(x, 0)) != null:
			spawned += 1
	_expect(spawned == 20, "spawned %d" % spawned)
	var passed_ids := {}
	var sample := await _simulate(defense, 900, func() -> bool:
		for enemy in _living(defense):
			if enemy.current_cell.x > 1:
				continue
			var id := enemy.get_instance_id()
			if passed_ids.has(id):
				continue
			passed_ids[id] = true
			_park_exited(enemy, passed_ids.size())
		return passed_ids.size() == 20
	)
	_report("corridor20", defense, sample)
	print("CROWD corridor_passed %d" % passed_ids.size())
	_expect(passed_ids.size() == 20, "corridor passed %d still_in_lane %d max_x %d" % [passed_ids.size(), _living(defense).size(), _max_cell_x(defense)])
	_expect(int(sample.overlap_frames) == 0, "corridor overlap frames %s min_gap %s" % [str(sample.overlap_frames), str(sample.min_gap)])
	_expect(float(sample.min_gap) >= 30.0, "corridor min gap %s" % str(sample.min_gap))
	_expect(int(sample.frames) < 900, "corridor did not clear inside the budget")
	_close(defense)


func _test_hold_then_death() -> void:
	var defense := await _open("res://tests/fixtures/defense/crowd_lane.json")
	if defense == null:
		return
	for x in range(6, 11):
		_spawn(defense, Vector2i(x, 0))
	var front := _enemy_on_cell(defense, Vector2i(6, 0))
	if front == null:
		_fail("front enemy missing")
		_close(defense)
		return
	front.set_combat_enabled(false)
	var held := await _simulate(defense, 150, func() -> bool: return false)
	var passed := false
	for enemy in _living(defense):
		if enemy == front:
			continue
		if enemy.global_position.x < front.global_position.x - 8.0:
			passed = true
	_report("hold", defense, held)
	_expect(not passed, "rear enemy passed through the held enemy")
	_expect(float(held.min_gap) >= 30.0, "hold min gap %s" % str(held.min_gap))
	_expect(int(held.overlap_frames) == 0, "hold overlap %s" % str(held.overlap_frames))
	_expect(float(held.max_stall) >= 0.3, "rear should have waited, stall %s" % str(held.max_stall))
	var killed := front.apply_damage(500)
	_expect(killed == "", "kill front %s" % killed)
	var after := await _simulate(defense, 700, func() -> bool:
		return _contact(defense) >= 1 and _max_cell_x(defense) <= 4
	)
	_report("after_death", defense, after)
	_expect(_contact(defense) >= 1, "after death contact %d alive %d" % [_contact(defense), defense.alive_enemies])
	_expect(_max_cell_x(defense) <= 4, "after death the lane is still blocked at x %d" % _max_cell_x(defense))
	_expect(int(after.overlap_frames) == 0, "after death overlap %s" % str(after.overlap_frames))
	_close(defense)


func _test_wall_opens_for_group() -> void:
	var defense := await _open("res://tests/fixtures/defense/crowd_match.json")
	if defense == null:
		return
	defense.select_building_id("base.short_wall")
	var placed: Dictionary = defense.place_at_cell(Vector2i(4, 2))
	_expect(placed.ok, "group wall %s" % str(placed.error))
	for x in range(8, 12):
		_spawn(defense, Vector2i(x, 2))
	var blocked_plan: Dictionary = defense.route_plan(Vector2i(8, 2))
	var epoch := defense.route_epoch()
	await _simulate(defense, 40, func() -> bool: return false)
	var stood_on_wall := false
	for enemy in _living(defense):
		if enemy.current_cell == Vector2i(4, 2):
			stood_on_wall = true
	var wall := defense.blocker_at(Vector2i(4, 2))
	if wall == null:
		_fail("group wall missing")
		_close(defense)
		return
	_expect(wall.apply_damage(100) == "", "could not open the wall")
	await process_frame
	var open_plan: Dictionary = defense.route_plan(Vector2i(8, 2))
	_expect(int(blocked_plan.length) > int(open_plan.length), "opened route was not shorter %s -> %s" % [str(blocked_plan.length), str(open_plan.length)])
	_expect(defense.route_epoch() > epoch, "group did not drop the path cache")
	_expect(not stood_on_wall, "enemy stood on the living wall")
	var sample := await _simulate(defense, 800, func() -> bool:
		return _contact(defense) >= 2 and _max_cell_x(defense) <= 4
	)
	_report("wall_open", defense, sample)
	_expect(_contact(defense) >= 2, "group contact after wall %d" % _contact(defense))
	_expect(_max_cell_x(defense) <= 4, "group still blocked at x %d" % _max_cell_x(defense))
	_expect(int(sample.overlap_frames) == 0, "wall open overlap %s" % str(sample.overlap_frames))
	_close(defense)


func _test_castle_cluster() -> void:
	var defense := await _open("res://tests/fixtures/defense/crowd_match.json")
	if defense == null:
		return
	var spawned := 0
	for y in range(0, 4):
		for x in [2, 3]:
			if _spawn(defense, Vector2i(x, y)) != null:
				spawned += 1
	_expect(spawned == 8, "cluster spawned %d" % spawned)
	var castle_before := defense.castle.health.current
	var sample := await _simulate(defense, 500, func() -> bool:
		return _contact(defense) >= 3 and defense.castle.health.current <= castle_before - 24
	)
	var moved := 0
	for enemy in _living(defense):
		if enemy.distance_moved > 20.0 or enemy.reached_contact():
			moved += 1
	_report("castle", defense, sample)
	_expect(defense.castle.health.current <= castle_before - 24, "castle damage %d" % (castle_before - defense.castle.health.current))
	_expect(_contact(defense) >= 3, "castle contact %d" % _contact(defense))
	_expect(moved == defense.alive_enemies, "some enemies never moved or arrived: %d/%d" % [moved, defense.alive_enemies])
	_expect(int(sample.overlap_frames) == 0, "castle overlap %s min_gap %s" % [str(sample.overlap_frames), str(sample.min_gap)])
	_close(defense)


func _test_head_on_cross() -> void:
	var defense := await _open("res://tests/fixtures/defense/crowd_cross.json")
	if defense == null:
		return
	var left_ids := {}
	var right_ids := {}
	var cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
		Vector2i(11, 1),
		Vector2i(12, 0), Vector2i(13, 0), Vector2i(14, 0),
		Vector2i(12, 1), Vector2i(13, 1), Vector2i(14, 1),
		Vector2i(12, 2), Vector2i(13, 2), Vector2i(14, 2),
	]
	for cell in cells:
		var enemy := _spawn(defense, cell)
		if enemy == null:
			continue
		if cell.x < 7:
			left_ids[enemy.get_instance_id()] = true
		else:
			right_ids[enemy.get_instance_id()] = true
	_expect(left_ids.size() == 10 and right_ids.size() == 10, "head-on spawned %d/%d" % [left_ids.size(), right_ids.size()])
	var castle_before := defense.castle.health.current
	var sample := await _simulate(defense, 900, func() -> bool:
		return _side_arrived(defense, left_ids, true) >= 1 and _side_arrived(defense, right_ids, false) >= 1 and defense.castle.health.current < castle_before
	)
	var on_castle := 0
	for enemy in _living(defense):
		if enemy.current_cell == Vector2i(7, 1):
			on_castle += 1
	_report("head_on", defense, sample)
	print("CROWD head_on_left %d head_on_right %d" % [_side_arrived(defense, left_ids, true), _side_arrived(defense, right_ids, false)])
	_expect(_side_arrived(defense, left_ids, true) >= 1, "left side did not reach the castle")
	_expect(_side_arrived(defense, right_ids, false) >= 1, "right side did not reach the castle")
	_expect(defense.castle.health.current < castle_before, "head-on did not damage the castle")
	_expect(on_castle == 0, "enemy entered the castle cell")
	_expect(int(sample.overlap_frames) == 0, "head-on overlap %s min_gap %s" % [str(sample.overlap_frames), str(sample.min_gap)])
	_expect(float(sample.min_gap) >= 30.0, "head-on min gap %s" % str(sample.min_gap))
	_expect(int(sample.frames) < 900, "head-on did not meet inside the budget")
	_close(defense)


func _test_junction() -> void:
	var defense := await _open("res://tests/fixtures/defense/crowd_junction.json")
	if defense == null:
		return
	var open := {}
	for x in defense.columns:
		for y in [4, 5, 6]:
			open[Vector2i(x, y)] = true
	for y in defense.rows:
		for x in [4, 5, 6]:
			open[Vector2i(x, y)] = true
	for y in defense.rows:
		for x in defense.columns:
			var cell := Vector2i(x, y)
			if open.has(cell) or defense._blocked.has(cell):
				continue
			defense._blocked[cell] = true
	defense._invalidate_routes()
	var north_ids := {}
	var east_ids := {}
	var north_cells: Array[Vector2i] = [
		Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0),
		Vector2i(4, 1), Vector2i(5, 1), Vector2i(6, 1),
		Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2),
	]
	var east_cells: Array[Vector2i] = [
		Vector2i(9, 4), Vector2i(10, 4), Vector2i(11, 4),
		Vector2i(9, 5), Vector2i(10, 5), Vector2i(11, 5),
		Vector2i(9, 6), Vector2i(10, 6), Vector2i(11, 6),
		Vector2i(8, 4), Vector2i(8, 6),
	]
	for cell in north_cells:
		var enemy := _spawn(defense, cell)
		if enemy != null:
			north_ids[enemy.get_instance_id()] = true
	for cell in east_cells:
		var enemy := _spawn(defense, cell)
		if enemy != null:
			east_ids[enemy.get_instance_id()] = true
	_expect(north_ids.size() == 9 and east_ids.size() == 11, "junction spawned %d/%d" % [north_ids.size(), east_ids.size()])
	var sample := await _simulate(defense, 900, func() -> bool:
		return _junction_north(defense, north_ids) >= 2 and _junction_east(defense, east_ids) >= 2 and _contact(defense) >= 1
	)
	var off_road := 0
	for enemy in _living(defense):
		if enemy.current_cell == Vector2i(0, 5) or not open.has(enemy.current_cell):
			off_road += 1
	_report("junction", defense, sample)
	print("CROWD junction_north %d junction_east %d" % [_junction_north(defense, north_ids), _junction_east(defense, east_ids)])
	_expect(_junction_north(defense, north_ids) >= 2, "north stream did not enter the crossing")
	_expect(_junction_east(defense, east_ids) >= 2, "east stream did not pass the crossing")
	_expect(_contact(defense) >= 1, "junction contact %d" % _contact(defense))
	_expect(off_road == 0, "enemy left the open cross")
	_expect(int(sample.overlap_frames) == 0, "junction overlap %s min_gap %s" % [str(sample.overlap_frames), str(sample.min_gap)])
	_expect(float(sample.min_gap) >= 30.0, "junction min gap %s" % str(sample.min_gap))
	_expect(int(sample.frames) < 900, "junction did not clear inside the budget")
	_close(defense)


func _junction_north(defense: DefenseMatch, ids: Dictionary) -> int:
	var count := 0
	for enemy in _living(defense):
		if ids.has(enemy.get_instance_id()) and (enemy.current_cell.y >= 4 or enemy.reached_contact()):
			count += 1
	return count


func _junction_east(defense: DefenseMatch, ids: Dictionary) -> int:
	var count := 0
	for enemy in _living(defense):
		if ids.has(enemy.get_instance_id()) and (enemy.current_cell.x <= 6 or enemy.reached_contact()):
			count += 1
	return count


func _side_arrived(defense: DefenseMatch, ids: Dictionary, from_left: bool) -> int:
	var count := 0
	for enemy in _living(defense):
		if not ids.has(enemy.get_instance_id()):
			continue
		if enemy.reached_contact():
			count += 1
			continue
		if from_left and enemy.current_cell.x >= 6:
			count += 1
		elif not from_left and enemy.current_cell.x <= 8:
			count += 1
	return count


func _simulate(defense: DefenseMatch, budget: int, done: Callable) -> Dictionary:
	var started := Time.get_ticks_msec()
	var overlap_frames := 0
	var min_gap := 10000.0
	var max_stall := 0.0
	var frames := 0
	for _frame in budget:
		await physics_frame
		frames += 1
		var gap := _min_gap(defense)
		if gap < 5000.0:
			min_gap = minf(min_gap, gap)
			if gap < 30.0:
				overlap_frames += 1
		max_stall = maxf(max_stall, _max_stall(defense))
		if bool(done.call()):
			break
	return {
		"frames": frames,
		"overlap_frames": overlap_frames,
		"min_gap": min_gap,
		"max_stall": max_stall,
		"ms": Time.get_ticks_msec() - started,
	}


func _report(label: String, defense: DefenseMatch, sample: Dictionary) -> void:
	print("CROWD case=%s frames=%d ms=%d alive=%d contact=%d passed=%d max_stall=%.2f min_gap=%.1f overlap_frames=%d castle=%d" % [
		label,
		int(sample.frames),
		int(sample.ms),
		defense.alive_enemies,
		_contact(defense),
		_past_column(defense, 3),
		float(sample.max_stall),
		float(sample.min_gap),
		int(sample.overlap_frames),
		defense.castle.health.current,
	])


func _open(path: String) -> DefenseMatch:
	var defense := DefenseMatch.new()
	defense.match_path = path
	root.add_child(defense)
	await process_frame
	if not defense.ready_ok:
		var fatal := defense.find_child("FatalMessage", true, false)
		_fail("defense %s failed: %s" % [path, str(fatal.text) if fatal != null else defense.status_message])
		defense.free()
		return null
	return defense


func _spawn(defense: DefenseMatch, cell: Vector2i) -> EnemyUnit:
	var definition: EnemyDefinition = defense.config.enemies["base.crowd_raider"]
	var enemy := defense._make_enemy(definition, cell)
	return enemy as EnemyUnit


func _park_exited(enemy: EnemyUnit, slot: int) -> void:
	enemy.set_combat_enabled(false)
	enemy.remove_from_group("defense_enemy")
	enemy.global_position = Vector2(-400.0, float(slot) * 48.0)


func _living(defense: DefenseMatch) -> Array[EnemyUnit]:
	var found: Array[EnemyUnit] = []
	for node in get_nodes_in_group("defense_enemy"):
		if node is EnemyUnit and (node as EnemyUnit).get_parent() == defense and (node as EnemyUnit).alive:
			found.append(node)
	return found


func _enemy_on_cell(defense: DefenseMatch, cell: Vector2i) -> EnemyUnit:
	for enemy in _living(defense):
		if enemy.current_cell == cell:
			return enemy
	return null


func _contact(defense: DefenseMatch) -> int:
	var count := 0
	for enemy in _living(defense):
		if enemy.reached_contact():
			count += 1
	return count


func _past_column(defense: DefenseMatch, column: int) -> int:
	var count := 0
	for enemy in _living(defense):
		if enemy.current_cell.x <= column or enemy.reached_contact():
			count += 1
	return count


func _max_cell_x(defense: DefenseMatch) -> int:
	var value := -1
	for enemy in _living(defense):
		value = maxi(value, enemy.current_cell.x)
	return value


func _min_gap(defense: DefenseMatch) -> float:
	var units := _living(defense)
	if units.size() < 2:
		return 10000.0
	var best := 10000.0
	for index in units.size():
		for other in range(index + 1, units.size()):
			best = minf(best, units[index].global_position.distance_to(units[other].global_position))
	return best


func _max_stall(defense: DefenseMatch) -> float:
	var best := 0.0
	for enemy in _living(defense):
		best = maxf(best, enemy.max_stall)
	return best


func _close(node: Node) -> void:
	if current_scene == node:
		current_scene = null
	if is_instance_valid(node):
		node.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
