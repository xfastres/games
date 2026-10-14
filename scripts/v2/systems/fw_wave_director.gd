class_name FwWaveDirector
extends Node

signal enemy_due(enemy_id: String)

var waves: Array = []
var next_wave_index := 0
var running := false
var _left := 0
var _wait := 0.0
var _interval := 0.0
var _enemy_id := ""


func reset(wave_list: Array) -> void:
	waves = wave_list.duplicate(true)
	next_wave_index = 0
	running = false
	_left = 0
	_wait = 0.0


func has_more() -> bool:
	return next_wave_index < waves.size()


func is_busy() -> bool:
	return running


func start_next() -> String:
	if running:
		return "当前波次还没结束"
	if not has_more():
		return "没有下一波"
	var wave: Dictionary = waves[next_wave_index]
	_enemy_id = str(wave["enemy_id"])
	_left = int(wave["count"])
	_interval = float(wave["spawn_interval"])
	if _left < 1 or _interval <= 0.0 or _enemy_id.is_empty():
		return "波次数据无效"
	next_wave_index += 1
	running = true
	_wait = 0.0
	return ""


func _physics_process(delta: float) -> void:
	if not running:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	enemy_due.emit(_enemy_id)
	_left -= 1
	if _left <= 0:
		running = false
		return
	_wait = _interval
