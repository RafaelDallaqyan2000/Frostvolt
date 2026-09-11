extends RefCounted
# Side-view attacker: walks along the road or flies to a point on the fortress front, then strikes on an interval.
const C = preload("res://scripts/fortress/config.gd")
var kind: String
var stats: Dictionary
var pos: Vector2
var goal: Vector2
var hp: float
var max_hp: float
var flying := false
var engaged := false
var slow := 0.0
var flash := 0.0
var attack := 0.0
var phase := 0.0
var warn := 0.0
var velocity := Vector2.ZERO

func _init(type: String, position: Vector2, target: Vector2, growth: float = 1.0) -> void:
 kind = type
 stats = C.ENEMIES[type]
 pos = position
 goal = target
 flying = stats.get("flying", false)
 max_hp = stats.hp * growth
 hp = max_hp
 attack = stats.interval * 0.4

func step(dt: float, game) -> void:
 slow = maxf(0, slow - dt)
 flash = maxf(0, flash - dt)
 var speed: float = stats.speed * (stats.get("slow_factor", C.WEAPONS.cryo.factor) if slow > 0 else 1.0)
 if not engaged:
  phase += dt * speed / 14.0
  var before := pos
  pos = pos.move_toward(goal, speed * dt)
  velocity = (pos - before) / dt if dt > 0 else Vector2.ZERO
  engaged = pos == goal
  return
 phase += dt * 3.0
 velocity = Vector2.ZERO
 attack -= dt
 if attack <= 0:
  attack = stats.interval
  game.damage_fortress(stats.damage, pos + Vector2(-stats.size, 0))

func hit(amount: float) -> float:
 var dealt := maxf(1.0, amount - stats.armor)
 hp -= dealt
 flash = 0.1
 return dealt
