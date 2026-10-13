class_name DefenseMatchConfig
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const ROOT_FIELDS: Array[String] = [
	"id",
	"schema_version",
	"columns",
	"rows",
	"cell_size",
	"starting_gold",
	"castle",
	"spawns",
	"buildings",
	"enemies",
	"waves",
]
const CASTLE_FIELDS: Array[String] = ["x", "y", "width", "height", "max_health"]

var id: String
var schema_version: int
var columns: int
var rows: int
var cell_size: int
var starting_gold: int
var castle_origin: Vector2i
var castle_size: Vector2i
var castle_max_health: int
var spawns: Array[Vector2i] = []
var buildings: Array[BuildingDefinition] = []
var enemies: Dictionary = {}
var waves: Array = []


static func parse_text(text: String) -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		return ContentFields.fail(
			"JSON 解析失败：%s（第 %d 行）" % [parser.get_error_message(), parser.get_error_line()]
		)
	if typeof(parser.data) != TYPE_DICTIONARY:
		return ContentFields.fail("配置不是 JSON 对象")
	return parse_dictionary(parser.data)


static func parse_dictionary(data: Dictionary) -> Dictionary:
	var shape_error := ContentFields.validate_keys(data, ROOT_FIELDS, ROOT_FIELDS, "")
	if shape_error != "":
		return ContentFields.fail(shape_error)
	var id_text := ContentFields.read_nonempty_string(data["id"], "id")
	if not id_text.ok:
		return id_text
	var id_error := ContentFields.validate_id(id_text.value)
	if id_error != "":
		return ContentFields.fail(id_error)
	var version := ContentFields.read_int(data["schema_version"], "schema_version")
	if not version.ok:
		return version
	if int(version.value) != SUPPORTED_SCHEMA_VERSION:
		return ContentFields.fail("字段取值无效：schema_version 必须为 1，实际为 %s" % str(version.value))

	var columns := ContentFields.read_int(data["columns"], "columns")
	if not columns.ok:
		return columns
	var rows := ContentFields.read_int(data["rows"], "rows")
	if not rows.ok:
		return rows
	if int(columns.value) < 4 or int(columns.value) > 24 or int(rows.value) < 1 or int(rows.value) > 16:
		return ContentFields.fail(
			"字段取值无效：地图必须在 4..24 列、1..16 行之间，实际为 %d x %d"
			% [int(columns.value), int(rows.value)]
		)
	var cell_size := ContentFields.read_int(data["cell_size"], "cell_size")
	if not cell_size.ok:
		return cell_size
	if int(cell_size.value) < 32 or int(cell_size.value) > 96:
		return ContentFields.fail(
			"字段取值无效：cell_size 必须在 32 到 96 之间，实际为 %d" % int(cell_size.value)
		)
	var gold := ContentFields.read_int(data["starting_gold"], "starting_gold")
	if not gold.ok:
		return gold
	if int(gold.value) < 0:
		return ContentFields.fail("字段取值无效：starting_gold 不能为负，实际为 %d" % int(gold.value))

	var castle := _parse_castle(data["castle"], int(columns.value), int(rows.value))
	if not castle.ok:
		return castle
	var spawns := _parse_spawns(data["spawns"], int(columns.value), int(rows.value), castle.cells)
	if not spawns.ok:
		return spawns

	var buildings := _load_buildings(data["buildings"])
	if not buildings.ok:
		return buildings
	var enemies := _load_enemies(data["enemies"])
	if not enemies.ok:
		return enemies
	var waves := _load_waves(data["waves"], enemies.by_id)
	if not waves.ok:
		return waves

	var config := DefenseMatchConfig.new()
	config.id = id_text.value
	config.schema_version = int(version.value)
	config.columns = int(columns.value)
	config.rows = int(rows.value)
	config.cell_size = int(cell_size.value)
	config.starting_gold = int(gold.value)
	config.castle_origin = castle.origin
	config.castle_size = castle.size
	config.castle_max_health = int(castle.max_health)
	config.spawns = spawns.cells
	config.buildings = buildings.list
	config.enemies = enemies.by_id
	config.waves = waves.list
	return {"ok": true, "error": "", "config": config}


static func _parse_castle(value: Variant, columns: int, rows: int) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return ContentFields.fail("字段类型错误：castle 应为对象")
	var castle: Dictionary = value
	var shape_error := ContentFields.validate_keys(castle, CASTLE_FIELDS, CASTLE_FIELDS, "castle.")
	if shape_error != "":
		return ContentFields.fail(shape_error)
	var origin_x := ContentFields.read_int(castle["x"], "castle.x")
	if not origin_x.ok:
		return origin_x
	var origin_y := ContentFields.read_int(castle["y"], "castle.y")
	if not origin_y.ok:
		return origin_y
	var width := ContentFields.read_int(castle["width"], "castle.width")
	if not width.ok:
		return width
	var height := ContentFields.read_int(castle["height"], "castle.height")
	if not height.ok:
		return height
	var health := ContentFields.read_int(castle["max_health"], "castle.max_health")
	if not health.ok:
		return health
	if int(width.value) < 1 or int(height.value) < 1:
		return ContentFields.fail(
			"字段取值无效：castle 的宽高必须大于 0，实际为 %d x %d"
			% [int(width.value), int(height.value)]
		)
	if int(health.value) < 1:
		return ContentFields.fail(
			"字段取值无效：castle.max_health 必须大于 0，实际为 %d" % int(health.value)
		)
	var origin := Vector2i(int(origin_x.value), int(origin_y.value))
	var size := Vector2i(int(width.value), int(height.value))
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var cell := origin + Vector2i(x, y)
			if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
				return ContentFields.fail("城堡超出地图：格子 (%d, %d)" % [cell.x, cell.y])
			cells.append(cell)
	return {
		"ok": true,
		"error": "",
		"origin": origin,
		"size": size,
		"max_health": int(health.value),
		"cells": cells,
	}


