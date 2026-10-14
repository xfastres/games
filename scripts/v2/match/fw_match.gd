class_name FwMatch
extends Node2D

const DETECT_LAYER := 2
const ARROW_TEXTURE := "res://assets/sprites/projectiles/arrow_projectile.png"
const CASTLE_TEXTURE := "res://assets/sprites/buildings/castle.png"

var match_path := "res://data/v2/prototype_match.json"
var config: DefenseMatchConfig
var wallet: GoldWallet
var ready_ok := false
var outcome := ""
var status_message := ""
var selected_id := ""
var columns := 0
var rows := 0

var ground: TileMapLayer
var actors: Node2D
var hud: FwHud
var castle: FwCastle
var director: FwWaveDirector

var _logic: FwLogicMap
var _terrain: FwTerrainBoard
var _paths := FwPathGrid.new()
var _castle_cells: Array[Vector2i] = []
var _structures: Dictionary = {}
var _spawn_points: Dictionary = {}
var _pending: Array[String] = []
var _spawn_cursor := 0
var _boot_count := 0


func _ready() -> void:
	_boot()


func _boot() -> void:
	_boot_count += 1
	_ensure_nodes()
	_clear_runtime()
	outcome = ""
	selected_id = ""
	ready_ok = false
	var loaded := ContentLoader.load_defense_match(match_path)
	if not loaded.ok:
		_fail_boot(str(loaded.error))
		return
	config = loaded.config
	columns = config.columns
	rows = config.rows
	_logic = FwLogicMap.new(columns, rows)
	_terrain = FwTerrainBoard.new(columns, rows)
	ground.tile_set = _terrain.tileset()
	wallet = GoldWallet.new(config.starting_gold)
	if wallet.init_error != "":
		_fail_boot(wallet.init_error)
		return
	_paint_showcase_roads()
	_terrain.apply(ground)
	_frame_map()
	var castle_error := _build_castle()
	if castle_error != "":
		_fail_boot(castle_error)
		return
	var spawn_error := _reserve_spawns()
	if spawn_error != "":
		_fail_boot(spawn_error)
		return
	director = FwWaveDirector.new()
	director.name = "WaveDirector"
	director.reset(config.waves)
	director.enemy_due.connect(_queue_spawn)
	add_child(director)
	if hud.has_method("build") and hud.get_child_count() == 0:
		hud.build(self)
	ready_ok = true
	status_message = "选择建筑后，在格子上单击放置。右键取消选择。"
	print("V2_READY %s gold=%d castle=%d waves=%d boot=%d" % [
		config.id, wallet.amount, castle.health.maximum, config.waves.size(), _boot_count
	])
	if "--shot" in OS.get_cmdline_user_args():
		_save_shot.call_deferred()


func restart() -> void:
	_boot()


func combat_enabled() -> bool:
	return ready_ok and outcome == ""


func path_epoch() -> int:
	return _paths.epoch


func building_choices() -> Array[BuildingDefinition]:
	if config == null:
		return []
	return config.buildings


func gold_text() -> String:
	if wallet == null:
		return "金币 --"
	return "金币 %d" % wallet.amount


func castle_text() -> String:
	if castle == null or castle.health == null:
		return "城堡 --"
	return "城堡 %d/%d" % [castle.health.current, castle.health.maximum]


func wave_text() -> String:
	if config == null or director == null:
		return "波次 --"
	return "波次 %d/%d" % [director.next_wave_index, config.waves.size()]


func status_text() -> String:
	if outcome == "victory":
		return "胜利。敌人已清空。"
	if outcome == "defeat":
		return "失败。城堡被攻破。"
	return status_message


func cell_to_world(cell: Vector2i) -> Vector2:
	return ground.to_global(ground.map_to_local(cell))


func world_to_cell(world: Vector2) -> Variant:
	if ground == null or ground.tile_set == null or _logic == null:
		return null
	var cell := ground.local_to_map(ground.to_local(world))
	if not _logic.inside(cell):
		return null
	return cell


func is_cell_blocked(cell: Vector2i) -> bool:
	return _logic != null and _logic.is_blocked(cell)


func blocked_count() -> int:
	if _logic == null:
		return 0
	return _logic.blocked_count()


func plan_from(start: Vector2i) -> Dictionary:
	return _paths.approach(start, _castle_cells, _logic.blocked_cells(), columns, rows)


func castle_point() -> Vector2:
	if _castle_cells.is_empty():
		return Vector2.ZERO
	return cell_to_world(_castle_cells[0])


func projectile_parent() -> Node:
	return actors


func report_path_error(message: String) -> void:
	status_message = message
	push_error(message)


