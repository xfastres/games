class_name BuildingDefinition
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const BEHAVIOR_BLOCKER := "blocker"
const BEHAVIOR_RANGED := "ranged"
const ROOT_FIELDS: Array[String] = [
	"id",
	"schema_version",
	"name",
	"description",
	"scene",
	"icon",
	"sprite",
	"footprint",
	"cost",
	"behavior",
]
const REQUIRED_ROOT: Array[String] = ["id", "schema_version", "name", "scene", "footprint"]
const FOOTPRINT_FIELDS: Array[String] = ["width", "height"]
const BLOCKER_FIELDS: Array[String] = ["type", "max_health"]
const RANGED_FIELDS: Array[String] = [
	"type",
	"max_health",
	"range",
	"attack_interval",
	"damage",
	"projectile_speed",
]

var id: String
var schema_version: int
var display_name: String
var description: String
var scene_path: String
var icon_path: String
var sprite_path: String
var footprint_width: int
var footprint_height: int
var cost: int
var has_cost := false
var behavior_type := ""
var max_health: int
var attack_range: float
var attack_interval: float
var attack_damage: int
var projectile_speed: float


static func parse_text(text: String) -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(text)
	if parse_error != OK:
		return _fail(
			"JSON 解析失败：%s（第 %d 行）" % [parser.get_error_message(), parser.get_error_line()]
		)
	if typeof(parser.data) != TYPE_DICTIONARY:
		return _fail("配置不是 JSON 对象")
	return parse_dictionary(parser.data)


static func parse_dictionary(data: Dictionary) -> Dictionary:
	var shape_error := _validate_object_keys(data, ROOT_FIELDS, REQUIRED_ROOT, "")
	if shape_error != "":
		return _fail(shape_error)

	var id_text := _read_nonempty_string(data["id"], "id")
	if not id_text.ok:
		return id_text
	var id_error := _validate_id(id_text.value)
	if id_error != "":
		return _fail(id_error)

	var version := _read_int(data["schema_version"], "schema_version")
	if not version.ok:
		return version
	if int(version.value) != SUPPORTED_SCHEMA_VERSION:
		return _fail("字段取值无效：schema_version 必须为 1，实际为 %s" % str(version.value))

	var building_name := _read_nonempty_string(data["name"], "name")
	if not building_name.ok:
		return building_name

	var description_text := ""
	if data.has("description"):
		var description_value := _read_string(data["description"], "description")
		if not description_value.ok:
			return description_value
		description_text = description_value.value

	var scene_value := _read_string(data["scene"], "scene")
	if not scene_value.ok:
		return scene_value
	var scene_error := ResourcePath.validate_project_file(scene_value.value, "字段 scene", ".tscn")
	if scene_error != "":
		return _fail(scene_error)

	var icon_text := ""
	if data.has("icon"):
		var icon_value := _read_string(data["icon"], "icon")
		if not icon_value.ok:
			return icon_value
		var icon_error := ResourcePath.validate_project_file(icon_value.value, "字段 icon", "")
		if icon_error != "":
			return _fail(icon_error)
		icon_text = icon_value.value

	var sprite_text := ""
	if data.has("sprite"):
		var sprite_value := _read_string(data["sprite"], "sprite")
		if not sprite_value.ok:
			return sprite_value
		var sprite_error := ResourcePath.validate_project_file(sprite_value.value, "字段 sprite", ".png")
		if sprite_error != "":
			return _fail(sprite_error)
		sprite_text = sprite_value.value

	if typeof(data["footprint"]) != TYPE_DICTIONARY:
		return _fail("字段类型错误：footprint 应为对象")
	var footprint: Dictionary = data["footprint"]
	var footprint_shape := _validate_object_keys(footprint, FOOTPRINT_FIELDS, FOOTPRINT_FIELDS, "footprint.")
	if footprint_shape != "":
		return _fail(footprint_shape)
	var width := _read_int(footprint["width"], "footprint.width")
	if not width.ok:
		return width
	var height := _read_int(footprint["height"], "footprint.height")
	if not height.ok:
		return height
	if int(width.value) < 1 or int(height.value) < 1:
		return _fail(
			"字段取值无效：footprint 的宽高必须大于 0，实际为 %d x %d"
			% [int(width.value), int(height.value)]
		)

	var cost_value := 0
	var cost_present := false
	if data.has("cost"):
		var cost_read := _read_int(data["cost"], "cost")
		if not cost_read.ok:
			return cost_read
		if int(cost_read.value) < 0:
			return _fail("字段取值无效：cost 不能为负，实际为 %d" % int(cost_read.value))
		cost_value = int(cost_read.value)
		cost_present = true

	var behavior := _empty_behavior()
	if data.has("behavior"):
		behavior = _parse_behavior(data["behavior"])
		if not behavior.ok:
			return behavior
		if not cost_present or cost_value < 1:
			return _fail("字段取值无效：有行为的建筑 cost 必须大于 0")

	var definition := BuildingDefinition.new()
	definition.id = id_text.value
	definition.schema_version = int(version.value)
	definition.display_name = building_name.value
	definition.description = description_text
	definition.scene_path = scene_value.value
	definition.icon_path = icon_text
	definition.sprite_path = sprite_text
	definition.footprint_width = int(width.value)
	definition.footprint_height = int(height.value)
	definition.cost = cost_value
	definition.has_cost = cost_present
	definition.behavior_type = str(behavior.type)
	definition.max_health = int(behavior.max_health)
	definition.attack_range = float(behavior.attack_range)
	definition.attack_interval = float(behavior.attack_interval)
	definition.attack_damage = int(behavior.attack_damage)
	definition.projectile_speed = float(behavior.projectile_speed)
	return {"ok": true, "error": "", "definition": definition}


