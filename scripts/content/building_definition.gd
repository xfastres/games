class_name BuildingDefinition
extends RefCounted

const SUPPORTED_SCHEMA_VERSION := 1
const ROOT_FIELDS: Array[String] = [
	"id",
	"schema_version",
	"name",
	"description",
	"scene",
	"icon",
	"footprint",
]
const REQUIRED_ROOT: Array[String] = ["id", "schema_version", "name", "scene", "footprint"]
const FOOTPRINT_FIELDS: Array[String] = ["width", "height"]

var id: String
var schema_version: int
var display_name: String
var description: String
var scene_path: String
var icon_path: String
var footprint_width: int
var footprint_height: int


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

	var definition := BuildingDefinition.new()
	definition.id = id_text.value
	definition.schema_version = int(version.value)
	definition.display_name = building_name.value
	definition.description = description_text
	definition.scene_path = scene_value.value
	definition.icon_path = icon_text
	definition.footprint_width = int(width.value)
	definition.footprint_height = int(height.value)
	return {"ok": true, "error": "", "definition": definition}


static func _validate_id(id_text: String) -> String:
	var parts := id_text.split(".")
	if parts.size() < 2:
		return "字段取值无效：id 必须是带命名空间的小写标识，例如 base.test_watchpost"
	for part in parts:
		if part.is_empty() or not _is_id_segment(part):
			return "字段取值无效：id 必须是带命名空间的小写标识，例如 base.test_watchpost"
	return ""


static func _is_id_segment(segment: String) -> bool:
	var first := segment.unicode_at(0)
	if first < 97 or first > 122:
		return false
	for index in range(1, segment.length()):
		var code := segment.unicode_at(index)
		var is_lower := code >= 97 and code <= 122
		var is_digit := code >= 48 and code <= 57
		if not (is_lower or is_digit or code == 95):
			return false
	return true


static func _validate_object_keys(
	data: Dictionary,
	allowed: Array[String],
	required: Array[String],
	prefix: String
) -> String:
	for key in required:
		if not data.has(key):
			return "缺少字段：%s%s" % [prefix, key]
	var unknown: Array[String] = []
	for key in data.keys():
		if typeof(key) != TYPE_STRING or not allowed.has(key):
			unknown.append(str(key))
	unknown.sort()
	if not unknown.is_empty():
		return "未知字段：%s%s" % [prefix, unknown[0]]
	return ""


static func _read_string(value: Variant, field_path: String) -> Dictionary:
	if typeof(value) != TYPE_STRING:
		return _fail("字段类型错误：%s 应为字符串" % field_path)
	return {"ok": true, "error": "", "value": value, "definition": null}


static func _read_nonempty_string(value: Variant, field_path: String) -> Dictionary:
	var read := _read_string(value, field_path)
	if not read.ok:
		return read
	var text := str(read.value).strip_edges()
	if text.is_empty():
		return _fail("字段取值无效：%s 不能为空" % field_path)
	return {"ok": true, "error": "", "value": text, "definition": null}


static func _read_int(value: Variant, field_path: String) -> Dictionary:
	if typeof(value) == TYPE_BOOL or (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT):
		return _fail("字段类型错误：%s 应为整数" % field_path)
	if typeof(value) == TYPE_FLOAT and not is_equal_approx(float(value), round(float(value))):
		return _fail("字段类型错误：%s 应为整数" % field_path)
	return {"ok": true, "error": "", "value": int(value), "definition": null}


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "definition": null}
