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