static func _parse_behavior(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail("字段类型错误：behavior 应为对象")
	var behavior: Dictionary = value
	if not behavior.has("type"):
		return _fail("缺少字段：behavior.type")
	var type_read := _read_nonempty_string(behavior["type"], "behavior.type")
	if not type_read.ok:
		return type_read
	var behavior_type := str(type_read.value)
	var allowed: Array[String] = []
	if behavior_type == BEHAVIOR_BLOCKER:
		allowed = BLOCKER_FIELDS
	elif behavior_type == BEHAVIOR_RANGED:
		allowed = RANGED_FIELDS
	else:
		return _fail("未知行为类型：%s" % behavior_type)
	var shape_error := _validate_object_keys(behavior, allowed, allowed, "behavior.")
	if shape_error != "":
		return _fail(shape_error)

	var health := _read_int(behavior["max_health"], "behavior.max_health")
	if not health.ok:
		return health
	if int(health.value) < 1:
		return _fail("字段取值无效：behavior.max_health 必须大于 0，实际为 %d" % int(health.value))

	var result := _empty_behavior()
	result.ok = true
	result.type = behavior_type
	result.max_health = int(health.value)
	if behavior_type != BEHAVIOR_RANGED:
		return result

	var attack_range := _read_positive_number(behavior["range"], "behavior.range")
	if not attack_range.ok:
		return attack_range
	var interval := _read_positive_number(behavior["attack_interval"], "behavior.attack_interval")
	if not interval.ok:
		return interval
	var damage := _read_int(behavior["damage"], "behavior.damage")
	if not damage.ok:
		return damage
	if int(damage.value) < 1:
		return _fail("字段取值无效：behavior.damage 必须大于 0，实际为 %d" % int(damage.value))
	var speed := _read_positive_number(behavior["projectile_speed"], "behavior.projectile_speed")
	if not speed.ok:
		return speed
	result.attack_range = float(attack_range.value)
	result.attack_interval = float(interval.value)
	result.attack_damage = int(damage.value)
	result.projectile_speed = float(speed.value)
	return result


static func _empty_behavior() -> Dictionary:
	return {
		"ok": true,
		"error": "",
		"definition": null,
		"type": "",
		"max_health": 0,
		"attack_range": 0.0,
		"attack_interval": 0.0,
		"attack_damage": 0,
		"projectile_speed": 0.0,
	}


static func _validate_id(id_text: String) -> String:
	return ContentFields.validate_id(id_text)


static func _validate_object_keys(
	data: Dictionary,
	allowed: Array[String],
	required: Array[String],
	prefix: String
) -> String:
	return ContentFields.validate_keys(data, allowed, required, prefix)


static func _read_string(value: Variant, field_path: String) -> Dictionary:
	var read := ContentFields.read_string(value, field_path)
	if not read.ok:
		return _fail(str(read.error))
	return {"ok": true, "error": "", "value": read.value, "definition": null}


static func _read_nonempty_string(value: Variant, field_path: String) -> Dictionary:
	var read := ContentFields.read_nonempty_string(value, field_path)
	if not read.ok:
		return _fail(str(read.error))
	return {"ok": true, "error": "", "value": read.value, "definition": null}


static func _read_int(value: Variant, field_path: String) -> Dictionary:
	var read := ContentFields.read_int(value, field_path)
	if not read.ok:
		return _fail(str(read.error))
	return {"ok": true, "error": "", "value": read.value, "definition": null}


static func _read_positive_number(value: Variant, field_path: String) -> Dictionary:
	var read := ContentFields.read_positive_number(value, field_path)
	if not read.ok:
		return _fail(str(read.error))
	return {"ok": true, "error": "", "value": read.value, "definition": null}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "definition": null}
