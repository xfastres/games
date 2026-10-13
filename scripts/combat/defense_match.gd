class_name DefenseMatch
extends Node2D

var match_path := "res://data/combat/prototype_match.json"
var config: DefenseMatchConfig
var grid: PlacementGrid
var wallet: GoldWallet
var spawner: WaveSpawner
var castle: CastleKeep
var hud: DefenseHud
var ready_ok := false
var outcome := ""
var status_message := ""
var selected_id := ""
var columns := 0
var rows := 0
var cell_size := 64
var map_origin := Vector2.ZERO
var alive_enemies := 0

var _view_size := Vector2(1280, 720)
var _castle_cells: Array[Vector2i] = []
var _blocked: Dictionary = {}
var _structures: Dictionary = {}
var _enemy_at: Dictionary = {}
var _move_claim: Dictionary = {}
var _tracked: Dictionary = {}
var _spawn_cursor := 0
var _route_epoch := 0
var _route_cache: Dictionary = {}
var _terrain: TerrainField
var _font: Font


func _ready() -> void:
	_font = UiFont.make()
	_load_match()


func _load_match() -> void:
	var loaded := ContentLoader.load_defense_match(match_path)
	if not loaded.ok:
		_show_fatal(str(loaded.error))
		return
	config = loaded.config
	columns = config.columns
	rows = config.rows
	cell_size = config.cell_size
	var layout_error := _layout_error()
	if layout_error != "":
		_show_fatal(layout_error)
		return
	grid = PlacementGrid.new(columns, rows)
	wallet = GoldWallet.new(config.starting_gold)
	if wallet.init_error != "":
		_show_fatal(wallet.init_error)
		return
	spawner = WaveSpawner.new()
	spawner.waves = config.waves
	var castle_error := _build_castle()
	if castle_error != "":
		_show_fatal(castle_error)
		return
	var spawn_error := _reserve_spawns()
	if spawn_error != "":
		_show_fatal(spawn_error)
		return
	hud = DefenseHud.new()
	hud.name = "DefenseHud"
	add_child(hud)
	hud.build(self)
	ready_ok = true
	status_message = "选择建筑后，在格子上单击放置。右键取消选择。"
	hud.refresh()
	_build_ground()
	print("DEFENSE_READY %s gold=%d waves=%d" % [config.id, wallet.amount, config.waves.size()])
	if "--shot" in OS.get_cmdline_user_args():
		_save_shot.call_deferred()


func combat_enabled() -> bool:
	return ready_ok and outcome == ""


func gold_text() -> String:
	if wallet == null:
		return "金币 --"
	return "金币 %d" % wallet.amount


func castle_text() -> String:
	if castle == null or castle.health == null:
		return "城堡 --"
	return "城堡 %d/%d" % [castle.health.current, castle.health.maximum]


func wave_text() -> String:
	if config == null or spawner == null:
		return "波次 --"
	if spawner.next_wave_index <= 0:
		return "波次 0/%d" % config.waves.size()
	return "波次 %d/%d" % [spawner.next_wave_index, config.waves.size()]


func start_button_text() -> String:
	if outcome != "":
		return "战斗结束"
	if spawner != null and spawner.is_busy():
		return "出兵中"
	if spawner != null and alive_enemies > 0:
		return "等待清场"
	if spawner != null and spawner.next_wave_index > 0:
		return "下一波"
	return "开始波次"


func can_start_wave() -> bool:
	return ready_ok and outcome == "" and spawner != null and not spawner.is_busy() \
		and spawner.has_more() and alive_enemies == 0


func select_building_id(building_id: String) -> String:
	if not ready_ok or outcome != "":
		return "现在不能选择建筑"
	var definition := _definition_by_id(building_id)
	if definition == null:
		return "没有这种可建造的建筑：%s" % building_id
	selected_id = building_id
	status_message = "已选择：%s（%d 金）" % [definition.display_name, definition.cost]
	if definition.description != "":
		status_message += " %s" % definition.description
	if hud != null:
		hud.refresh()
	return ""


func clear_selection() -> void:
	selected_id = ""
	status_message = "已取消选择。"
	if hud != null:
		hud.refresh()


func cell_center(cell: Vector2i) -> Vector2:
	return map_origin + Vector2(cell) * float(cell_size) + Vector2(cell_size, cell_size) * 0.5


