extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_resource_paths()
	_test_valid_building()
	_test_invalid_files()
	_test_inline_configs()
	_test_placement_grid()
	await _test_scene_and_movement()
	if _failures.is_empty():
		print("STAGE0_PASS")
		quit(0)
		return
	print("STAGE0_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_resource_paths() -> void:
	_expect_error(
		ContentLoader.load_building("res://data/buildings/does_not_exist.json"),
		"资源不存在",
		"missing file"
	)
	_expect_error(
		ContentLoader.load_building("res://../AGENTS.md"),
		"上级目录",
		"parent path"
	)
	_expect_error(
		ContentLoader.load_building("C:/Windows/win.ini"),
		"res://",
		"windows path"
	)
	_expect_error(
		ContentLoader.load_building("user://save.json"),
		"res://",
		"user path"
	)


func _test_valid_building() -> void:
	var loaded := ContentLoader.load_building("res://data/buildings/test_watchpost.json")
	if not loaded.ok:
		_fail("valid building failed: %s" % str(loaded.error))
		return
	var definition: BuildingDefinition = loaded.definition
	_expect(definition.id == "base.test_watchpost", "valid id")
	_expect(definition.display_name == "测试哨所", "valid name")
	_expect(definition.schema_version == 1, "valid schema")
	_expect(definition.footprint_width == 1 and definition.footprint_height == 1, "valid footprint")
	_expect(
		definition.scene_path == "res://scenes/buildings/placeholder_building.tscn",
		"valid scene"
	)


func _test_invalid_files() -> void:
	var cases := [
		["res://tests/fixtures/invalid_building_missing_id.json", "缺少字段：id"],
		["res://tests/fixtures/invalid_building_bad_version.json", "schema_version 必须为 1"],
		["res://tests/fixtures/invalid_building_bad_footprint.json", "宽高必须大于 0"],
		["res://tests/fixtures/invalid_building_unknown_field.json", "未知字段：surprise"],
		["res://tests/fixtures/invalid_building_missing_scene.json", "资源不存在"],
		["res://tests/fixtures/invalid_not_json.json", "JSON 解析失败"],
	]
	for case_row in cases:
		_expect_error(ContentLoader.load_building(case_row[0]), case_row[1], case_row[0])


func _test_inline_configs() -> void:
	_expect_error(
		BuildingDefinition.parse_text("[1, 2, 3]"),
		"配置不是 JSON 对象",
		"array root"
	)
	_expect_error(
		BuildingDefinition.parse_text(
			'{"id":"base.bad_bool","schema_version":true,"name":"布尔版本","scene":"res://scenes/buildings/placeholder_building.tscn","footprint":{"width":1,"height":1}}'
		),
		"应为整数",
		"bool schema"
	)
	_expect_error(
		BuildingDefinition.parse_text(
			'{"id":"base.bad_icon","schema_version":1,"name":"坏图标","scene":"res://scenes/buildings/placeholder_building.tscn","icon":"res://assets/missing.png","footprint":{"width":1,"height":1}}'
		),
		"资源不存在",
		"missing icon"
	)


func _test_placement_grid() -> void:
	var other := BuildingDefinition.new()
	other.id = "sample.other"
	other.display_name = "另一座"
	other.schema_version = 1
	other.footprint_width = 2
	other.footprint_height = 2
	other.scene_path = "res://scenes/buildings/placeholder_building.tscn"

	var grid := PlacementGrid.new(3, 3)
	var edge: Dictionary = grid.try_place(Vector2i(2, 2), other)
	_expect(not edge.ok, "edge placement should fail")
	_expect("超出地图范围" in str(edge.error), "edge error text: %s" % str(edge.error))
	_expect(grid.occupied_count() == 0, "failed placement must not occupy cells")

	var placed: Dictionary = grid.try_place(Vector2i(0, 0), other)
	_expect(placed.ok, "data-driven placement should accept sample.other")
	_expect(grid.occupied_count() == 4, "2x2 footprint should occupy 4 cells")
	var overlap: Dictionary = grid.try_place(Vector2i(1, 1), other)
	_expect(not overlap.ok and "已被占用" in str(overlap.error), "overlap error: %s" % str(overlap.error))
	_expect(grid.occupied_count() == 4, "rejected overlap must not change occupancy")

	var invalid_map := PlacementGrid.new(0, 4)
	var invalid_place: Dictionary = invalid_map.try_place(Vector2i(0, 0), other)
	_expect(not invalid_place.ok and "地图尺寸无效" in str(invalid_place.error), "invalid map size")


func _test_scene_and_movement() -> void:
	var packed := load("res://scenes/main/tech_demo.tscn") as PackedScene
	if packed == null:
		_fail("tech demo scene failed to load")
		return
	var demo := packed.instantiate()
	root.add_child(demo)
	await process_frame

	if demo.definition == null or demo.definition.id != "base.test_watchpost":
		_fail("scene did not load the test building")
	if "缺少字段：id" not in demo.rejection_message:
		_fail("scene did not show invalid config error: %s" % demo.rejection_message)

	var legal_position: Vector2 = demo.get_map_rect().position + Vector2(130, 70)
	var legal: Dictionary = demo.place_at_world_position(legal_position)
	_expect(legal.ok, "legal placement failed: %s" % str(legal.get("error", "")))
	var occupied: Dictionary = demo.place_at_world_position(legal_position)
	_expect(
		not occupied.ok and "已被占用" in str(occupied.error),
		"occupied placement error: %s" % str(occupied.get("error", ""))
	)
	var outside: Dictionary = demo.place_at_world_position(Vector2(8, 8))
	_expect(
		not outside.ok and "不在地图网格内" in str(outside.error),
		"outside placement error: %s" % str(outside.get("error", ""))
	)
	_expect(demo.action_message.begins_with("无法放置"), "hud should keep the placement error")

	var markers := get_nodes_in_group("placed_building")
	if markers.size() != 1:
		_fail("expected 1 building instance, got %d" % markers.size())
	elif str(markers[0].get_meta("building_id")) != "base.test_watchpost":
		_fail("building instance id was not taken from the config")

	if demo.lord == null:
		_fail("temp lord was not spawned")
		return
	demo.lord.scripted_direction = Vector2.RIGHT
	var start_x: float = demo.lord.global_position.x
	for _frame in 15:
		await physics_frame
	if demo.lord.global_position.x <= start_x + 10.0:
		_fail("lord did not move right: start %s end %s" % [start_x, demo.lord.global_position])
	var min_x: float = demo.lord.map_bounds.position.x
	demo.lord.global_position = Vector2(min_x + 1.0, demo.lord.global_position.y)
	demo.lord.scripted_direction = Vector2.LEFT
	for _frame in 15:
		await physics_frame
	if demo.lord.global_position.x < min_x - 0.01:
		_fail("lord left the map bounds: %s" % demo.lord.global_position)


func _expect_error(result: Dictionary, fragment: String, label: String) -> void:
	if result.get("ok", true):
		_fail("%s should have failed" % label)
		return
	var message := str(result.get("error", ""))
	if fragment not in message:
		_fail("%s error missing '%s': %s" % [label, fragment, message])
	if result.get("definition") != null:
		_fail("%s returned a definition on failure" % label)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
