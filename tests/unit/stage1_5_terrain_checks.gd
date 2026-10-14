extends SceneTree

var _failures: PackedStringArray = []


func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_road_shapes()
	_test_refresh_neighbors()
	_test_ground_tiles_are_square()
	_test_source_art_is_not_stitched()
	_test_native_terrain_connect()
	await _test_battle_map_keeps_logic()
	if _failures.is_empty():
		print("STAGE15_TERRAIN_PASS")
		quit(0)
		return
	print("STAGE15_TERRAIN_FAIL %d" % _failures.size())
	for failure in _failures:
		print("FAIL: ", failure)
	quit(1)


func _test_road_shapes() -> void:
	var field := _blank(8, 6)
	for x in range(1, 5):
		_expect(field.set_kind(Vector2i(x, 2), TerrainField.ROAD) == "", "straight road")
	_expect(field.road_mask(Vector2i(2, 2)) == TerrainField.EAST | TerrainField.WEST, "horizontal mask")
	_expect(field.atlas_coords(Vector2i(2, 2)) == Vector2i(2, 2), "horizontal tile %s" % str(field.atlas_coords(Vector2i(2, 2))))
	_expect(field.road_mask(Vector2i(1, 2)) == TerrainField.EAST, "road end")

	var vertical := _blank(6, 6)
	for y in range(1, 5):
		vertical.set_kind(Vector2i(3, y), TerrainField.ROAD)
	_expect(vertical.road_mask(Vector2i(3, 2)) == TerrainField.NORTH | TerrainField.SOUTH, "vertical mask")
	_expect(vertical.atlas_coords(Vector2i(3, 2)) == Vector2i(5, 1), "vertical tile")

	var corner := _blank(6, 6)
	corner.set_kind(Vector2i(2, 2), TerrainField.ROAD)
	corner.set_kind(Vector2i(3, 2), TerrainField.ROAD)
	corner.set_kind(Vector2i(2, 3), TerrainField.ROAD)
	_expect(corner.road_mask(Vector2i(2, 2)) == TerrainField.EAST | TerrainField.SOUTH, "corner mask")
	_expect(corner.atlas_coords(Vector2i(2, 2)) == Vector2i(6, 1), "corner tile")

	var junction := _blank(6, 6)
	for cell in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		junction.set_kind(cell, TerrainField.ROAD)
	_expect(junction.road_mask(Vector2i(2, 2)) == TerrainField.EAST | TerrainField.SOUTH | TerrainField.WEST, "T mask")
	_expect(junction.atlas_coords(Vector2i(2, 2)) == Vector2i(6, 2), "T tile")

	junction.set_kind(Vector2i(2, 1), TerrainField.ROAD)
	_expect(junction.road_mask(Vector2i(2, 2)) == 15, "cross mask")
	_expect(junction.atlas_coords(Vector2i(2, 2)) == Vector2i(7, 2), "cross tile")

	_expect(field.set_kind(Vector2i(0, 0), TerrainField.DIRT) == "", "dirt")
	_expect(field.atlas_coords(Vector2i(0, 0)) == Vector2i(4, 0), "dirt tile")
	_expect(field.set_kind(Vector2i(0, 1), TerrainField.STONE) == "", "stone")
	_expect(field.atlas_coords(Vector2i(0, 1)) == Vector2i(5, 0), "stone tile")
	_expect(field.kind_at(Vector2i(5, 5)) == TerrainField.GRASS, "default grass")
	_expect(field.atlas_coords(Vector2i(0, 4)).y == 0, "grass stays on the ground row")
	_expect(field.set_kind(Vector2i(1, 1), "water") != "", "unknown terrain must fail")
	_expect(field.kind_at(Vector2i(1, 1)) == TerrainField.GRASS, "rejected terrain must not change the cell")
	_expect("超出地图" in field.set_kind(Vector2i(9, 0), TerrainField.ROAD), "outside terrain")


func _test_refresh_neighbors() -> void:
	var field := _blank(6, 4)
	field.set_kind(Vector2i(2, 1), TerrainField.ROAD)
	field.set_kind(Vector2i(3, 1), TerrainField.ROAD)
	var layer := TileMapLayer.new()
	root.add_child(layer)
	field.apply(layer)
	_expect(layer.get_cell_source_id(Vector2i(2, 1)) == TerrainField.SOURCE_ID, "tile source")
	_expect(layer.get_cell_atlas_coords(Vector2i(2, 1)) == field.atlas_coords(Vector2i(2, 1)), "applied horizontal coords")
	var before := field.road_mask(Vector2i(2, 1))
	field.set_kind(Vector2i(2, 0), TerrainField.ROAD)
	field.refresh(layer, Vector2i(2, 0))
	_expect(field.road_mask(Vector2i(2, 1)) == before | TerrainField.NORTH, "neighbor mask should gain north")
	_expect(layer.get_cell_atlas_coords(Vector2i(2, 1)) == field.atlas_coords(Vector2i(2, 1)), "layer should follow the new mask")
	field.set_kind(Vector2i(2, 0), TerrainField.GRASS)
	field.refresh(layer, Vector2i(2, 0))
	_expect(field.road_mask(Vector2i(2, 1)) == before, "removing the branch restores the straight mask")
	layer.free()


func _test_ground_tiles_are_square() -> void:
	var field := _blank(2, 2)
	var set := field.tileset()
	_expect(set.tile_size == Vector2i(TerrainField.TILE_SIZE, TerrainField.TILE_SIZE), "tile size %s" % str(set.tile_size))
	var source := set.get_source(TerrainField.SOURCE_ID) as TileSetAtlasSource
	_expect(source != null, "atlas source missing")
	if source == null:
		return
	_expect(source.texture_region_size == Vector2i(64, 64), "region %s" % str(source.texture_region_size))
	_expect(source.has_tile(Vector2i(2, 2)), "horizontal road tile exists")
	_expect(source.has_tile(Vector2i(7, 2)), "cross tile exists")