func world_to_cell(world_position: Vector2) -> Variant:
	var local := world_position - map_origin
	if local.x < 0.0 or local.y < 0.0:
		return null
	var cell := Vector2i(floori(local.x / float(cell_size)), floori(local.y / float(cell_size)))
	if cell.x >= columns or cell.y >= rows:
		return null
	return cell


func place_at_cell(cell: Vector2i) -> Dictionary:
	return place_at_world_position(cell_center(cell))


func place_at_world_position(world_position: Vector2) -> Dictionary:
	if not ready_ok:
		return _reject("防守尚未就绪")
	if outcome != "":
		return _reject("战斗已经结束")
	if selected_id == "":
		return _reject("请先选择要建造的建筑")
	var definition := _selected_definition()
	if definition == null:
		return _reject("没有这种可建造的建筑：%s" % selected_id)
	if not wallet.can_afford(definition.cost):
		return _reject("金币不足：需要 %d，当前 %d" % [definition.cost, wallet.amount])
	var cell_value: Variant = world_to_cell(world_position)
	if cell_value == null:
		return _reject("无法放置：坐标不在地图网格内")
	var cell: Vector2i = cell_value
	if _footprint_has_enemy(cell, definition):
		return _reject("无法放置：格子上有敌人")
	var placed: Dictionary = grid.try_place(cell, definition)
	if not placed.ok:
		return _reject(str(placed.error))
	var cells: Array[Vector2i] = []
	for raw in placed.cells:
		cells.append(raw as Vector2i)
	var marker := _instantiate_building(definition, cell, cells)
	if marker == null:
		_rollback_cells(cells)
		return _reject(status_message)
	var spent := wallet.try_spend(definition.cost)
	if not spent.ok:
		_rollback_cells(cells)
		marker.free()
		return _reject(str(spent.error))
	for occupied in cells:
		_blocked[occupied] = true
		_structures[occupied] = marker
	_invalidate_routes()
	add_child(marker)
	status_message = "已放置：%s，花费 %d 金" % [definition.display_name, definition.cost]
	print(status_message)
	if hud != null:
		hud.refresh()
	return {"ok": true, "error": "", "cells": cells}


func start_next_wave() -> Dictionary:
	if not can_start_wave():
		return _reject("现在不能开始波次")
	var started := spawner.start_next()
	if not started.ok:
		return _reject(str(started.error))
	status_message = "第 %d 波开始。" % int(started.wave_number)
	print("DEFENSE_WAVE %d" % int(started.wave_number))
	if hud != null:
		hud.refresh()
	return started


func restart() -> void:
	if scene_file_path.is_empty():
		push_error("无法重新开始：当前场景没有文件路径")
		return
	print("DEFENSE_RESTART")
	var error := get_tree().reload_current_scene()
	if error != OK:
		push_error("无法重新开始：%s" % error_string(error))


func query_action(cell: Vector2i) -> Dictionary:
	var plan := route_plan(cell)
	if not bool(plan.get("ok", false)):
		return {
			"ok": false,
			"error": str(plan.get("error", "敌人寻路失败")),
			"kind": "",
			"cell": Vector2i.ZERO,
		}
	if str(plan.get("kind", "")) == "attack_blocker" and not _structures.has(plan.cell):
		return {
			"ok": false,
			"error": "路线要求攻击不存在的建筑 (%d, %d)" % [plan.cell.x, plan.cell.y],
			"kind": "",
			"cell": Vector2i.ZERO,
		}
	return {"ok": true, "error": "", "kind": plan.kind, "cell": plan.cell}


func route_epoch() -> int:
	return _route_epoch


func route_plan(cell: Vector2i) -> Dictionary:
	if _route_cache.has(cell):
		return _route_cache[cell]
	var planned := GridRoute.plan(cell, _castle_cells, _blocked, columns, rows)
	_route_cache[cell] = planned
	return planned


func sync_enemy_cell(enemy: Node, cell: Vector2i) -> void:
	_clear_enemy_cell(enemy)
	_enemy_at[cell] = enemy


func enemies_near(enemy: Node, radius: float) -> Array:
	var found: Array = []
	if not (enemy is Node2D):
		return found
	var origin := (enemy as Node2D).global_position
	for node in get_tree().get_nodes_in_group("defense_enemy"):
		if node == enemy or not (node is Node2D) or not bool(node.get("alive")):
			continue
		var other := node as Node2D
		if origin.distance_to(other.global_position) <= radius:
			found.append(other)
	return found


