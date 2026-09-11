extends RefCounted
const B = preload("res://scripts/balance.gd")
var kind: String
var pos: Vector2
var hp: float
var max_hp: float
var slow := 0.0
var flash := 0.0
var attack := 0.0
var stats: Dictionary
func _init(type: String, position: Vector2, wave: int):
 kind = type
 pos = position
 stats = B.ENEMIES[type]
 max_hp = stats.hp * (1.0 + 0.035 * (wave - 1)) if type != "boss" else stats.hp
 hp = max_hp
func step(dt: float, center: Vector2, tower) -> void:
 slow = maxf(0, slow - dt)
 flash = maxf(0, flash - dt)
 attack -= dt
 if pos.distance_to(center) > 40 + stats.size:
  pos = pos.move_toward(center, stats.speed * (B.CRYO.factor if slow > 0 else 1.0) * dt)
 elif attack <= 0:
  tower.damage(stats.damage)
  attack = stats.interval
func hit(amount: float) -> void:
 hp -= amount
 flash = 0.1
