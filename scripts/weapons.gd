extends RefCounted
const B = preload("res://scripts/balance.gd")
var cooldowns := {"mg": 0.0, "cryo": 0.0, "tesla": 0.0}
var projectiles: Array = []
var last_aim := Vector2.UP
var kick := 0.0

func nearest(enemies: Array, origin: Vector2, radius: float, excluded: Array = []):
 var target = null
 var distance_sq = radius * radius
 for enemy in enemies:
  if enemy.hp <= 0 or enemy in excluded: continue
  var candidate = origin.distance_squared_to(enemy.pos)
  if candidate <= distance_sq:
   distance_sq = candidate
   target = enemy
 return target

func step(dt: float, game) -> void:
 kick = maxf(0, kick - dt * 14)
 var tower = game.tower
 for key in cooldowns: cooldowns[key] = maxf(0, cooldowns[key] - dt)
 var mg_target = nearest(game.enemies, game.center, B.MG.range * (1 + 0.1 * tower.level("range")))
 if mg_target != null:
  last_aim = (mg_target.pos - game.center).normalized()
  if cooldowns.mg <= 0:
   cooldowns.mg = 1.0 / (B.MG.rate * (1 + 0.15 * tower.level("rate")))
   mg_target.hit(B.MG.damage * (1 + 0.2 * tower.level("damage")))
   kick = 1.0
   game.add_effect("shot", game.center + last_aim * 74, mg_target.pos, Color("f9db8b"), 0.09)
   game.add_effect("muzzle", game.center + last_aim * 74, mg_target.pos, Color("ffe7a1"), 0.09)
   game.add_effect("hit", mg_target.pos, mg_target.pos, Color("ffd9a5"), 0.16)
   game.sound.play_sound("shot")
 if tower.level("cryo") > 0 and cooldowns.cryo <= 0:
  var target = nearest(game.enemies, game.center, B.CRYO.range)
  if target != null:
   cooldowns.cryo = 1.0 / B.CRYO.rate
   projectiles.append({"pos": game.center, "destination": target.pos, "life": 2.0})
 if tower.level("tesla") > 0 and cooldowns.tesla <= 0:
  var target = nearest(game.enemies, game.center, B.TESLA.range)
  if target != null:
   cooldowns.tesla = 1.0 / B.TESLA.rate
   fire_tesla(game, target)
 for i in range(projectiles.size() - 1, -1, -1):
  var projectile = projectiles[i]
  projectile.life -= dt
  projectile.pos = projectile.pos.move_toward(projectile.destination, B.CRYO.speed * dt)
  if projectile.pos.distance_to(projectile.destination) < 1:
   cryo_explode(game, projectile.destination)
   projectiles.remove_at(i)
  elif projectile.life <= 0: projectiles.remove_at(i)

func cryo_explode(game, position: Vector2) -> void:
 var damage = B.CRYO.damage * (1 + 0.25 * (game.tower.level("cryo") - 1))
 var duration = B.CRYO.slow + 0.5 * game.tower.level("slow")
 for enemy in game.enemies:
  if enemy.hp > 0 and enemy.pos.distance_to(position) <= B.CRYO.radius:
   enemy.hit(damage)
   enemy.slow = maxf(enemy.slow, duration)
 game.add_effect("ice", position, position, Color("6fe0ff"), 0.5, B.CRYO.radius)
 game.impact_shake = maxf(game.impact_shake, 0.24)
 game.sound.play_sound("hit")

func fire_tesla(game, first) -> Array:
 var visited: Array = []
 var target = first
 var origin: Vector2 = game.center
 var base_damage = B.TESLA.damage * (1 + 0.25 * (game.tower.level("tesla") - 1))
 for i in range(B.TESLA.targets + game.tower.level("chain")):
  if target == null: break
  visited.append(target)
  var conductive: bool = target.slow > 0 and game.tower.level("conduct") > 0
  target.hit(base_damage * (1.3 if conductive else 1.0))
  var color = Color("b9fff5") if conductive else Color("b89aff")
  game.add_effect("bolt", origin, target.pos, color, 0.24)
  if conductive:
   game.add_effect("conduct", target.pos, target.pos, color, 0.65)
   game.conductive_hits += 1
  origin = target.pos
  target = nearest(game.enemies, origin, B.TESLA.jump, visited)
 return visited
