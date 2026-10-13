class_name Blocker
extends Node

signal destroyed

var building_id := ""
var health: HealthPool


func setup(max_health: int, id_text: String) -> String:
	if id_text.is_empty():
		return "阻挡建筑缺少 id"
	if max_health < 1:
		return "阻挡建筑生命无效"
	building_id = id_text
	health = HealthPool.new(max_health)
	if health.init_error != "":
		return health.init_error
	health.depleted.connect(_on_depleted, CONNECT_ONE_SHOT)
	return ""


func apply_damage(amount: int) -> String:
	if health == null:
		return "阻挡建筑没有生命值"
	return health.apply_damage(amount)


func _on_depleted() -> void:
	destroyed.emit()