func _invalidate_routes() -> void:
	_route_epoch += 1
	_route_cache.clear()


func try_begin_step(enemy: Node, cell: Vector2i) -> bool:
	if _blocked.has(cell):
		return false
	if _enemy_at.has(cell) and _enemy_at[cell] != enemy:
		return false
	if _move_claim.has(cell) and _move_claim[cell] != enemy:
		return false
	_release_claim(enemy)
	_move_claim[cell] = enemy
	return true


func finish_step(enemy: Node, cell: Vector2i) -> void:
	if _move_claim.get(cell) == enemy:
		_move_claim.erase(cell)
	_clear_enemy_cell(enemy)
	_enemy_at[cell] = enemy


func cancel_step(enemy: Node) -> void:
	_release_claim(enemy)


func is_path_blocked(cell: Vector2i) -> bool:
	return _blocked.has(cell)


func blocker_at(cell: Vector2i) -> Node:
	return _structures.get(cell) as Node


func apply_castle_damage(amount: int) -> String:
	if outcome != "":
		return "战斗已经结束"
	if castle == null:
		return "城堡不存在"
	var error := castle.apply_damage(amount)
	if error != "" and error != "目标已经摧毁":
		push_error(error)
	return error


func notify_enemy_died(enemy: Node, reward: int) -> void:
	if not _tracked.has(enemy):
		push_error("收到未登记敌人的死亡通知")
		return
	_tracked.erase(enemy)
	_clear_enemy_cell(enemy)
	_release_claim(enemy)
	alive_enemies -= 1
	if alive_enemies < 0:
		push_error("敌人计数变成负数")
	var gold_error := wallet.add(reward)
	if gold_error != "":
		push_error(gold_error)
	_check_victory()
	if hud != null:
		hud.refresh()


func notify_structure_destroyed(building: Node) -> void:
	if building.has_meta("demolished"):
		return
	building.set_meta("demolished", true)
	var cells: Array = building.get("occupied_cells")
	for raw in cells:
		var cell := raw as Vector2i
		_blocked.erase(cell)
		if _structures.get(cell) == building:
			_structures.erase(cell)
		var release_error := grid.release(cell)
		if release_error != "":
			push_error(release_error)
	_invalidate_routes()
	building.queue_free()


func _physics_process(delta: float) -> void:
	if not ready_ok or spawner == null:
		return
	if outcome != "":
		return
	var enemy_id := spawner.poll(delta)
	if enemy_id != "":
		if _try_spawn(enemy_id):
			spawner.commit_spawn()
	_check_victory()
	if hud != null:
		hud.refresh()


func _process(_delta: float) -> void:
	if ready_ok:
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not ready_ok or not (event is InputEventMouseButton):
		return
	var mouse := event as InputEventMouseButton
	if not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_RIGHT:
		clear_selection()
		get_viewport().set_input_as_handled()
		return
	if mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	var local_event := make_input_local(mouse)
	place_at_world_position(local_event.position)
	get_viewport().set_input_as_handled()


func _draw() -> void:
	if not ready_ok:
		return
	var map_size := Vector2(columns * cell_size, rows * cell_size)
	var map_rect := Rect2(map_origin, map_size)
	for cell in config.spawns:
		var spawn_rect := Rect2(map_origin + Vector2(cell) * float(cell_size), Vector2(cell_size, cell_size))
		draw_rect(spawn_rect, Color(0.35, 0.16, 0.16, 0.35), true)
		draw_string(
			_font,
			spawn_rect.position + Vector2(8, 36),
			"出兵",
			HORIZONTAL_ALIGNMENT_LEFT,
			cell_size - 8,
			14,
			Color("f0c2b2")
		)
	var line_color := Color(0.36, 0.42, 0.38, 0.28)
	var map_end := map_rect.end
	for column in columns + 1:
		var x := map_origin.x + column * cell_size
		draw_line(Vector2(x, map_origin.y), Vector2(x, map_end.y), line_color, 1.0)
	for row in rows + 1:
		var y := map_origin.y + row * cell_size
		draw_line(Vector2(map_origin.x, y), Vector2(map_end.x, y), line_color, 1.0)
	_draw_hover()


