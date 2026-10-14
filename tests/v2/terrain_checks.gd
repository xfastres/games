extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_connections()
	await _test_roundtrip_and_logic()
	if _failures.is_empty():
		print("V2_TERRAIN_PASS")
		quit(0)
		return
	print("V2_TERRAIN_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_connections() -> void:
	var board := FwTerrainBoard.new(8, 8)
	var layer := TileMapLayer.new()
	root.add_child(layer)
	for x in range(0, 3):
		board.set_kind(Vector2i(x, 1), FwTerrainBoard.ROAD)
	board.set_kind(Vector2i(5, 1), FwTerrainBoard.ROAD)
	board.set_kind(Vector2i(6, 1), FwTerrainBoard.ROAD)
	board.set_kind(Vector2i(6, 2), FwTerrainBoard.ROAD)
	for x in range(2, 5):
		board.set_kind(Vector2i(x, 4), FwTerrainBoard.ROAD)
	board.set_kind(Vector2i(3, 3), FwTerrainBoard.ROAD)
	for x in range(3, 6):
		board.set_kind(Vector2i(x, 6), FwTerrainBoard.ROAD)
	board.set_kind(Vector2i(4, 5), FwTerrainBoard.ROAD)
	board.set_kind(Vector2i(4, 7), FwTerrainBoard.ROAD)
	board.apply(layer)
	var east := layer.map_to_local(Vector2i(1, 0)) - layer.map_to_local(Vector2i(0, 0))
	var south := layer.map_to_local(Vector2i(0, 1)) - layer.map_to_local(Vector2i(0, 0))
	print("V2_TILE_EAST %s" % str(east))
	print("V2_TILE_SOUTH %s" % str(south))
	_expect(layer.tile_set.tile_shape == TileSet.TILE_SHAPE_SQUARE, "tile shape")
	_expect(layer.tile_set.get_terrain_set_mode(0) == TileSet.TERRAIN_MODE_MATCH_SIDES, "terrain mode")
	_expect_mask(layer, board, Vector2i(1, 1), false, true, false, true, "straight")
	_expect_mask(layer, board, Vector2i(6, 1), false, false, true, true, "corner")
	_expect_mask(layer, board, Vector2i(3, 4), true, true, false, true, "tee")
	_expect_mask(layer, board, Vector2i(4, 6), true, true, true, true, "cross")
	var grass := layer.get_cell_atlas_coords(Vector2i(0, 0))
	var other := layer.get_cell_atlas_coords(Vector2i(7, 7))
	_expect(grass.y == 0 and other.y == 0, "grass became road %s %s" % [str(grass), str(other)])
	_expect(grass.x >= 0 and grass.x <= 3 and other.x >= 0 and other.x <= 3, "grass variant out of range")
	_expect(board.kind_at(Vector2i(0, 0)) == FwTerrainBoard.GRASS, "logical grass changed")
	layer.free()


func _test_roundtrip_and_logic() -> void:
	var session := FwMatch.new()
	session.match_path = "res://data/v2/prototype_match.json"
	root.add_child(session)
	await process_frame
	_expect(session.ready_ok, session.status_message)
	_expect(is_equal_approx(session.ground.scale.x, 1.0), "ground scale changed distances")
	for y in session.rows:
		for x in session.columns:
			var cell := Vector2i(x, y)
			var back: Variant = session.world_to_cell(session.cell_to_world(cell))
			if back != cell:
				_failures.append("roundtrip %s -> %s" % [str(cell), str(back)])
				break
	var before := session.blocked_count()
	session.select_building("base.wall")
	var placed: Dictionary = session.place_at_cell(Vector2i(8, 4))
	_expect(placed.ok, str(placed.error))
	_expect(session.blocked_count() == before + 1, "place did not block")
	var grass_before := session._terrain.kind_at(Vector2i(8, 4))
	var structure: FwStructure = session._structures[Vector2i(8, 4)]
	structure.health.apply_damage(structure.health.current)
	await physics_frame
	_expect(not session.is_cell_blocked(Vector2i(8, 4)), "destroyed wall stayed blocked")
	_expect(session._terrain.kind_at(Vector2i(8, 4)) == grass_before, "removing a building changed terrain")
	var north := session.plan_from(Vector2i(15, 2))
	var south := session.plan_from(Vector2i(15, 5))
	_expect(north.ok and south.ok, "aligned paths %s / %s" % [str(north.error), str(south.error)])
	var north_world: Vector2 = session.cell_to_world(Vector2i(15, 2))
	var north_cell: Variant = session.world_to_cell(north_world)
	_expect(north_cell == Vector2i(15, 2), "spawn misaligned %s" % str(north_cell))
	session.free()


func _expect_mask(
	layer: TileMapLayer,
	board: FwTerrainBoard,
	cell: Vector2i,
	north: bool,
	east: bool,
	south: bool,
	west: bool,
	label: String
) -> void:
	var coords := layer.get_cell_atlas_coords(cell)
	var data := board.source().get_tile_data(coords, 0)
	if data == null:
		_failures.append("%s missing tile %s" % [label, str(coords)])
		return
	_expect(data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE) == _bit(north), "%s north %s" % [label, str(coords)])
	_expect(data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE) == _bit(east), "%s east %s" % [label, str(coords)])
	_expect(data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE) == _bit(south), "%s south %s" % [label, str(coords)])
	_expect(data.get_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE) == _bit(west), "%s west %s" % [label, str(coords)])


func _bit(connected: bool) -> int:
	if connected:
		return FwTerrainBoard.ROAD_TERRAIN
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
