extends Node2D
const HALL = preload("res://art/reactor_hall.png")
const CreatureVisual = preload("res://scripts/creature_visual.gd")
const CombatEffects = preload("res://scripts/combat_effects.gd")
var game
var creatures: Dictionary = {}
var fading: Array = []
var menu_time := 0.0
var foreground

func _ready() -> void:
 foreground = CombatEffects.new()
 foreground.game = game
 foreground.z_index = 10
 add_child(foreground)

func reset_visuals() -> void:
 for visual in creatures.values():
  remove_child(visual)
  visual.queue_free()
 for visual in fading:
  remove_child(visual)
  visual.queue_free()
 creatures.clear()
 fading.clear()
 position = Vector2.ZERO

func _process(dt: float) -> void:
 if game.state == game.State.MENU: menu_time += dt
 sync_creatures()
 if game.state in [game.State.RUNNING, game.State.VICTORY, game.State.GAME_OVER]:
  for i in range(fading.size() - 1, -1, -1):
   if fading[i].step_death(dt):
    fading[i].queue_free()
    fading.remove_at(i)
 var t: float = game.elapsed
 position = Vector2(sin(t * 87), cos(t * 103)) * game.impact_shake * 2.6
 if game.state == game.State.MENU: position = Vector2.ZERO
 queue_redraw()
 foreground.queue_redraw()

func sync_creatures() -> void:
 var present: Dictionary = {}
 for enemy in game.enemies:
  var id = enemy.get_instance_id()
  present[id] = true
  if not creatures.has(id):
   var visual = CreatureVisual.new()
   visual.enemy = enemy
   visual.game = game
   visual.z_index = 3
   creatures[id] = visual
   add_child(visual)
  creatures[id].sync()
 for id in creatures.keys():
  if not present.has(id):
   var visual = creatures[id]
   visual.die()
   fading.append(visual)
   creatures.erase(id)
 while fading.size() > 40:
  fading.pop_front().queue_free()

func _draw() -> void:
 var viewport_size = get_viewport_rect().size
 var c: Vector2 = game.center
 var t: float = menu_time if game.state == game.State.MENU else game.elapsed
 draw_rect(Rect2(Vector2.ZERO, viewport_size), Color("061018"))
 # Keep the floor circle round on taller phones; crop/extend the dark borders.
 var width = maxf(viewport_size.x, viewport_size.y * HALL.get_width() / HALL.get_height())
 var height = width * HALL.get_height() / HALL.get_width()
 var destination = Rect2(c - Vector2(width * 0.5, height * 0.48), Vector2(width, height))
 draw_texture_rect(HALL, destination, false, Color(0.90, 0.98, 1.0))
 # Slow ground haze, travelling conduit lights and drifting sparks.
 for i in range(10):
  var phase = t * 0.035 + i * 0.61
  var p = c + Vector2(sin(phase) * 240, cos(phase * 0.73 + i) * 290)
  draw_circle(p, 65 + 12 * sin(phase), Color(0.13, 0.6, 0.64, 0.008))
 for axis in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
  for segment in range(3):
   var phase = fmod(t * 34 + segment * 110, 330.0)
   var p = c + axis * (60 + phase)
   draw_line(p, p + axis * 18, Color(0.32, 0.96, 0.75, 0.1), 5, true)
 for i in range(24):
  var cycle = fmod(t * (8 + i % 5) + i * 49.0, 580.0)
  var p = c + Vector2(sin(i * 28.31) * 280 + sin(t * 0.4 + i) * 10, 290 - cycle)
  var alpha = sin(cycle / 580 * PI) * 0.28
  draw_circle(p, 1.1 + i % 2, Color(0.48, 0.86, 0.77, alpha))
 for i in range(2):
  var angle = t * (0.18 if i == 0 else -0.12) + i * PI
  draw_arc(c, 103 + i * 15, angle, angle + PI * 0.55, 30, Color(0.33, 0.89, 0.68, 0.2), 1.8, true)
 # Opaque HUD backing keeps floor detail from competing with Russian text.
 var upper = 312.0 if game.boss != null and game.state == game.State.RUNNING else 255.0
 if game.state == game.State.MENU: upper = 390.0
 for strip in range(16):
  var y = upper - 48 + strip * 3
  draw_rect(Rect2(0, y, viewport_size.x, 3), Color(0.02, 0.045, 0.07, (1.0 - strip / 16.0) * 0.9))
 draw_rect(Rect2(0, 0, viewport_size.x, upper - 48), Color(0.02, 0.045, 0.07, 0.9))
 draw_rect(Rect2(0, viewport_size.y - 175, viewport_size.x, 175), Color(0.02, 0.045, 0.07, 0.93))