func _draw_hover() -> void:
	var definition := _selected_definition()
	if definition == null:
		return
	var cell_value: Variant = world_to_cell(get_global_mouse_position())
	if cell_value == null:
		return
	var origin: Vector2i = cell_value
	var preview := Color(0.45, 0.8, 0.45, 0.35)
	if not _preview_ok(origin, definition):
		preview = Color(0.9, 0.3, 0.3, 0.4)
	for y in definition.footprint_height:
		for x in definition.footprint_width:
			var cell := origin + Vector2i(x, y)
			var rect := Rect2(map_origin + Vector2(cell) * float(cell_size), Vector2(cell_size, cell_size))
			draw_rect(rect, preview, true)


func _try_spawn(enemy_id: String) -> bool:
	if outcome != "":
		return false
	if not config.enemies.has(enemy_id):
		_fail_runtime("波次引用了未加载的敌人：%s" % enemy_id)
		return false
	var cell_value: Variant = _free_spawn_cell()
	if cell_value == null:
		return false
	var definition: EnemyDefinition = config.enemies[enemy_id]
	var enemy := _make_enemy(definition, cell_value as Vector2i)
	if enemy == null:
		_fail_runtime("无法生成敌人 %s" % enemy_id)
		return false
	return true


func _make_enemy(definition: EnemyDefinition, cell: Vector2i) -> Node:
	var packed := load(definition.scene_path) as PackedScene
	if packed == null:
		push_error("无法加载敌人场景 %s" % definition.scene_path)
		return null
	var enemy := packed.instantiate()
	if enemy == null:
		push_error("无法实例化敌人场景 %s" % definition.scene_path)
		return null
	add_child(enemy)
	if not enemy.has_method("setup"):
		enemy.free()
		push_error("敌人场景缺少 setup")
		return null
	var error: String = enemy.setup(self, definition, cell)
	if error != "":
		enemy.free()
		push_error(error)
		return null
	_enemy_at[cell] = enemy
	_tracked[enemy] = true
	alive_enemies += 1
	return enemy


func _build_ground() -> void:
	var ground := TileMapLayer.new()
	ground.name = "Ground"
	ground.z_index = -1
	ground.texture_filter = TEXTURE_FILTER_NEAREST
	ground.position = map_origin
	if cell_size != TerrainField.TILE_SIZE:
		var tile_scale := float(cell_size) / float(TerrainField.TILE_SIZE)
		ground.scale = Vector2(tile_scale, tile_scale)
	add_child(ground)
	_terrain = TerrainField.new(columns, rows)
	for y in rows:
		for x in columns:
			var ignored: String = _terrain.set_kind(Vector2i(x, y), TerrainField.GRASS)
			if ignored != "":
				push_error(ignored)
	for spawn in config.spawns:
		var dirt_error: String = _terrain.set_kind(spawn, TerrainField.DIRT)
		if dirt_error != "":
			push_error(dirt_error)
	if config.spawns.is_empty():
		_terrain.apply(ground)
		return
	var road_x := config.castle_origin.x + config.castle_size.x
	var min_y := config.spawns[0].y
	var max_y := config.spawns[0].y
	for spawn in config.spawns:
		min_y = mini(min_y, spawn.y)
		max_y = maxi(max_y, spawn.y)
		for x in range(road_x, spawn.x):
			var road := Vector2i(x, spawn.y)
			if _blocked.has(road):
				continue
			var road_error: String = _terrain.set_kind(road, TerrainField.ROAD)
			if road_error != "":
				push_error(road_error)
	if config.spawns.size() >= 2:
		for y in range(min_y, max_y + 1):
			var connector := Vector2i(road_x, y)
			if _blocked.has(connector):
				continue
			var connector_error: String = _terrain.set_kind(connector, TerrainField.ROAD)
			if connector_error != "":
				push_error(connector_error)
	_terrain.apply(ground)


func _spawn_blocked(cell: Vector2i) -> bool:
	var center := cell_center(cell)
	var limit := float(cell_size) * 0.56
	for node in get_tree().get_nodes_in_group("defense_enemy"):
		if not (node is Node2D) or not bool(node.get("alive")):
			continue
		if center.distance_to((node as Node2D).global_position) < limit:
			return true
	return false


func _cell_has_enemy(cell: Vector2i) -> bool:
	for node in get_tree().get_nodes_in_group("defense_enemy"):
		if bool(node.get("alive")) and node.get("current_cell") == cell:
			return true
	return false


func _free_spawn_cell() -> Variant:
	if config.spawns.is_empty():
		return null
	for offset in config.spawns.size():
		var index := (_spawn_cursor + offset) % config.spawns.size()
		var cell: Vector2i = config.spawns[index]
		if _spawn_blocked(cell):
			continue
		_spawn_cursor = (index + 1) % config.spawns.size()
		return cell
	return null


