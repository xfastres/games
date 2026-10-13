class_name ContentLoader
extends RefCounted

## Loads one built-in building file. This is not a mod scanner and does not execute scripts.
static func load_building(path: String) -> Dictionary:
	var path_error := ResourcePath.validate_project_file(path, "配置文件", ".json")
	if path_error != "":
		return {"ok": false, "error": path_error, "definition": null}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error": "无法读取配置：%s（%s）" % [path, error_string(FileAccess.get_open_error())],
			"definition": null,
		}
	var text := file.get_as_text()
	file.close()
	return BuildingDefinition.parse_text(text)