func select_building(building_id: String) -> String:
	if not ready_ok or outcome != "":
		return "现在不能选择建筑"
	var definition := _definition(building_id)
	if definition == null:
		return "没有这种可建造的建筑：%s" % building_id
	selected_id = building_id
	status_message = "已选择：%s（%d 金）" % [definition.display_name, definition.cost]
	return ""


func clear_selection() -> void:
	selected_id = ""
	status_message = "已取消选择。"


func place_at_cell(cell: Vector2i) -> Dictionary:
	if not ready_ok:
		return _reject("防守尚未就绪")
	if outcome != "":
		return _reject("战斗已经结束")
	if selected_id == "":
		return _reject("请先选择要建造的建筑")
	var definition := _definition(selected_id)
	if definition == null:
		return _reject("没有这种可建造的建筑：%s" % selected_id)
	if not wallet.can_afford(definition.cost):
		return _reject("金币不足：需要 %d，当前 %d" % [definition.cost, wallet.amount])
	var cells := _footprint(cell, definition)
	if cells.is_empty():
		return _reject(status_message)
	for occupied in cells:
		if _spawn_points.has(occupied):
			return _reject("无法放置：出兵点 (%d, %d)" % [occupied.x, occupied.y])
		if _enemy_near(occupied):
			return _reject("无法放置：格子上有敌人")
	var packed := load(definition.scene_path) as PackedScene
	if packed == null:
		return _reject("无法加载建筑场景：%s" % definition.scene_path)
	var structure := packed.instantiate() as FwStructure
	if structure == null:
		return _reject("建筑场景类型错误：%s" % definition.scene_path)
	var setup_error := structure.setup_combat(self, definition, cell)
	if setup_error != "":
		structure.free()
		return _reject(setup_error)
	var spent := wallet.try_spend(definition.cost)
	if not spent.ok:
		structure.free()
		return _reject(str(spent.error))
	for occupied in cells:
		var block_error := _logic.set_blocked(occupied, true)
		if block_error != "":
			for rollback in cells:
				_logic.set_blocked(rollback, false)
			structure.free()
			wallet.add(definition.cost)
			return _reject(block_error)
		_structures[occupied] = structure
	structure.position = _anchor_position(cells)
	actors.add_child(structure)
	_paths.invalidate()
	status_message = "已放置：%s，花费 %d 金" % [definition.display_name, definition.cost]
	return {"ok": true, "error": ""}


func start_next_wave() -> Dictionary:
	if not can_start_wave():
		return {"ok": false, "error": "现在不能开始波次"}
	var error := director.start_next()
	if error != "":
		return {"ok": false, "error": error}
	status_message = "第 %d 波开始。" % director.next_wave_index
	return {"ok": true, "error": ""}


func can_start_wave() -> bool:
	return ready_ok and outcome == "" and director != null and not director.is_busy() \
		and director.has_more() and living_enemies().is_empty() and _pending.is_empty()


func spawn_enemy_at(cell: Vector2i, enemy_id: String) -> String:
	if not ready_ok:
		return "防守尚未就绪"
	if not _logic.inside(cell):
		return "出兵点超出地图 (%d, %d)" % [cell.x, cell.y]
	if _logic.is_blocked(cell):
		return "无法出兵：格子被占用 (%d, %d)" % [cell.x, cell.y]
	if _enemy_near(cell):
		return "无法出兵：格子上已有敌人 (%d, %d)" % [cell.x, cell.y]
	if not config.enemies.has(enemy_id):
		return "没有这种敌人：%s" % enemy_id
	return _add_enemy(config.enemies[enemy_id], cell)


func apply_castle_damage(amount: int) -> String:
	if castle == null or castle.health == null:
		return "城堡不存在"
	if outcome != "":
		return "战斗已经结束"
	var error := castle.health.apply_damage(amount)
	if error != "":
		return error
	if castle.health.current == 0:
		_set_outcome("defeat")
	return ""


func apply_blocker_damage(cell: Vector2i, amount: int) -> String:
	if not _structures.has(cell):
		return "阻挡格子上没有建筑 (%d, %d)" % [cell.x, cell.y]
	var structure := _structures[cell] as FwStructure
	if structure == null:
		return "阻挡建筑无效 (%d, %d)" % [cell.x, cell.y]
	if structure.definition.behavior_type != BuildingDefinition.BEHAVIOR_BLOCKER \
			and structure.definition.behavior_type != BuildingDefinition.BEHAVIOR_RANGED:
		return "这个建筑不能被拆 (%d, %d)" % [cell.x, cell.y]
	return structure.apply_damage(amount)


func notify_structure_destroyed(structure: FwStructure) -> void:
	var removed: Array[Vector2i] = []
	for raw in _structures.keys():
		if _structures[raw] == structure:
			removed.append(raw)
	for cell in removed:
		_structures.erase(cell)
		var error := _logic.set_blocked(cell, false)
		if error != "":
			push_error(error)
	_paths.invalidate()
	if is_instance_valid(structure):
		structure.queue_free()
	status_message = "建筑被摧毁，路线已更新。"


