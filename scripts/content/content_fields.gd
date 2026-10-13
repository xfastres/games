class_name ContentFields
extends RefCounted

## Shared JSON field checks. Error text stays stable so content tests can match it.


static func fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "definition": null, "config": null}


static func validate_id(id_text: String) -> String:
	var parts := id_text.split(".")
	if parts.size() < 2:
		return "字段取值无效：id 必须是带命名空间的小写标识，例如 base.test_watchpost"
	for part in parts:
		if part.is_empty() or not _is_id_segment(part):
			return "字段取值无效：id 必须是带命名空间的小写标识，例如 base.test_watchpost"
	return ""


static func validate_keys(
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


static func read_string(value: Variant, field_path: String) -> Dictionary:
	if typeof(value) != TYPE_STRING:
		return fail("字段类型错误：%s 应为字符串" % field_path)
	return {"ok": true, "error": "", "value": value}


static func read_nonempty_string(value: Variant, field_path: String) -> Dictionary:
	var read := read_string(value, field_path)
	if not read.ok:
		return read
	var text := str(read.value).strip_edges()
	if text.is_empty():
		return fail("字段取值无效：%s 不能为空" % field_path)
	return {"ok": true, "error": "", "value": text}


static func read_int(value: Variant, field_path: String) -> Dictionary:
	if typeof(value) == TYPE_BOOL or (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT):
		return fail("字段类型错误：%s 应为整数" % field_path)
	if typeof(value) == TYPE_FLOAT and not is_equal_approx(float(value), round(float(value))):
		return fail("字段类型错误：%s 应为整数" % field_path)
	return {"ok": true, "error": "", "value": int(value)}


static func read_positive_number(value: Variant, field_path: String) -> Dictionary:
	if typeof(value) == TYPE_BOOL or (typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT):
		return fail("字段类型错误：%s 应为数字" % field_path)
	var number := float(value)
	if is_nan(number) or is_inf(number) or number <= 0.0:
		return fail("字段取值无效：%s 必须大于 0，实际为 %s" % [field_path, str(value)])
	return {"ok": true, "error": "", "value": number}


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
