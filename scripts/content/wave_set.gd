class_name WaveSet
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const ROOT_FIELDS: Array[String] = ["id", "schema_version", "waves"]
const WAVE_FIELDS: Array[String] = ["enemy_id", "count", "spawn_interval"]
const MAX_WAVES := 10
const MAX_WAVE_COUNT := 30

var id: String
var schema_version: int
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
	if typeof(data["waves"]) != TYPE_ARRAY:
		return ContentFields.fail("字段类型错误：waves 应为数组")
	var source: Array = data["waves"]
	if source.is_empty():
		return ContentFields.fail("波次不能为空")
	if source.size() > MAX_WAVES:
		return ContentFields.fail("波次过多：%d，阶段 1 最多 %d 波" % [source.size(), MAX_WAVES])

	var waves: Array = []
	for index in source.size():
		var parsed := _parse_wave(source[index], index)
		if not parsed.ok:
			return parsed
		waves.append(parsed.wave)

	var definition := WaveSet.new()
	definition.id = id_text.value
	definition.schema_version = int(version.value)
	definition.waves = waves
	return {"ok": true, "error": "", "definition": definition}


static func _parse_wave(value: Variant, index: int) -> Dictionary:
	var prefix := "waves[%d]." % index
	if typeof(value) != TYPE_DICTIONARY:
		return ContentFields.fail("字段类型错误：waves[%d] 应为对象" % index)
	var wave: Dictionary = value
	var shape_error := ContentFields.validate_keys(wave, WAVE_FIELDS, WAVE_FIELDS, prefix)
	if shape_error != "":
		return ContentFields.fail(shape_error)
	var enemy_id := ContentFields.read_nonempty_string(wave["enemy_id"], prefix + "enemy_id")
	if not enemy_id.ok:
		return enemy_id
	var id_error := ContentFields.validate_id(enemy_id.value)
	if id_error != "":
		return ContentFields.fail(id_error)
	var count := ContentFields.read_int(wave["count"], prefix + "count")
	if not count.ok:
		return count
	if int(count.value) < 1 or int(count.value) > MAX_WAVE_COUNT:
		return ContentFields.fail(
			"字段取值无效：%scount 必须在 1 到 %d 之间，实际为 %d"
			% [prefix, MAX_WAVE_COUNT, int(count.value)]
		)
	var interval := ContentFields.read_positive_number(wave["spawn_interval"], prefix + "spawn_interval")
	if not interval.ok:
		return interval
	return {
		"ok": true,
		"error": "",
		"wave": {
			"enemy_id": enemy_id.value,
			"count": int(count.value),
			"spawn_interval": float(interval.value),
		},
	}
