extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	await _test_rules_gold_and_restart()
	await _test_defeat()
	await _test_victory_and_three_waves()
	if _failures.is_empty():
		print("V2_COMBAT_PASS")
		quit(0)
		return
	print("V2_COMBAT_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_rules_gold_and_restart() -> void:
	var session := await _open("res://data/v2/prototype_match.json")
	if session == null:
		return
	_expect(session.wallet.amount == 200, "gold %d" % session.wallet.amount)
	_expect(session.castle.health.maximum == 300 and session.castle.health.current == 300, "castle hp")
	_expect(session.config.waves.size() == 3, "waves %d" % session.config.waves.size())
	_expect(session.config.buildings[0].cost == 10 and session.config.buildings[1].cost == 50, "costs")
	var enemy_error := session.spawn_enemy_at(Vector2i(8, 2), "base.raider")
	_expect(enemy_error == "", enemy_error)
	var enemy := session.living_enemies()[0]
	_expect(enemy.definition.gold_reward == 8 and enemy.definition.contact_damage == 9, "raider stats")
	var view := enemy.view
	_expect(view != null and not view.uses_frame_animation, "static sprite reported as animation")
	for action in ["idle", "walk", "attack", "hurt", "death"]:
		_expect(view.missing_actions.has(action), "missing action %s" % action)
	var health_before := enemy.health.current
	var cooldown := enemy._attack_wait
	view.set_state("walk")
	view.set_state("attack")
	_expect(enemy.health.current == health_before, "animation state changed health")
	_expect(is_equal_approx(enemy._attack_wait, cooldown), "animation state changed cooldown")
	session.select_building("base.wall")
	var placed: Dictionary = session.place_at_cell(Vector2i(8, 4))
	_expect(placed.ok, str(placed.error))
	_expect(session.wallet.amount == 190, "gold after wall %d" % session.wallet.amount)
	enemy.apply_damage(30)
	_expect(session.wallet.amount == 198, "kill reward %d" % session.wallet.amount)
	var again := enemy.apply_damage(30)
	_expect(again != "", "second kill was accepted")
	_expect(session.wallet.amount == 198, "reward repeated %d" % session.wallet.amount)
	session.apply_castle_damage(9)
	_expect(session.castle.health.current == 291, "castle damage %d" % session.castle.health.current)
	session.restart()
	await process_frame
	_expect(session.ready_ok and session.outcome == "", session.status_message)
	_expect(session.wallet.amount == 200, "restart gold %d" % session.wallet.amount)
	_expect(session.castle.health.current == 300, "restart castle %d" % session.castle.health.current)
	_expect(session.living_enemies().is_empty(), "restart enemies")
	_expect(session.blocked_count() == 4, "restart blocks %d" % session.blocked_count())
	_expect(session.director.next_wave_index == 0 and session.config.waves.size() == 3, "restart waves")
	session.free()


func _test_defeat() -> void:
	var session := await _open("res://data/v2/defeat_match.json")
	if session == null:
		return
	var error := session.spawn_enemy_at(Vector2i(2, 3), "base.raider")
	_expect(error == "", error)
	var sample := await _simulate(session, 180, func() -> bool: return session.outcome == "defeat")
	print("V2_DEFEAT frames=%s hp=%s outcome=%s" % [str(sample), str(session.castle.health.current), session.outcome])
	_expect(session.outcome == "defeat", "outcome %s hp %d" % [session.outcome, session.castle.health.current])
	_expect(session.castle.health.current == 0, "defeat hp %d" % session.castle.health.current)
	_expect(session.outcome != "victory", "defeat also counted as victory")
	session.free()


func _test_victory_and_three_waves() -> void:
	var session := await _open("res://data/v2/prototype_match.json")
	if session == null:
		return
	var spots: Array[Vector2i] = [Vector2i(14, 1), Vector2i(14, 6), Vector2i(8, 1), Vector2i(8, 6)]
	for spot in spots:
		session.select_building("base.archer_tower")
		var placed: Dictionary = session.place_at_cell(spot)
		_expect(placed.ok, "tower %s %s" % [str(spot), str(placed.error)])
	_expect(session.wallet.amount == 0, "tower spend %d" % session.wallet.amount)
	var sample := await _simulate(session, 3600, func() -> bool:
		if session.outcome != "":
			return true
		if session.can_start_wave():
			session.start_next_wave()
		return false
	)
	print("V2_VICTORY frames=%s waves=%d outcome=%s gold=%d castle=%d alive=%d" % [
		str(sample), session.director.next_wave_index, session.outcome, session.wallet.amount, session.castle.health.current, session.living_enemies().size()
	])
	_expect(session.director.next_wave_index == 3, "waves started %d" % session.director.next_wave_index)
	_expect(session.outcome == "victory", "outcome %s castle %d alive %d" % [session.outcome, session.castle.health.current, session.living_enemies().size()])
	_expect(session.outcome != "defeat", "victory also counted as defeat")
	_expect(session.castle.health.current == 300, "castle damaged during victory %d" % session.castle.health.current)
	_expect(session.wallet.amount == 18 * 8, "kill gold %d" % session.wallet.amount)
	session.free()


func _open(path: String) -> FwMatch:
	var session := FwMatch.new()
	session.match_path = path
	root.add_child(session)
	await process_frame
	if not session.ready_ok:
		_fail(session.status_message)
		session.free()
		return null
	return session


func _simulate(session: FwMatch, budget: int, done: Callable) -> int:
	var frames := 0
	for _frame in budget:
		await physics_frame
		frames += 1
		if bool(done.call()):
			break
	return frames


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _fail(message: String) -> void:
	_failures.append(message)