func notify_enemy_died(enemy: FwEnemy) -> void:
	if enemy.definition != null:
		var error := wallet.add(enemy.definition.gold_reward)
		if error != "":
			push_error(error)
	_evaluate_victory()


func living_enemies() -> Array[FwEnemy]:
	var result: Array[FwEnemy] = []
	if not is_inside_tree():
		return result
	for node in get_tree().get_nodes_in_group("fw_enemy"):
		var enemy := node as FwEnemy
		if enemy != null and enemy.alive and enemy.session == self:
			result.append(enemy)
	return result


func _unhandled_input(event: InputEvent) -> void:
	if not ready_ok:
		return
	if event is InputEventMouseButton and event.pressed:
		var mouse := event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_RIGHT:
			clear_selection()
			return
		if mouse.button_index != MOUSE_BUTTON_LEFT or selected_id == "":
			return
		var cell: Variant = world_to_cell(get_global_mouse_position())
		if cell == null:
			status_message = "点击位置不在地图内"
			return
		place_at_cell(cell)


func _physics_process(_delta: float) -> void:
	if not ready_ok or outcome != "":
		return
	_drain_spawns()
	_evaluate_victory()


func _evaluate_victory() -> void:
	if outcome != "" or director == null or castle == null or castle.health == null:
		return
	if castle.health.current <= 0:
		return
	if director.next_wave_index > 0 and not director.has_more() and not director.is_busy() \
			and _pending.is_empty() and living_enemies().is_empty():
		_set_outcome("victory")


func _set_outcome(next_outcome: String) -> void:
	if outcome != "":
		return
	outcome = next_outcome
	status_message = status_text()


func _queue_spawn(enemy_id: String) -> void:
	_pending.append(enemy_id)


func _drain_spawns() -> void:
	while not _pending.is_empty():
		var cell: Variant = _free_spawn()
		if cell == null:
			return
		var enemy_id := _pending[0]
		var error := spawn_enemy_at(cell, enemy_id)
		if error != "":
			push_error(error)
			return
		_pending.remove_at(0)


func _free_spawn() -> Variant:
	if config == null or config.spawns.is_empty():
		return null
	var count := config.spawns.size()
	for offset in count:
		var index := (_spawn_cursor + offset) % count
		var cell: Vector2i = config.spawns[index]
		if _logic.is_blocked(cell) or _enemy_near(cell):
			continue
		_spawn_cursor = index + 1
		return cell
	return null


func _add_enemy(definition: EnemyDefinition, cell: Vector2i) -> String:
	var packed := load(definition.scene_path) as PackedScene
	if packed == null:
		return "无法加载敌人场景：%s" % definition.scene_path
	var enemy := packed.instantiate() as FwEnemy
	if enemy == null:
		return "敌人场景类型错误：%s" % definition.scene_path
	var error := enemy.setup(self, definition, cell)
	if error != "":
		enemy.free()
		return error
	actors.add_child(enemy)
	return ""


func _build_castle() -> String:
	_castle_cells.clear()
	for y in config.castle_size.y:
		for x in config.castle_size.x:
			var cell := config.castle_origin + Vector2i(x, y)
			if not _logic.inside(cell):
				return "城堡超出地图 (%d, %d)" % [cell.x, cell.y]
			var error := _logic.set_blocked(cell, true)
			if error != "":
				return error
			_castle_cells.append(cell)
	castle = FwCastle.new()
	castle.name = "Castle"
	var texture := load(CASTLE_TEXTURE) as Texture2D
	var error := castle.setup(config.castle_max_health, _castle_cells, texture)
	if error != "":
		return error
	castle.position = _anchor_position(_castle_cells)
	castle.destroyed.connect(func() -> void: _set_outcome("defeat"))
	actors.add_child(castle)
	return ""


func _reserve_spawns() -> String:
	_spawn_points.clear()
	for cell in config.spawns:
		if _logic.is_blocked(cell):
			return "出兵点与城堡重叠 (%d, %d)" % [cell.x, cell.y]
		_spawn_points[cell] = true
	return ""


func _paint_showcase_roads() -> void:
	for x in range(1, columns):
		_terrain.set_kind(Vector2i(x, mini(2, rows - 1)), FwTerrainBoard.ROAD)
		if rows > 5:
			_terrain.set_kind(Vector2i(x, 5), FwTerrainBoard.ROAD)
	if rows > 6:
		for y in range(2, 6):
			_terrain.set_kind(Vector2i(mini(8, columns - 1), y), FwTerrainBoard.ROAD)
		_terrain.set_kind(Vector2i(mini(4, columns - 1), mini(4, rows - 1)), FwTerrainBoard.ROAD)
		for y in range(4, mini(7, rows)):
			_terrain.set_kind(Vector2i(mini(4, columns - 1), y), FwTerrainBoard.ROAD)


