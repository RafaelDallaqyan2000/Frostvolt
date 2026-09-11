extends RefCounted
# Weapon logic of the classic mode, applied per mounted turret: every shot starts at that turret's barrel.
const C = preload("res://scripts/fortress/config.gd")
var projectiles: Array = []

func target_for(turret, enemies: Array, field_right: float):
 var best = null
 var best_distance := INF
 for enemy in enemies:
  if not turret.can_reach(enemy, field_right): continue
  var distance: float = turret.origin_toward(enemy.pos).distance_squared_to(enemy.pos)
  if distance < best_distance:
   best_distance = distance
   best = enemy
 return best

func step(dt: float, game) -> void:
 for turret in game.turrets:
  turret.cooldown = maxf(0, turret.cooldown - dt)
  turret.recoil = maxf(0, turret.recoil - dt)
  var target = target_for(turret, game.enemies, game.field_right)
  turret.has_target = target != null
  if target == null: continue
  turret.aim = (target.pos - turret.pivot).angle()
  if turret.cooldown > 0: continue
  turret.cooldown = 1.0 / turret.stats.rate
  turret.recoil = 0.09
  turret.shots += 1
  match turret.kind:
   "mg": fire_mg(game, turret, target)
   "cryo": fire_cryo(game, turret, target)
   "tesla": fire_tesla(game, turret, target)
 for i in range(projectiles.size() - 1, -1, -1):
  var shell: Dictionary = projectiles[i]
  shell.t = minf(1.0, shell.t + dt / shell.duration)
  shell.pos = shell_position(shell)
  if shell.t >= 1.0:
   projectiles.remove_at(i)
   cryo_explode(game, shell.to)

func fire_mg(game, turret, target) -> void:
 var from: Vector2 = turret.muzzle()
 target.hit(turret.stats.damage)
 game.add_effect("shot", from, target.pos, Color("f9db8b"), 0.08)
 game.add_effect("flash", from, from, Color("ffe7a8"), 0.07, 9)
 game.add_effect("hit", target.pos, target.pos, Color("ffd9a5"), 0.16, 8)
 game.play("shot")

# The shell leads its target and lands on a shallow arc; the blast is what deals damage.
func fire_cryo(game, turret, target) -> void:
 var from: Vector2 = turret.muzzle()
 var stats: Dictionary = turret.stats
 var duration: float = maxf(0.15, from.distance_to(target.pos) / stats.speed)
 var to: Vector2 = target.pos + target.velocity * duration
 to.y = clampf(to.y, -C.TOWER_EXTENT + 60, -6)
 projectiles.append({"from": from, "to": to, "pos": from, "t": 0.0, "duration": duration, "arc": minf(70.0, from.distance_to(to) * 0.16)})
 game.add_effect("flash", from, from, Color("aef1ff"), 0.1, 12)

static func shell_position(shell: Dictionary) -> Vector2:
 var t: float = shell.t
 return shell.from.lerp(shell.to, t) + Vector2(0, -shell.arc * 4.0 * t * (1.0 - t))

func cryo_explode(game, at: Vector2) -> Array:
 var stats: Dictionary = C.WEAPONS.cryo
 var hits := []
 for enemy in game.enemies:
  if enemy.hp > 0 and enemy.pos.distance_to(at) <= stats.radius + enemy.stats.size * 0.5:
   enemy.hit(stats.damage)
   enemy.slow = maxf(enemy.slow, stats.slow)
   hits.append(enemy)
 game.add_effect("ice", at, at, Color("6fe0ff"), 0.5, stats.radius)
 game.play("hit")
 return hits

# Each discharge visits every enemy at most once, jumping to the nearest unvisited one.
func fire_tesla(game, turret, first) -> Array:
 var stats: Dictionary = turret.stats
 var visited := []
 var target = first
 var origin: Vector2 = turret.origin_toward(first.pos)
 for i in range(stats.targets):
  if target == null: break
  visited.append(target)
  var chilled: bool = target.slow > 0
  target.hit(stats.damage * (stats.slowed_bonus if chilled else 1.0))
  var color := Color("b9fff5") if chilled else Color("b89aff")
  game.add_effect("bolt", origin, target.pos, color, 0.22)
  if chilled: game.add_effect("conduct", target.pos, target.pos, color, 0.6)
  origin = target.pos
  target = next_link(game, origin, stats.jump, visited)
 game.play("zap")
 return visited

func next_link(game, origin: Vector2, radius: float, visited: Array):
 var best = null
 var best_distance := radius * radius
 for enemy in game.enemies:
  if enemy.hp <= 0 or enemy in visited or enemy.pos.x > game.field_right: continue
  var distance := origin.distance_squared_to(enemy.pos)
  if distance <= best_distance:
   best_distance = distance
   best = enemy
 return best