func _check_victory() -> void:
	if outcome != "" or spawner == null or not spawner.all_waves_committed() or alive_enemies > 0:
		return
	outcome = "victory"
	status_message = "全部波次已被清除。"
	spawner.stop()
	_freeze_combat()
	if hud != null:
		hud.show_outcome("防守成功", "全部敌人已被清除。可以重新开始。")
		hud.refresh()
	print("DEFENSE_VICTORY")


func _on_castle_destroyed() -> void:
	if outcome != "":
		return
	outcome = "defeat"
	status_message = "城堡已被摧毁。"
	if spawner != null:
		spawner.stop()
	_freeze_combat()
	if hud != null:
		hud.show_outcome("防守失败", "城堡已被摧毁。可以重新开始。")
		hud.refresh()
	print("DEFENSE_DEFEAT")


func _freeze_combat() -> void:
	for node in get_tree().get_nodes_in_group("defense_enemy"):
		if node.has_method("set_combat_enabled"):
			node.set_combat_enabled(false)
	for node in get_tree().get_nodes_in_group("defense_projectile"):
		node.queue_free()


func _build_castle() -> String:
	var origin := map_origin + Vector2(config.castle_origin) * float(cell_size)
	var size := Vector2(config.castle_size) * float(cell_size)
	castle = CastleKeep.new()
	castle.name = "CastleKeep"
	var error := castle.setup(origin, size, config.castle_max_health)
	if error != "":
		castle.free()
		castle = null
		return error
	add_child(castle)
	castle.destroyed.connect(_on_castle_destroyed)
	castle.health.changed.connect(_on_castle_health_changed)
	for y in config.castle_size.y:
		for x in config.castle_size.x:
			var cell := config.castle_origin + Vector2i(x, y)
			_castle_cells.append(cell)
			var reserve_error := grid.reserve(cell, "match.castle")
			if reserve_error != "":
				return reserve_error
			_blocked[cell] = true
	return ""


func _reserve_spawns() -> String:
	for cell in config.spawns:
		var reserve_error := grid.reserve(cell, "match.spawn")
		if reserve_error != "":
			return reserve_error
	return ""


func _on_castle_health_changed(_current: int, _maximum: int) -> void:
	if hud != null:
		hud.refresh()


func _layout_error() -> String:
	var view := get_viewport_rect().size
	if view.x < 100.0 or view.y < 100.0:
		view = Vector2(1280, 720)
	_view_size = view
	var map_size := Vector2(columns * cell_size, rows * cell_size)
	if map_size.x > view.x - 16.0 or map_size.y > view.y - 148.0:
		return "地图尺寸超出窗口：%d x %d 像素" % [int(map_size.x), int(map_size.y)]
	map_origin = Vector2(floorf((view.x - map_size.x) * 0.5), 148)
	return ""


func _instantiate_building(
	definition: BuildingDefinition,
	origin: Vector2i,
	cells: Array[Vector2i]
) -> Node2D:
	var packed := load(definition.scene_path) as PackedScene
	if packed == null:
		status_message = "无法放置：建筑场景无法加载 %s" % definition.scene_path
		return null
	var marker: Variant = packed.instantiate()
	if not (marker is Node2D) or not marker.has_method("setup_combat"):
		if is_instance_valid(marker):
			marker.free()
		status_message = "无法放置：建筑场景 %s 缺少 setup_combat" % definition.scene_path
		return null
	var size_px := Vector2(definition.footprint_width, definition.footprint_height) * float(cell_size)
	var world := map_origin + Vector2(origin) * float(cell_size)
	var setup_error: String = marker.setup_combat(world, size_px, definition, self, cells)
	if setup_error != "":
		marker.free()
		status_message = setup_error
		return null
	return marker


func _selected_definition() -> BuildingDefinition:
	return _definition_by_id(selected_id)


func _definition_by_id(building_id: String) -> BuildingDefinition:
	if config == null or building_id == "":
		return null
	for definition in config.buildings:
		if definition.id == building_id:
			return definition
	return null


func _footprint_has_enemy(origin: Vector2i, definition: BuildingDefinition) -> bool:
	for y in definition.footprint_height:
		for x in definition.footprint_width:
			var cell := origin + Vector2i(x, y)
			if _cell_has_enemy(cell) or _move_claim.has(cell):
				return true
	return false