func _frame_map() -> void:
	var min_point := Vector2(INF, INF)
	for y in rows:
		for x in columns:
			min_point = min_point.min(ground.map_to_local(Vector2i(x, y)))
	var pad := Vector2(FwTerrainBoard.TILE_W, FwTerrainBoard.TILE_H) * 0.5
	min_point -= pad
	var origin := Vector2(24, 84)
	ground.scale = Vector2.ONE
	ground.position = origin - min_point
	actors.y_sort_enabled = true


func _anchor_position(cells: Array[Vector2i]) -> Vector2:
	var anchor := cells[0]
	for cell in cells:
		if cell.y > anchor.y or (cell.y == anchor.y and cell.x > anchor.x):
			anchor = cell
	return cell_to_world(anchor)


func _footprint(origin: Vector2i, definition: BuildingDefinition) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in definition.footprint_height:
		for x in definition.footprint_width:
			var cell := origin + Vector2i(x, y)
			if not _logic.inside(cell):
				status_message = "无法放置：格子 (%d, %d) 超出地图范围" % [cell.x, cell.y]
				return []
			if _logic.is_blocked(cell):
				status_message = "无法放置：格子 (%d, %d) 已被占用" % [cell.x, cell.y]
				return []
			cells.append(cell)
	return cells


func _enemy_near(cell: Vector2i) -> bool:
	var center := cell_to_world(cell)
	for enemy in living_enemies():
		if enemy.current_cell == cell or enemy.global_position.distance_to(center) < 30.0:
			return true
	return false


func _definition(building_id: String) -> BuildingDefinition:
	if config == null:
		return null
	for building in config.buildings:
		if building.id == building_id:
			return building
	return null


func _ensure_nodes() -> void:
	ground = get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		ground = TileMapLayer.new()
		ground.name = "Ground"
		add_child(ground)
	actors = get_node_or_null("Actors") as Node2D
	if actors == null:
		actors = Node2D.new()
		actors.name = "Actors"
		add_child(actors)
	actors.y_sort_enabled = true
	hud = get_node_or_null("HudLayer") as FwHud
	if hud == null:
		hud = FwHud.new()
		hud.name = "HudLayer"
		add_child(hud)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ground.z_index = 0
	actors.z_index = 2


func _clear_runtime() -> void:
	_pending.clear()
	_structures.clear()
	_castle_cells.clear()
	_spawn_points.clear()
	_paths.invalidate()
	if director != null and is_instance_valid(director):
		var retiring := director
		director = null
		retiring.free()
	if actors != null:
		for child in actors.get_children():
			child.free()
	if hud != null:
		for child in hud.get_children():
			child.free()


func _fail_boot(message: String) -> void:
	ready_ok = false
	status_message = message
	push_error(message)
	print("V2_BOOT_FAIL %s" % message)


func _reject(message: String) -> Dictionary:
	status_message = message
	return {"ok": false, "error": message}


func _save_shot() -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path("res://docs/screenshots/v2_match.png")
	var error := image.save_png(path)
	print("V2_SHOT %s %s" % [error_string(error), path])


func _draw() -> void:
	if not ready_ok or selected_id == "" or ground == null:
		return
	var definition := _definition(selected_id)
	if definition == null:
		return
	var hover: Variant = world_to_cell(get_global_mouse_position())
	if hover == null:
		return
	var origin := hover as Vector2i
	var color := Color(0.95, 0.82, 0.35, 0.9)
	for y in definition.footprint_height:
		for x in definition.footprint_width:
			_draw_cell_diamond(origin + Vector2i(x, y), color)


func _draw_cell_diamond(cell: Vector2i, color: Color) -> void:
	if not _logic.inside(cell):
		return
	var center := to_local(cell_to_world(cell))
	var east := to_local(cell_to_world(Vector2i(mini(cell.x + 1, columns - 1), cell.y))) - center
	var south := to_local(cell_to_world(Vector2i(cell.x, mini(cell.y + 1, rows - 1)))) - center
	if cell.x + 1 >= columns:
		east = to_local(cell_to_world(cell)) - to_local(cell_to_world(cell - Vector2i(1, 0)))
	if cell.y + 1 >= rows:
		south = to_local(cell_to_world(cell)) - to_local(cell_to_world(cell - Vector2i(0, 1)))
	var corners := PackedVector2Array([
		center + (east + south) * 0.5,
		center + (east - south) * 0.5,
		center - (east + south) * 0.5,
		center + (south - east) * 0.5,
	])
	draw_colored_polygon(corners, Color(color.r, color.g, color.b, 0.28))
	draw_polyline(corners + PackedVector2Array([corners[0]]), color, 2.0)
