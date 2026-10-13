class_name EnemyDefinition
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const ROOT_FIELDS: Array[String] = [
	"id",
	"schema_version",
	"name",
	"scene",
	"sprite",
	"max_health",
	"move_speed",
	"contact_damage",
	"attack_interval",
	"gold_reward",
]
const REQUIRED_ROOT: Array[String] = [
	"id",
	"schema_version",
	"name",
	"scene",
	"max_health",
	"move_speed",
	"contact_damage",
	"attack_interval",
	"gold_reward",
]

var id: String
var schema_version: int
var display_name: String
var scene_path: String
var sprite_path: String
var max_health: int
var move_speed: float
var contact_damage: int
var attack_interval: float
var gold_reward: int


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
	var shape_error := ContentFields.validate_keys(data, ROOT_FIELDS, REQUIRED_ROOT, "")
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
	var enemy_name := ContentFields.read_nonempty_string(data["name"], "name")
	if not enemy_name.ok:
		return enemy_name
	var scene_value := ContentFields.read_string(data["scene"], "scene")
	if not scene_value.ok:
		return scene_value
	var scene_error := ResourcePath.validate_project_file(scene_value.value, "字段 scene", ".tscn")
	if scene_error != "":
		return ContentFields.fail(scene_error)
	var sprite_text := ""
	if data.has("sprite"):
		var sprite_value := ContentFields.read_string(data["sprite"], "sprite")
		if not sprite_value.ok:
			return sprite_value
		var sprite_error := ResourcePath.validate_project_file(sprite_value.value, "字段 sprite", ".png")
		if sprite_error != "":
			return ContentFields.fail(sprite_error)
		sprite_text = sprite_value.value
	var health := ContentFields.read_int(data["max_health"], "max_health")
	if not health.ok:
		return health
	if int(health.value) < 1:
		return ContentFields.fail("字段取值无效：max_health 必须大于 0，实际为 %d" % int(health.value))
	var speed := ContentFields.read_positive_number(data["move_speed"], "move_speed")
	if not speed.ok:
		return speed
	var damage := ContentFields.read_int(data["contact_damage"], "contact_damage")
	if not damage.ok:
		return damage
	if int(damage.value) < 1:
		return ContentFields.fail(
			"字段取值无效：contact_damage 必须大于 0，实际为 %d" % int(damage.value)
		)
	var interval := ContentFields.read_positive_number(data["attack_interval"], "attack_interval")
	if not interval.ok:
		return interval
	var reward := ContentFields.read_int(data["gold_reward"], "gold_reward")
	if not reward.ok:
		return reward
	if int(reward.value) < 0:
		return ContentFields.fail("字段取值无效：gold_reward 不能为负，实际为 %d" % int(reward.value))

	var definition := EnemyDefinition.new()
	definition.id = id_text.value
	definition.schema_version = int(version.value)
	definition.display_name = enemy_name.value
	definition.scene_path = scene_value.value
	definition.sprite_path = sprite_text
	definition.max_health = int(health.value)
	definition.move_speed = float(speed.value)
	definition.contact_damage = int(damage.value)
	definition.attack_interval = float(interval.value)
	definition.gold_reward = int(reward.value)
	return {"ok": true, "error": "", "definition": definition}
