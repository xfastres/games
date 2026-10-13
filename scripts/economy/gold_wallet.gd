class_name GoldWallet
extends RefCounted

var amount: int
var init_error := ""


func _init(starting: int) -> void:
	if starting < 0:
		init_error = "初始金币不能为负：%d" % starting
		amount = 0
		return
	amount = starting


func can_afford(cost: int) -> bool:
	return init_error == "" and cost >= 0 and amount >= cost


func try_spend(cost: int) -> Dictionary:
	if init_error != "":
		return {"ok": false, "error": init_error}
	if cost < 0:
		return {"ok": false, "error": "造价不能为负，实际为 %d" % cost}
	if amount < cost:
		return {"ok": false, "error": "金币不足：需要 %d，当前 %d" % [cost, amount]}
	amount -= cost
	return {"ok": true, "error": ""}


func add(reward: int) -> String:
	if init_error != "":
		return init_error
	if reward < 0:
		return "金币奖励不能为负，实际为 %d" % reward
	amount += reward
	return ""
