extends RefCounted
const B = preload("res://scripts/balance.gd")
var number := 1
var elapsed := 0.0
var spawn_clock := 1.0
var escort_clock := 9.0
func next() -> void:
 number += 1
 elapsed = 0
 spawn_clock = 0.8
 escort_clock = 9
func step(dt: float, game) -> bool:
 elapsed += dt
 if number == 10:
  escort_clock -= dt
  if escort_clock <= 0:
   escort_clock = 9
   for i in range(3): game.spawn_enemy("runner" if i == 0 else "normal")
  return false
 spawn_clock -= dt
 if spawn_clock <= 0:
  spawn_clock = maxf(0.52, 2.1 - number * 0.16)
  var roll = game.rng.randf()
  var kind = "normal"
  if number >= 3 and roll < minf(0.28, number * 0.03): kind = "heavy"
  elif number >= 2 and roll > 0.7: kind = "runner"
  game.spawn_enemy(kind)
 return elapsed >= B.WAVE_SECONDS
