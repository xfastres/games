extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_content()
	_test_wallet_health_and_grid()
	_test_routes()
	await _test_bad_scene()
	await _test_mouse_and_gold()
	await _test_victory_shot()
	await _test_defeat()
	await _test_breach()
	await _test_restart()
	await _test_prototype_defense()
	if _failures.is_empty():
		print("STAGE1_PASS")
		quit(0)
		return
	print("STAGE1_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_content() -> void:
	var watchpost := ContentLoader.load_building("res://data/buildings/test_watchpost.json")
	if not watchpost.ok:
		_fail("watchpost failed: %s" % str(watchpost.error))
	else:
		var definition: BuildingDefinition = watchpost.definition
		_expect(definition.behavior_type == "", "watchpost should stay non-combat")
		_expect(not definition.has_cost and definition.cost == 0, "watchpost has no cost")

	var wall := ContentLoader.load_building("res://data/buildings/wall.json")
	var tower := ContentLoader.load_building("res://data/buildings/archer_tower.json")
	if not wall.ok or not tower.ok:
		_fail("combat buildings failed: %s | %s" % [str(wall.error), str(tower.error)])
	else:
		_expect(wall.definition.behavior_type == "blocker", "wall behavior")
		_expect(wall.definition.display_name == "城墙", "wall name")
		_expect(wall.definition.cost == 10 and wall.definition.max_health == 100, "wall cost and health")
		_expect(wall.definition.footprint_width == 1 and wall.definition.footprint_height == 1, "wall footprint")
		_expect(wall.definition.sprite_path == "res://assets/sprites/buildings/wooden_wall.png", "wall sprite")
		_expect(tower.definition.behavior_type == "ranged", "tower behavior")
		_expect(tower.definition.cost == 50, "tower cost")
		_expect(tower.definition.attack_damage > 0 and tower.definition.attack_range > 0.0, "tower stats")
		_expect(tower.definition.sprite_path == "res://assets/sprites/buildings/archer_tower.png", "tower sprite")
		_expect(wall.definition.scene_path == tower.definition.scene_path, "shared combat scene")

	_expect_error(
		ContentLoader.load_building("res://tests/fixtures/invalid_building_unknown_behavior.json"),
		"未知行为类型：flyer",
		"unknown behavior"
	)
	_expect_error(
		BuildingDefinition.parse_text(
			'{"id":"base.bad_cost","schema_version":1,"name":"负价","scene":"res://scenes/buildings/placeholder_building.tscn","cost":-3,"footprint":{"width":1,"height":1}}'
		),
		"cost 不能为负",
		"negative cost"
	)
	_expect_error(
		BuildingDefinition.parse_text(
			'{"id":"base.free_tower","schema_version":1,"name":"免费塔","scene":"res://scenes/buildings/combat_building.tscn","behavior":{"type":"blocker","max_health":10},"footprint":{"width":1,"height":1}}'
		),
		"cost 必须大于 0",
		"behavior without cost"
	)
	_expect_error(
		BuildingDefinition.parse_text(
			'{"id":"base.bad_ranged","schema_version":1,"name":"缺弹速","scene":"res://scenes/buildings/combat_building.tscn","cost":10,"footprint":{"width":1,"height":1},"behavior":{"type":"ranged","max_health":10,"range":20,"attack_interval":0.2,"damage":1}}'
		),
		"缺少字段：behavior.projectile_speed",
		"missing projectile speed"
	)
	_expect_error(
		BuildingDefinition.parse_text(
			'{"id":"base.splash","schema_version":1,"name":"多余字段","scene":"res://scenes/buildings/combat_building.tscn","cost":10,"footprint":{"width":1,"height":1},"behavior":{"type":"blocker","max_health":10,"splash":1}}'
		),
		"未知字段：behavior.splash",
		"unknown behavior field"
	)
	_expect_error(
		ContentLoader.load_defense_match("res://tests/fixtures/defense/duplicate_match.json"),
		"重复 id：base.wall",
		"duplicate building"
	)
	_expect_error(
		ContentLoader.load_defense_match("res://tests/fixtures/defense/missing_enemy_match.json"),
		"未加载的敌人：base.not_in_match",
		"missing enemy"
	)
	_expect_error(
		ContentLoader.load_defense_match("res://tests/fixtures/defense/missing_setup_match.json"),
		"缺少 setup_combat",
		"missing setup"
	)
	_expect_error(
		DefenseMatchConfig.parse_text(
			'{"id":"base.bad_castle","schema_version":1,"columns":8,"rows":3,"cell_size":64,"starting_gold":10,"castle":{"x":0,"y":0,"width":0,"height":1,"max_health":10},"spawns":[[2,0]],"buildings":["res://data/buildings/wall.json"],"enemies":["res://data/enemies/raider.json"],"waves":"res://data/combat/prototype_waves.json"}'
		),
		"宽高必须大于 0",
		"castle width"
	)
	_expect_error(
		EnemyDefinition.parse_text(
			'{"id":"base.bad_enemy","schema_version":1,"name":"坏敌人","scene":"res://scenes/combat/enemy_unit.tscn","max_health":10,"move_speed":10,"contact_damage":0,"attack_interval":1,"gold_reward":1}'
		),
		"contact_damage 必须大于 0",
		"zero damage enemy"
	)
	_expect_error(
		BuildingDefinition.parse_text(
			'{"id":"base.bad_sprite","schema_version":1,"name":"缺图","scene":"res://scenes/buildings/combat_building.tscn","sprite":"res://assets/sprites/missing.png","cost":10,"footprint":{"width":1,"height":1},"behavior":{"type":"blocker","max_health":10}}'
		),
		"资源不存在",
		"missing building sprite"
	)
	_expect_error(
		EnemyDefinition.parse_text(
			'{"id":"base.bad_sprite","schema_version":1,"name":"缺图","scene":"res://scenes/combat/enemy_unit.tscn","sprite":"res://assets/sprites/missing.png","max_health":10,"move_speed":10,"contact_damage":1,"attack_interval":1,"gold_reward":0}'
		),
		"资源不存在",
		"missing enemy sprite"
	)

	var prototype := ContentLoader.load_defense_match("res://data/combat/prototype_match.json")
	if not prototype.ok:
		_fail("prototype defense failed: %s" % str(prototype.error))
		return
	var config: DefenseMatchConfig = prototype.config
	_expect(config.buildings.size() == 2, "two buildable buildings")
	_expect(config.waves.size() == 3, "three waves")
	_expect(config.enemies.has("base.raider"), "raider loaded")
	_expect(config.starting_gold == 200, "starting gold stays 200")
	_expect(config.castle_max_health == 300, "castle health stays 300")
	var raider: EnemyDefinition = config.enemies["base.raider"]
	_expect(raider.max_health == 30 and raider.gold_reward == 8, "raider combat numbers")
	_expect(raider.sprite_path == "res://assets/sprites/characters/enemies/goblin.png", "raider sprite")
	var ids: PackedStringArray = []
	for building in config.buildings:
		ids.append(building.id)
	_expect(ids.has("base.wall") and ids.has("base.archer_tower"), "prototype ids %s" % str(ids))


func _test_wallet_health_and_grid() -> void:
	var wallet := GoldWallet.new(30)
	var poor: Dictionary = wallet.try_spend(40)
	_expect(not poor.ok and wallet.amount == 30, "spend must not change a poor wallet: %s" % str(poor.error))
	_expect("金币不足" in str(poor.error), "poor message")
	var spent: Dictionary = wallet.try_spend(10)
	_expect(spent.ok and wallet.amount == 20, "spend 10")
	var bad_reward := wallet.add(-1)
	_expect(bad_reward != "" and wallet.amount == 20, "negative reward rejected")
	_expect(wallet.add(4) == "" and wallet.amount == 24, "reward added")

	var health := HealthPool.new(15)
	var bad_hit := health.apply_damage(0)
	_expect(bad_hit != "" and health.current == 15, "zero damage rejected")
	_expect(health.apply_damage(5) == "" and health.current == 10, "damage applied")
	_expect(health.apply_damage(20) == "" and health.current == 0, "lethal damage")
	_expect(health.apply_damage(1) == "目标已经摧毁", "second kill rejected")

	var grid := PlacementGrid.new(3, 3)
	var reserve_error := grid.reserve(Vector2i(1, 1), "match.castle")
	_expect(reserve_error == "", reserve_error)
	var sample := BuildingDefinition.new()
	sample.id = "sample.other"
	sample.footprint_width = 1
	sample.footprint_height = 1
	var blocked: Dictionary = grid.try_place(Vector2i(1, 1), sample)
	_expect(not blocked.ok and "已被占用" in str(blocked.error), "reserved cell blocks placement")
	var release_error := grid.release(Vector2i(1, 1))
	_expect(release_error == "", release_error)
	var opened: Dictionary = grid.try_place(Vector2i(1, 1), sample)
	_expect(opened.ok, "released cell can be used")
	var missing := grid.release(Vector2i(0, 0))
	_expect("没有占用" in missing, missing)


func _test_routes() -> void:
	var open := GridRoute.choose(Vector2i(2, 0), [Vector2i(0, 0)], {}, 5, 1)
	_expect(open.ok and open.kind == "move" and open.cell == Vector2i(1, 0), "open step %s" % str(open))
	var adjacent := GridRoute.choose(Vector2i(1, 0), [Vector2i(0, 0)], {}, 5, 1)
	_expect(adjacent.ok and adjacent.kind == "attack_castle", "adjacent attacks castle")
	var outside := GridRoute.choose(Vector2i(-1, 0), [Vector2i(0, 0)], {}, 5, 1)
	_expect(not outside.ok and "地图外" in str(outside.error), "outside route")

	var blocked := {Vector2i(2, 0): true}
	var far := GridRoute.choose(Vector2i(4, 0), [Vector2i(0, 0)], blocked, 5, 1)
	_expect(far.ok and far.kind == "move" and far.cell == Vector2i(3, 0), "approach the wall %s" % str(far))
	var hit := GridRoute.choose(Vector2i(3, 0), [Vector2i(0, 0)], blocked, 5, 1)
	_expect(hit.ok and hit.kind == "attack_blocker" and hit.cell == Vector2i(2, 0), "attack the wall %s" % str(hit))

	var around_blocked := {Vector2i(1, 1): true, Vector2i(2, 1): true}
	var cell := Vector2i(4, 1)
	var reached := false
	for _step in 16:
		var action := GridRoute.choose(cell, [Vector2i(0, 1)], around_blocked, 5, 3)
		if not action.ok:
			_fail("around route failed: %s" % str(action.error))
			return
		if action.kind == "attack_castle":
			reached = true
			break
		_expect(action.kind == "move", "unexpected around action %s" % str(action))
		_expect(not around_blocked.has(action.cell), "route entered a wall at %s" % str(action.cell))
		cell = action.cell
	_expect(reached, "enemy should walk around walls to the castle")


func _test_bad_scene() -> void:
	var broken := DefenseMatch.new()
	broken.match_path = "res://tests/fixtures/invalid_not_json.json"
	root.add_child(broken)
	await process_frame
	_expect(not broken.ready_ok, "invalid defense should not start")
	var fatal := broken.find_child("FatalMessage", true, false) as Label
	_expect(fatal != null and "JSON" in str(fatal.text), "fatal text missing")
	broken.free()


func _test_mouse_and_gold() -> void:
	var defense := await _open_match("res://tests/fixtures/defense/short_match.json")
	if defense == null:
		return
	var button := defense.find_child("Build_base_short_tower", true, false) as Button
	if button == null:
		_fail("tower button missing")
		_close(defense)
		return
	button.pressed.emit()
	_expect(defense.selected_id == "base.short_tower", "button selects the tower")

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = defense.cell_center(Vector2i(2, 0))
	defense._unhandled_input(event)
	_expect(defense.wallet.amount == 30, "mouse placement should spend 10, got %d" % defense.wallet.amount)
	var towers := _buildings(defense)
	_expect(towers.size() == 1, "mouse click should place one tower, got %d" % towers.size())
	if towers.size() == 1:
		_expect(towers[0].get_child_count() >= 2, "tower should have a blocker and a weapon")
		_expect(str(towers[0].get_meta("building_id")) == "base.short_tower", "placed id comes from config")

	event.button_index = MOUSE_BUTTON_RIGHT
	defense._unhandled_input(event)
	_expect(defense.selected_id == "", "right click clears selection")
	var occupied := defense.grid.occupied_count()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = defense.cell_center(Vector2i(3, 0))
	defense._unhandled_input(event)
	_expect(defense.grid.occupied_count() == occupied, "cleared selection must not place")

	defense.select_building_id("base.short_tower")
	var outside: Dictionary = defense.place_at_world_position(Vector2(4, 4))
	_expect(not outside.ok and "不在地图网格内" in str(outside.error), "outside click %s" % str(outside.error))
	var overlap: Dictionary = defense.place_at_cell(Vector2i(2, 0))
	_expect(not overlap.ok and "已被占用" in str(overlap.error), "occupied click %s" % str(overlap.error))
	_expect(defense.wallet.amount == 30, "failed placement must not spend more gold")
	_close(defense)

	var payer := await _open_match("res://tests/fixtures/defense/short_match.json")
	if payer == null:
		return
	payer.select_building_id("base.short_tower")
	for index in 4:
		var placed: Dictionary = payer.place_at_cell(Vector2i(index + 1, 0))
		_expect(placed.ok, "tower %d failed: %s" % [index, str(placed.error)])
	_expect(payer.wallet.amount == 0, "four towers spend the starting gold")
	var broke: Dictionary = payer.place_at_cell(Vector2i(5, 0))
	_expect(not broke.ok and "金币不足" in str(broke.error), "fifth tower %s" % str(broke.error))
	_expect(payer.wallet.amount == 0, "rejected purchase stays at zero")
	_expect(_buildings(payer).size() == 4, "fifth tower was not instantiated")
	_close(payer)


func _test_victory_shot() -> void:
	var defense := await _open_match("res://tests/fixtures/defense/short_match.json")
	if defense == null:
		return
	defense.select_building_id("base.short_tower")
	var placed: Dictionary = defense.place_at_cell(Vector2i(3, 0))
	_expect(placed.ok, "victory tower %s" % str(placed.error))
	var started: Dictionary = defense.start_next_wave()
	_expect(started.ok, "start wave %s" % str(started.error))
	var castle_hp := defense.castle.health.current
	for _frame in 240:
		await physics_frame
		if _enemy_on_blocked(defense):
			_close(defense)
			return
		if defense.outcome != "":
			break
	_expect(defense.outcome == "victory", "short defense outcome=%s castle=%s alive=%s gold=%s msg=%s" % [
		defense.outcome, defense.castle_text(), defense.alive_enemies, defense.wallet.amount, defense.status_message
	])
	_expect(defense.castle.health.current == castle_hp, "victory should not damage the castle")
	_expect(defense.wallet.amount == 39, "gold should be 40 - 10 + 9, got %d" % defense.wallet.amount)
	var title := defense.find_child("ResultTitle", true, false) as Label
	var overlay := defense.find_child("OutcomeOverlay", true, false) as Control
	_expect(overlay != null and overlay.visible and title != null and title.text == "防守成功", "victory overlay")
	_close(defense)


func _test_defeat() -> void:
	var defense := await _open_match("res://tests/fixtures/defense/defeat_match.json")
	if defense == null:
		return
	var started: Dictionary = defense.start_next_wave()
	_expect(started.ok, "defeat wave %s" % str(started.error))
	for _frame in 240:
		await physics_frame
		if defense.outcome != "":
			break
	_expect(defense.outcome == "defeat", "defeat outcome=%s %s alive=%s" % [
		defense.outcome, defense.castle_text(), defense.alive_enemies
	])
	_expect(defense.castle.health.current == 0, "castle should be destroyed")
	_expect(defense.outcome != "victory", "defeat must not also count as victory")
	var overlay := defense.find_child("OutcomeOverlay", true, false) as Control
	var title := defense.find_child("ResultTitle", true, false) as Label
	_expect(overlay != null and overlay.visible and title != null and "防守失败" in title.text, "defeat overlay")
	var restart := defense.find_child("OutcomeRestart", true, false) as Button
	_expect(restart != null, "defeat screen should offer restart")
	_close(defense)


func _test_breach() -> void:
	var defense := await _open_match("res://tests/fixtures/defense/breach_match.json")
	if defense == null:
		return
	defense.select_building_id("base.short_wall")
	var placed: Dictionary = defense.place_at_cell(Vector2i(3, 0))
	_expect(placed.ok, "breach wall %s" % str(placed.error))
	defense.start_next_wave()
	var crossed := false
	for _frame in 300:
		await physics_frame
		var wall := defense.blocker_at(Vector2i(3, 0))
		for node in get_nodes_in_group("defense_enemy"):
			if not is_instance_valid(node) or not bool(node.get("alive")):
				continue
			var cell: Vector2i = node.current_cell
			if wall != null and cell == Vector2i(3, 0):
				_fail("enemy walked through a living wall")
			if cell.x < 3:
				crossed = true
		if defense.blocker_at(Vector2i(3, 0)) == null and crossed:
			break
	_expect(defense.blocker_at(Vector2i(3, 0)) == null, "blocked enemy should destroy the wall")
	_expect(crossed, "enemy should continue after the wall falls")
	_close(defense)


func _test_restart() -> void:
	var packed := load("res://scenes/combat/defense_match.tscn") as PackedScene
	if packed == null:
		_fail("defense scene missing")
		return
	var defense := packed.instantiate() as DefenseMatch
	root.add_child(defense)
	current_scene = defense
	await process_frame
	if not defense.ready_ok:
		_fail("prototype scene was not ready")
		_close(defense)
		return
	var select_error := defense.select_building_id("base.wall")
	_expect(select_error == "", select_error)
	var placed: Dictionary = defense.place_at_cell(Vector2i(5, 1))
	_expect(placed.ok, "restart setup place %s" % str(placed.error))
	var starting := defense.config.starting_gold
	_expect(defense.wallet.amount < starting, "gold was spent before restart")
	defense.restart()
	for _frame in 20:
		await process_frame
	var restarted := current_scene as DefenseMatch
	if restarted == null or not is_instance_valid(restarted) or restarted == defense:
		_fail("restart did not load a new defense scene")
		return
	_expect(restarted.ready_ok, "restarted scene should be ready")
	_expect(restarted.wallet.amount == restarted.config.starting_gold, "restart gold %s" % restarted.wallet.amount)
	_expect(get_nodes_in_group("combat_building").is_empty(), "restart should remove placed buildings")
	_expect(restarted.castle.health.current == restarted.castle.health.maximum, "restart castle")
	_close(restarted)


func _test_prototype_defense() -> void:
	var defense := await _open_match("res://data/combat/prototype_match.json")
	if defense == null:
		return
	var towers: Array[Vector2i] = [Vector2i(8, 2), Vector2i(8, 5), Vector2i(7, 4)]
	for cell in towers:
		defense.select_building_id("base.archer_tower")
		var placed: Dictionary = defense.place_at_cell(cell)
		if not placed.ok:
			_fail("prototype tower %s failed: %s" % [cell, str(placed.error)])
			_close(defense)
			return
	var walls: Array[Vector2i] = [Vector2i(4, 2), Vector2i(4, 3), Vector2i(4, 4), Vector2i(4, 5)]
	for cell in walls:
		defense.select_building_id("base.wall")
		var placed: Dictionary = defense.place_at_cell(cell)
		if not placed.ok:
			_fail("prototype wall %s failed: %s" % [cell, str(placed.error)])
			_close(defense)
			return
	var frames := 0
	while frames < 5000 and defense.outcome == "":
		if defense.can_start_wave():
			var started: Dictionary = defense.start_next_wave()
			if not started.ok:
				_fail("prototype wave failed: %s" % str(started.error))
				break
		await physics_frame
		frames += 1
		if _enemy_on_blocked(defense):
			break
	print("PROTOTYPE_RESULT outcome=%s frames=%d %s alive=%d gold=%d" % [
		defense.outcome, frames, defense.castle_text(), defense.alive_enemies, defense.wallet.amount
	])
	_expect(defense.outcome == "victory", "scripted prototype defense did not win")
	_expect(defense.castle.health.current > 0, "castle died in the prototype defense")
	_close(defense)


func _open_match(path: String) -> DefenseMatch:
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


func _close(node: Node) -> void:
	if current_scene == node:
		current_scene = null
	if is_instance_valid(node):
		node.free()


func _buildings(defense: Node) -> Array:
	var found: Array = []
	for node in get_nodes_in_group("combat_building"):
		if node is Node and (node as Node).get_parent() == defense:
			found.append(node)
	return found


func _enemy_on_blocked(defense: DefenseMatch) -> bool:
	for node in get_nodes_in_group("defense_enemy"):
		if not is_instance_valid(node) or not bool(node.get("alive")):
			continue
		var cell: Vector2i = node.current_cell
		if defense.is_path_blocked(cell):
			_fail("enemy stood on a blocked cell %s" % cell)
			return true
	return false


func _expect_error(result: Dictionary, fragment: String, label: String) -> void:
	if result.get("ok", true):
		_fail("%s should have failed" % label)
		return
	var message := str(result.get("error", ""))
	if fragment not in message:
		_fail("%s error missing '%s': %s" % [label, fragment, message])
	if result.get("definition") != null or result.get("config") != null:
		_fail("%s returned content on failure" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
