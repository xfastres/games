class_name WaveSpawner
extends RefCounted

var waves: Array = []
var next_wave_index := 0
var active := false
var stopped := false
var _left := 0
var _interval := 0.0
var _cooldown := 0.0
var _pending := false
var _enemy_id := ""


func has_more() -> bool:
	return next_wave_index < waves.size()


func is_busy() -> bool:
	return active


func all_waves_committed() -> bool:
	return not has_more() and not active


func start_next() -> Dictionary:
	if stopped:
		return _fail("战斗已经结束")
	if active:
		return _fail("当前波次还在出兵")
	if not has_more():
		return _fail("没有更多波次")
	var wave: Dictionary = waves[next_wave_index]
	var count := int(wave["count"])
	if count < 1:
		return _fail("波次数量无效")
	next_wave_index += 1
	_left = count
	_interval = float(wave["spawn_interval"])
	_enemy_id = str(wave["enemy_id"])
	_cooldown = 0.0
	_pending = false
	active = true
	return {"ok": true, "error": "", "wave_number": next_wave_index, "enemy_id": _enemy_id}


func poll(delta: float) -> String:
	if stopped or not active:
		return ""
	if not _pending:
		_cooldown -= delta
		if _left <= 0:
			active = false
			return ""
		if _cooldown > 0.0:
			return ""
		_pending = true
	return _enemy_id


func commit_spawn() -> void:
	if not _pending:
		push_error("没有待生成的敌人，不能确认出兵")
		return
	_pending = false
	_left -= 1
	_cooldown = _interval
	if _left <= 0:
		active = false
		_cooldown = 0.0


func stop() -> void:
	stopped = true
	active = false
	_pending = false
	_left = 0


func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message, "wave_number": next_wave_index, "enemy_id": ""}
