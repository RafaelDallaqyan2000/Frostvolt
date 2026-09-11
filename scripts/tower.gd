extends RefCounted
const B = preload("res://scripts/balance.gd")
var max_hp: float = B.HEALTH
var hp: float = B.HEALTH
var levels: Dictionary = {}
func level(id: String) -> int:
 return int(levels.get(id, 0))
func damage(amount: float) -> void:
 hp = maxf(0, hp - amount)
