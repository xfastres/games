class_name ContentLoader
extends RefCounted

## Loads built-in JSON content. This is not a mod scanner and does not execute scripts.
static func load_building(path: String) -> Dictionary:
	var read := _read_text(path)
	if not read.ok:
		return {"ok": false, "error": read.error, "definition": null}
	return BuildingDefinition.parse_text(read.text)


static func load_enemy(path: String) -> Dictionary:
	var read := _read_text(path)
	if not read.ok:
		return {"ok": false, "error": read.error, "definition": null}
	return EnemyDefinition.parse_text(read.text)


static func load_wave_set(path: String) -> Dictionary:
	var read := _read_text(path)
	if not read.ok:
		return {"ok": false, "error": read.error, "definition": null}
	return WaveSet.parse_text(read.text)


static func load_defense_match(path: String) -> Dictionary:
	var read := _read_text(path)
	if not read.ok:
		return {"ok": false, "error": read.error, "config": null}
	return DefenseMatchConfig.parse_text(read.text)


static func _read_text(path: String) -> Dictionary:
	var path_error := ResourcePath.validate_project_file(path, "配置文件", ".json")
	if path_error != "":
		return {"ok": false, "error": path_error, "text": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"error": "无法读取配置：%s（%s）" % [path, error_string(FileAccess.get_open_error())],
			"text": "",
		}
	var text := file.get_as_text()
	file.close()
	return {"ok": true, "error": "", "text": text}