func _preview_ok(origin: Vector2i, definition: BuildingDefinition) -> bool:
	if wallet == null or not wallet.can_afford(definition.cost):
		return false
	for y in definition.footprint_height:
		for x in definition.footprint_width:
			var cell := origin + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
				return false
			if grid.is_occupied(cell) or _cell_has_enemy(cell) or _move_claim.has(cell):
				return false
	return true


func _rollback_cells(cells: Array[Vector2i]) -> void:
	for cell in cells:
		var release_error := grid.release(cell)
		if release_error != "":
			push_error(release_error)


func _clear_enemy_cell(enemy: Node) -> void:
	var stale: Array = []
	for key in _enemy_at.keys():
		if _enemy_at[key] == enemy:
			stale.append(key)
	for key in stale:
		_enemy_at.erase(key)


func _release_claim(enemy: Node) -> void:
	var stale: Array = []
	for key in _move_claim.keys():
		if _move_claim[key] == enemy:
			stale.append(key)
	for key in stale:
		_move_claim.erase(key)


func _fail_runtime(message: String) -> void:
	if outcome != "":
		return
	outcome = "error"
	status_message = message
	push_error(message)
	print("DEFENSE_ERROR %s" % message)
	if spawner != null:
		spawner.stop()
	_freeze_combat()
	if hud != null:
		hud.show_outcome("无法继续", message)
		hud.refresh()


func _reject(message: String) -> Dictionary:
	status_message = message
	print(message)
	if hud != null:
		hud.refresh()
	return {"ok": false, "error": message, "cells": []}


func _show_fatal(message: String) -> void:
	ready_ok = false
	push_error(message)
	print("DEFENSE_LOAD_FAIL %s" % message)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.name = "FatalMessage"
	label.text = message
	label.position = Vector2(24, 24)
	label.size = Vector2(1200, 220)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", _font if _font != null else UiFont.make())
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color("ffb0b0"))
	layer.add_child(label)
	if "--shot" in OS.get_cmdline_user_args():
		get_tree().quit(1)


func _save_shot() -> void:
	for _frame in 3:
		await RenderingServer.frame_post_draw
	if not await _capture_viewport("stage1_preview.png"):
		return
	_arrange_art_preview()
	for _frame in 3:
		await RenderingServer.frame_post_draw
	if not await _capture_viewport("art_integration_preview.png"):
		return
	get_tree().quit(0)


func _arrange_art_preview() -> void:
	var wall_placed: Dictionary = {}
	var select_wall := select_building_id("base.wall")
	if select_wall == "":
		wall_placed = place_at_cell(Vector2i(4, 4))
		if not bool(wall_placed.get("ok", false)):
			push_error("截图城墙放置失败：%s" % str(wall_placed.get("error", "")))
	else:
		push_error(select_wall)
	var select_tower := select_building_id("base.archer_tower")
	if select_tower == "":
		var tower_placed: Dictionary = place_at_cell(Vector2i(7, 3))
		if not bool(tower_placed.get("ok", false)):
			push_error("截图弓箭塔放置失败：%s" % str(tower_placed.get("error", "")))
	else:
		push_error(select_tower)
	clear_selection()
	if not config.enemies.has("base.raider"):
		push_error("截图缺少敌人 base.raider")
		return
	var enemy := _make_enemy(config.enemies["base.raider"], Vector2i(11, 4))
	if enemy == null or not enemy.has_method("set_combat_enabled"):
		push_error("截图敌人没有生成")
		return
	enemy.set_combat_enabled(false)
	var shot := Projectile.new()
	add_child(shot)
	var from := cell_center(Vector2i(9, 4))
	var shot_error := shot.setup(from, enemy, 18, 700)
	shot.active = false
	if shot_error != "":
		push_error(shot_error)
		shot.free()
		return
	shot.face_target()


func _capture_viewport(file_name: String) -> bool:
	var image := get_viewport().get_texture().get_image()
	if image == null:
		push_error("无法取得防守画面")
		get_tree().quit(1)
		return false
	var directory := ProjectSettings.globalize_path("user://")
	var path := directory.path_join(file_name)
	var save_error := image.save_png(path)
	if save_error != OK:
		push_error("截图保存失败：%s" % error_string(save_error))
		get_tree().quit(1)
		return false
	print("STAGE1_SHOT ", path)
	return true