func _test_source_art_is_not_stitched() -> void:
	_expect(TerrainField.UNUSABLE_ART.size() >= 8, "unusable art should be listed")
	var road := load("res://assets/source/art_pack_a/terrain/road_straight.png") as Texture2D
	var grass := load("res://assets/sprites/terrain/grass_tile_01.png") as Texture2D
	_expect(road != null and road.get_width() < 16, "extracted straight road is not a tile, size %s" % str(road.get_size() if road != null else Vector2.ZERO))
	_expect(grass != null and grass.get_width() != 64, "diamond grass is not a 64px square")
	var set := _blank(1, 1).tileset()
	var source := set.get_source(0) as TileSetAtlasSource
	_expect(source != null and source.texture != road and source.texture != grass, "tileset must not reuse the broken source textures")


func _test_battle_map_keeps_logic() -> void:
	var defense := DefenseMatch.new()
	defense.match_path = "res://data/combat/prototype_match.json"
	root.add_child(defense)
	await process_frame
	if not defense.ready_ok:
		_fail("prototype did not start")
		defense.free()
		return
	_expect(defense._blocked.size() == 4, "terrain paint changed blocked cells: %d" % defense._blocked.size())
	var ground := defense.get_node_or_null("Ground") as TileMapLayer
	_expect(ground != null, "battle map has no tile layer")
	if ground == null:
		defense.free()
		return
	_expect(defense._terrain.kind_at(Vector2i(15, 2)) == TerrainField.DIRT, "spawn should stay dirt")
	_expect(defense._terrain.kind_at(Vector2i(8, 2)) == TerrainField.ROAD, "approach should be a road")
	_expect(defense._terrain.road_mask(Vector2i(8, 2)) == TerrainField.EAST | TerrainField.WEST, "live straight road")
	_expect(defense._terrain.road_mask(Vector2i(2, 2)) == TerrainField.EAST | TerrainField.SOUTH, "live corner")
	_expect(ground.get_cell_atlas_coords(Vector2i(8, 2)) == defense._terrain.atlas_coords(Vector2i(8, 2)), "live layer coords")
	var blocked_before := defense._blocked.size()
	var plan_before: Dictionary = defense.route_plan(Vector2i(15, 2))
	defense._terrain.set_kind(Vector2i(8, 2), TerrainField.STONE)
	defense._terrain.refresh(ground, Vector2i(8, 2))
	var plan_after: Dictionary = defense.route_plan(Vector2i(15, 2))
	_expect(defense._blocked.size() == blocked_before, "changing a texture cell changed collision")
	_expect(plan_before.length == plan_after.length and plan_before.path == plan_after.path, "terrain texture changed the route")
	_expect(plan_after.ok and int(plan_after.length) > 0, "spawn route missing")
	defense.free()


func _test_native_terrain_connect() -> void:
	var straight := _blank(8, 6)
	for x in range(1, 5):
		straight.set_kind(Vector2i(x, 2), TerrainField.ROAD)
	var straight_layer := _applied(straight)
	_expect(straight_layer.get_cell_atlas_coords(Vector2i(2, 2)) == Vector2i(2, 2), "connected straight")
	_expect(straight_layer.get_cell_atlas_coords(Vector2i(0, 0)).y == 0, "grass stayed off the road row")
	straight_layer.free()

	var vertical := _blank(6, 6)
	for y in range(1, 5):
		vertical.set_kind(Vector2i(3, y), TerrainField.ROAD)
	var vertical_layer := _applied(vertical)
	_expect(vertical_layer.get_cell_atlas_coords(Vector2i(3, 2)) == Vector2i(5, 1), "connected vertical")
	vertical_layer.free()

	var corner := _blank(6, 6)
	corner.set_kind(Vector2i(2, 2), TerrainField.ROAD)
	corner.set_kind(Vector2i(3, 2), TerrainField.ROAD)
	corner.set_kind(Vector2i(2, 3), TerrainField.ROAD)
	var corner_layer := _applied(corner)
	_expect(corner_layer.get_cell_atlas_coords(Vector2i(2, 2)) == Vector2i(6, 1), "connected corner")
	corner_layer.free()

	var junction := _blank(6, 6)
	for cell in [Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(2, 3)]:
		junction.set_kind(cell, TerrainField.ROAD)
	var tee_layer := _applied(junction)
	_expect(tee_layer.get_cell_atlas_coords(Vector2i(2, 2)) == Vector2i(6, 2), "connected T")
	tee_layer.free()

	junction.set_kind(Vector2i(2, 1), TerrainField.ROAD)
	var cross_layer := _applied(junction)
	_expect(cross_layer.get_cell_atlas_coords(Vector2i(2, 2)) == Vector2i(7, 2), "connected cross")
	_expect(cross_layer.get_cell_atlas_coords(Vector2i(0, 0)) == junction.atlas_coords(Vector2i(0, 0)), "cross paint changed grass")
	cross_layer.free()


func _applied(field: TerrainField) -> TileMapLayer:
	var layer := TileMapLayer.new()
	root.add_child(layer)
	field.apply(layer)
	return layer


func _blank(columns: int, rows: int) -> TerrainField:
	var field := TerrainField.new(columns, rows)
	for y in rows:
		for x in columns:
			field.set_kind(Vector2i(x, y), TerrainField.GRASS)
	return field


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> void:
	_failures.append(message)