static func _parse_spawns(
	value: Variant,
	columns: int,
	rows: int,
	castle_cells: Array[Vector2i]
) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return ContentFields.fail("字段类型错误：spawns 应为数组")
	var source: Array = value
	if source.is_empty():
		return ContentFields.fail("至少需要一个出兵点")
	var castle := {}
	for cell in castle_cells:
		castle[cell] = true
	var spawns: Array[Vector2i] = []
	var seen := {}
	for index in source.size():
		var point: Variant = source[index]
		if typeof(point) != TYPE_ARRAY or (point as Array).size() != 2:
			return ContentFields.fail("字段取值无效：spawns[%d] 必须是两个整数" % index)
		var pair: Array = point
		var x_read := ContentFields.read_int(pair[0], "spawns[%d].x" % index)
		if not x_read.ok:
			return x_read
		var y_read := ContentFields.read_int(pair[1], "spawns[%d].y" % index)
		if not y_read.ok:
			return y_read
		var cell := Vector2i(int(x_read.value), int(y_read.value))
		if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
			return ContentFields.fail("出兵点超出地图：格子 (%d, %d)" % [cell.x, cell.y])
		if castle.has(cell):
			return ContentFields.fail("出兵点与城堡重叠：格子 (%d, %d)" % [cell.x, cell.y])
		if seen.has(cell):
			return ContentFields.fail("出兵点重复：格子 (%d, %d)" % [cell.x, cell.y])
		seen[cell] = true
		spawns.append(cell)
	return {"ok": true, "error": "", "cells": spawns}


static func _load_buildings(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return ContentFields.fail("字段类型错误：buildings 应为数组")
	var source: Array = value
	if source.is_empty():
		return ContentFields.fail("至少需要一种可建造的建筑")
	var buildings: Array[BuildingDefinition] = []
	var seen := {}
	for index in source.size():
		if typeof(source[index]) != TYPE_STRING:
			return ContentFields.fail("字段类型错误：buildings[%d] 应为字符串" % index)
		var loaded := ContentLoader.load_building(str(source[index]))
		if not loaded.ok:
			return ContentFields.fail("建筑配置 %s：%s" % [str(source[index]), str(loaded.error)])
		var definition: BuildingDefinition = loaded.definition
		if seen.has(definition.id):
			return ContentFields.fail("重复 id：%s" % definition.id)
		if definition.behavior_type != BuildingDefinition.BEHAVIOR_BLOCKER \
				and definition.behavior_type != BuildingDefinition.BEHAVIOR_RANGED:
			return ContentFields.fail("建筑 %s 没有可用于防守的行为" % definition.id)
		if definition.cost < 1:
			return ContentFields.fail("建筑 %s 的造价必须大于 0" % definition.id)
		var method_error := _require_scene_method(definition.scene_path, "setup_combat")
		if method_error != "":
			return ContentFields.fail(method_error)
		seen[definition.id] = true
		buildings.append(definition)
	return {"ok": true, "error": "", "list": buildings}


static func _load_enemies(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return ContentFields.fail("字段类型错误：enemies 应为数组")
	var source: Array = value
	if source.is_empty():
		return ContentFields.fail("至少需要一种敌人")
	var enemies := {}
	for index in source.size():
		if typeof(source[index]) != TYPE_STRING:
			return ContentFields.fail("字段类型错误：enemies[%d] 应为字符串" % index)
		var loaded := ContentLoader.load_enemy(str(source[index]))
		if not loaded.ok:
			return ContentFields.fail("敌人配置 %s：%s" % [str(source[index]), str(loaded.error)])
		var definition: EnemyDefinition = loaded.definition
		if enemies.has(definition.id):
			return ContentFields.fail("重复 id：%s" % definition.id)
		var method_error := _require_scene_method(definition.scene_path, "setup")
		if method_error != "":
			return ContentFields.fail(method_error)
		enemies[definition.id] = definition
	return {"ok": true, "error": "", "by_id": enemies}


static func _load_waves(value: Variant, enemies: Dictionary) -> Dictionary:
	if typeof(value) != TYPE_STRING:
		return ContentFields.fail("字段类型错误：waves 应为字符串")
	var loaded := ContentLoader.load_wave_set(str(value))
	if not loaded.ok:
		return ContentFields.fail("波次配置 %s：%s" % [str(value), str(loaded.error)])
	var wave_set: WaveSet = loaded.definition
	for wave in wave_set.waves:
		var enemy_id := str(wave["enemy_id"])
		if not enemies.has(enemy_id):
			return ContentFields.fail("波次引用了未加载的敌人：%s" % enemy_id)
	return {"ok": true, "error": "", "list": wave_set.waves}


static func _require_scene_method(scene_path: String, method_name: String) -> String:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return "无法加载场景：%s" % scene_path
	var node: Node = packed.instantiate()
	if node == null:
		return "无法实例化场景：%s" % scene_path
	var missing := not node.has_method(method_name)
	node.free()
	if missing:
		return "场景 %s 缺少 %s" % [scene_path, method_name]
	return ""
