extends Node2D
var game
const MINT = Color("78efce")
const ICE = Color("71dfff")
const INK = Color("08111f")

func polygon_points(at: Vector2, radius: float, count: int, rotation: float = 0.0) -> PackedVector2Array:
 var points := PackedVector2Array()
 for i in range(count): points.append(at + Vector2.from_angle(rotation + TAU * i / count) * radius)
 return points

func _draw() -> void:
 var size = get_viewport_rect().size
 var c: Vector2 = game.center
 var t: float = game.elapsed
 draw_rect(Rect2(Vector2.ZERO, size), INK)
 # Layered flat shapes give a soft halo without renderer-specific glow.
 for i in range(12, 0, -1):
  draw_circle(c, 52 + i * 22, Color(0.08, 0.3, 0.28, 0.022))
 for x in range(0, int(size.x), 48):
  draw_line(Vector2(x, 260), Vector2(x, size.y - 185), Color(0.2, 0.4, 0.48, 0.075), 1)
 for y in range(272, int(size.y - 180), 48):
  draw_line(Vector2(20, y), Vector2(size.x - 20, y), Color(0.2, 0.4, 0.48, 0.075), 1)
 for r in [125, 235, 330]: draw_arc(c, r, 0, TAU, 100, Color(0.32, 0.75, 0.66, 0.075), 1.4, true)
 for i in range(12):
  var a = TAU * i / 12
  draw_line(c + Vector2.from_angle(a) * 225, c + Vector2.from_angle(a) * 235, Color(0.3, 0.75, 0.65, 0.18), 2, true)
 # Four quiet perimeter markers.
 for corner in [game.arena_rect.position, Vector2(game.arena_rect.end.x, game.arena_rect.position.y), game.arena_rect.end, Vector2(game.arena_rect.position.x, game.arena_rect.end.y)]:
  var direction: Vector2 = (c - corner).sign()
  draw_line(corner, corner + Vector2(direction.x * 24, 0), Color("284c51"), 3)
  draw_line(corner, corner + Vector2(0, direction.y * 24), Color("284c51"), 3)
 if game.state == game.State.RUNNING:
  var range_radius = game.B.MG.range * (1 + 0.1 * game.tower.level("range"))
  draw_arc(c, range_radius, -0.35, 0.35, 32, Color(0.4, 0.9, 0.73, 0.15), 2, true)
 for enemy in game.enemies: draw_enemy(enemy)
 draw_reactor(c, t)
 for projectile in game.weapons.projectiles:
  draw_circle(projectile.pos, 14, Color(0.35, 0.8, 1, 0.13))
  draw_circle(projectile.pos, 6, ICE)
  draw_circle(projectile.pos, 2.5, Color.WHITE)
 for effect in game.effects: draw_effect(effect)

func draw_reactor(c: Vector2, t: float) -> void:
 var aim: Vector2 = game.weapons.last_aim
 draw_circle(c + Vector2(0, 8), 72, Color(0, 0, 0, 0.35))
 draw_colored_polygon(polygon_points(c, 69, 6, PI / 6), Color("152633"))
 draw_polyline(close_polygon(polygon_points(c, 69, 6, PI / 6)), Color("31564f"), 2, true)
 draw_circle(c, 48, Color("0a181f"))
 draw_arc(c, 53, t * 0.3, t * 0.3 + PI * 1.6, 64, Color("418f7a"), 3, true)
 for i in range(4):
  var p = c + Vector2.from_angle(PI / 4 + i * PI / 2) * 61
  draw_circle(p, 4, MINT)
 draw_line(c + aim * 25, c + aim * 78, Color("345951"), 13, true)
 draw_line(c + aim * 25, c + aim * 78, Color("a1cab8"), 5, true)
 if game.tower.level("cryo") > 0:
  var p = c + Vector2(-48, 16)
  draw_colored_polygon(polygon_points(p, 17, 6), Color("246578"))
  draw_circle(p, 7, ICE)
 if game.tower.level("tesla") > 0:
  var p = c + Vector2(48, 16)
  draw_circle(p, 17, Color("514174"))
  draw_arc(p, 11, 0, TAU, 24, Color("c6a6ff"), 3, true)
 var pulse = 0.7 + 0.3 * sin(t * 2.2)
 for i in range(5, 0, -1): draw_circle(c, 29 + i * 5, Color(0.27, 1.0, 0.69, 0.045 * pulse))
 draw_colored_polygon(polygon_points(c, 31, 6, PI / 6), Color("337e68"))
 draw_colored_polygon(polygon_points(c, 22, 6, PI / 6), MINT)
 draw_colored_polygon(polygon_points(c, 11, 6, PI / 6), Color("ddfff0"))

func close_polygon(points: PackedVector2Array) -> PackedVector2Array:
 points.append(points[0])
 return points

func draw_enemy(enemy) -> void:
 var p: Vector2 = enemy.pos
 var r: float = enemy.stats.size
 var color: Color = ICE if enemy.slow > 0 else enemy.stats.color
 if enemy.flash > 0: color = Color.WHITE
 draw_circle(p + Vector2(0, 5), r + 3, Color(0, 0, 0, 0.28))
 var sides = 3 if enemy.kind == "runner" else (4 if enemy.kind == "heavy" else 6)
 if enemy.kind == "boss": sides = 8
 var angle = (game.center - p).angle()
 var points = polygon_points(p, r, sides, angle)
 draw_colored_polygon(points, color.darkened(0.65))
 draw_polyline(close_polygon(points), color, 2.3, true)
 draw_circle(p, r * 0.27, color)
 if enemy.kind in ["heavy", "boss"]:
  draw_arc(p, r * 0.65, 0, TAU, 24, color.darkened(0.25), 2, true)
 if enemy.slow > 0:
  draw_arc(p, r + 6, 0, TAU, 24, Color(0.4, 0.83, 1, 0.45), 1, true)
  draw_line(p + Vector2(-5, -r - 9), p + Vector2(5, -r - 9), ICE, 2)
 if enemy.hp < enemy.max_hp and enemy.kind != "boss":
  draw_rect(Rect2(p + Vector2(-r, r + 8), Vector2(r * 2, 3)), Color("243343"))
  draw_rect(Rect2(p + Vector2(-r, r + 8), Vector2(r * 2 * maxf(0, enemy.hp / enemy.max_hp), 3)), color)

func draw_effect(effect: Dictionary) -> void:
 var alpha: float = effect.left / effect.duration
 var progress = 1.0 - alpha
 var color: Color = effect.color
 color.a = alpha
 var p: Vector2 = effect.from
 match effect.kind:
  "shot": draw_line(p, effect.to, color, 2.5, true)
  "bolt":
   var points := PackedVector2Array([p])
   var normal = (effect.to - p).normalized().orthogonal()
   for i in range(1, 6):
    points.append(p.lerp(effect.to, i / 6.0) + normal * (10 if i % 2 == 0 else -10))
   points.append(effect.to)
   draw_polyline(points, Color(color, alpha * 0.2), 11, true)
   draw_polyline(points, color, 3, true)
  "ice":
   draw_circle(p, effect.radius * progress, Color(color, alpha * 0.12))
   draw_arc(p, effect.radius * progress, 0, TAU, 48, color, 3, true)
  "conduct":
   draw_string(ThemeDB.fallback_font, p + Vector2(-22, -28 - 25 * progress), "+30%", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
  _:
   for i in range(6):
    var offset = Vector2.from_angle(i * TAU / 6) * (8 + progress * effect.radius * 1.8)
    draw_circle(p + offset, 3 * alpha + 1, color)
