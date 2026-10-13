class_name HealthPool
extends RefCounted

signal changed(current: int, maximum: int)
signal depleted

var current: int
var maximum: int
var init_error := ""


func _init(maximum_health: int) -> void:
	if maximum_health < 1:
		init_error = "生命值必须大于 0，实际为 %d" % maximum_health
		maximum = 0
		current = 0
		return
	maximum = maximum_health
	current = maximum_health


func apply_damage(amount: int) -> String:
	if init_error != "":
		return init_error
	if current <= 0:
		return "目标已经摧毁"
	if amount < 1:
		return "伤害必须大于 0，实际为 %d" % amount
	current -= amount
	if current < 0:
		current = 0
	changed.emit(current, maximum)
	if current == 0:
		depleted.emit()
	return ""
