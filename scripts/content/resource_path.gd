class_name ResourcePath
extends RefCounted

const PREFIX := "res://"

## Returns an empty string when the path is a safe project file, otherwise a player-facing error.
static func validate_project_file(path: String, field_label: String, suffix: String) -> String:
	if typeof(path) != TYPE_STRING:
		return "拒绝读取：%s 必须是字符串路径" % field_label
	if not path.begins_with(PREFIX):
		return "拒绝读取：%s 必须位于 res:// 内，实际为 %s" % [field_label, path]
	var relative := path.substr(PREFIX.length())
	if relative.is_empty() or relative.begins_with("/") or relative.ends_with("/"):
		return "拒绝读取：%s 不是文件路径" % field_label
	var parts := relative.split("/")
	for part in parts:
		if part.is_empty() or part == "." or part == "..":
			return "拒绝读取：%s 不能包含空目录或上级目录" % field_label
		if not _is_safe_segment(part):
			return "拒绝读取：%s 包含不允许的字符" % field_label
	if suffix != "" and not path.ends_with(suffix):
		return "拒绝读取：%s 必须以 %s 结尾" % [field_label, suffix]
	if not FileAccess.file_exists(path):
		return "资源不存在：%s" % path
	return ""


static func _is_safe_segment(segment: String) -> bool:
	if segment.is_empty():
		return false
	for index in segment.length():
		var code := segment.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_upper := code >= 65 and code <= 90
		var is_lower := code >= 97 and code <= 122
		var is_extra := code == 45 or code == 46 or code == 95
		if not (is_digit or is_upper or is_lower or is_extra):
			return false
	return true
