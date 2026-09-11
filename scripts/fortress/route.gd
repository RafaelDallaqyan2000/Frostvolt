extends RefCounted
# Level progression: depot (0), three regular segments (1..3) and the carrier fight (4).
const C = preload("res://scripts/fortress/config.gd")
var stage := 0
var clock := 0.0
var spawn_clock := 0.0
var summon_clock := 0.0
var pack_clock := 0.0
var queued := 0
var distance := 0.0
var spawned := 0

func begin(next: int) -> void:
 stage = next
 clock = 0
 spawn_clock = 0.6
 pack_clock = 0
 queued = 0
 summon_clock = C.BOSS.summon_every

func is_boss() -> bool:
 return stage > C.SEGMENTS.size()

# The carrier blocks the road, so the boss fight happens standing still.
func rolling() -> bool:
 return stage >= 1 and not is_boss()

func progress() -> float:
 return clampf(distance / C.route_length(), 0, 1)

func step(dt: float, game) -> bool:
 clock += dt
 if rolling(): distance += C.SPEED * dt
 if is_boss():
  var boss = game.boss
  if boss == null or boss.hp <= 0: return false
  summon_clock -= dt
  boss.warn = summon_clock if summon_clock <= C.BOSS.warning else 0.0
  if summon_clock <= 0:
   summon_clock = C.BOSS.summon_every
   boss.warn = 0.0
   game.summon(boss)
  return false
 var segment: Dictionary = C.SEGMENTS[stage - 1]
 if clock < C.SEGMENT_SECONDS * C.SPAWN_CUTOFF:
  spawn_clock -= dt
  if spawn_clock <= 0:
   spawn_clock += segment.every
   queued += game.rng.randi_range(segment.pack.x, segment.pack.y)
 if queued > 0:
  pack_clock -= dt
  if pack_clock <= 0:
   pack_clock = C.PACK_GAP
   queued -= 1
   if game.spawn_enemy(pick(segment.mix, game.rng)) != null: spawned += 1
 return clock >= C.SEGMENT_SECONDS

static func pick(mix: Dictionary, rng: RandomNumberGenerator) -> String:
 var total := 0.0
 for kind in mix: total += mix[kind]
 var roll := rng.randf() * total
 for kind in mix:
  roll -= mix[kind]
  if roll <= 0: return kind
 return mix.keys()[0]
