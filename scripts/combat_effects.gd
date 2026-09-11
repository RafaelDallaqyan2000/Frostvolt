extends Node2D
const MINT = Color("78efce")
const ICE = Color("71dfff")
var game

func points(at: Vector2, radius: float, count: int, angle: float = 0.0) -> PackedVector2Array:
 var output := PackedVector2Array()
 for i in range(count): output.append(at + Vector2.from_angle(angle + TAU * i / count) * radius)
 return output

func outline(polygon: PackedVector2Array) -> PackedVector2Array:
 polygon.append(polygon[0])
 return polygon

func _draw() -> void:
 var t: float = game.arena.menu_time if game.state == game.State.MENU else game.elapsed
 draw_reactor(game.center, t)
 for projectile in game.weapons.projectiles:
  var direction: Vector2 = (projectile.destination - projectile.pos).normalized()
  for i in range(5):
   draw_circle(projectile.pos - direction * i * 7, 7.0 - i, Color(0.28, 0.77, 1.0, 0.25 - i * 0.04))
  draw_circle(projectile.pos, 13, Color(0.28, 0.77, 1.0, 0.12))
  draw_circle(projectile.pos, 5, ICE)
  draw_circle(projectile.pos, 2.5, Color.WHITE)
 for effect in game.effects: draw_effect(effect)

func draw_reactor(c: Vector2, t: float) -> void:
 var aim: Vector2 = game.weapons.last_aim
 if game.state == game.State.MENU: aim = Vector2.from_angle(-PI / 2 + sin(t * 0.45) * 0.35)
 var pulse = 0.5 + 0.5 * sin(t * 2.6)
 var startup = clampf(game.elapsed / 0.7, 0.0, 1.0) if game.state != game.State.MENU else 1.0
 var damage: float = game.damage_glow
 draw_circle(c + Vector2(0, 9), 77, Color(0, 0, 0, 0.5))
 var base = points(c, 73, 8, PI / 8)
 draw_colored_polygon(base, Color("1a3037"))
 draw_polyline(outline(base), Color("60847c"), 2.4, true)
 draw_circle(c, 62, Color("07151a"))
 for i in range(3):
  var angle = t * 0.45 + TAU * i / 3.0
  draw_arc(c, 62, angle, angle + 1.25, 28, MINT.darkened(0.35), 3.5, true)
  draw_circle(c + Vector2.from_angle(angle) * 62, 3, MINT)
 for i in range(8):
  var angle = PI / 8 + i * TAU / 8
  var p = c + Vector2.from_angle(angle) * 68
  draw_circle(p, 3.3, Color("b1d2be") if i % 2 == 0 else Color("385949"))
 # Mechanical barrel kick and a rotating magnetic bearing.
 var recoil: float = game.weapons.kick * 9.0
 var base_point = c + aim * 23
 var tip = c + aim * (83 - recoil)
 draw_line(base_point + Vector2(0, 3), tip + Vector2(0, 3), Color("030a10"), 17, true)
 draw_line(base_point, tip, Color("40645e"), 15, true)
 draw_line(base_point + aim.orthogonal() * 3, tip + aim.orthogonal() * 3, Color("b1cfc2"), 4, true)
 draw_line(tip - aim * 12, tip, Color("e5e0bf"), 6, true)
 if game.tower.level("cryo") > 0:
  var p = c + Vector2(-52, 21)
  draw_circle(p, 20, Color("13222c"))
  draw_polyline(outline(points(p, 17, 6, t * 0.5)), Color("428cb0"), 3, true)
  draw_circle(p, 9, ICE.darkened(0.3))
  draw_circle(p, 5 + pulse, ICE)
  for i in range(3): draw_circle(p + Vector2.from_angle(t * 2 + i * TAU / 3) * 13, 2, Color.WHITE)
 if game.tower.level("tesla") > 0:
  var p = c + Vector2(52, 21)
  draw_circle(p, 20, Color("241d3d"))
  for ring in range(3): draw_arc(p, 6 + ring * 4, t * (ring + 1), t * (ring + 1) + PI * 1.5, 24, Color("b697f9"), 1.8, true)
  draw_circle(p, 4, Color("e9ddff"))
 for i in range(7, 0, -1):
  draw_circle(c, 28 + i * 5 + pulse * 2, Color(0.20, 1.0, 0.66, (0.025 + 0.022 * pulse) * startup))
 draw_colored_polygon(points(c, 36, 6, PI / 6), Color("184d44"))
 draw_polyline(outline(points(c, 36, 6, PI / 6)), MINT, 2, true)
 draw_colored_polygon(points(c, 26 + pulse, 6, PI / 6), MINT.lerp(Color("ff7d62"), damage))
 draw_colored_polygon(points(c, 13 + pulse * 2, 6, -t * 0.3), Color("e0fff1"))
 draw_arc(c, 46, -t * 0.55, -t * 0.55 + PI * 1.55, 48, Color("55aa8c"), 2, true)
 if damage > 0:
  draw_arc(c, 85 + (1 - damage) * 18, 0, TAU, 64, Color(1, 0.35, 0.22, damage * 0.65), 3, true)

func draw_effect(effect: Dictionary) -> void:
 var alpha: float = clampf(effect.left / effect.duration, 0, 1)
 if alpha < 0.015: return
 var progress = 1.0 - alpha
 var color: Color = effect.color
 color.a = alpha
 var p: Vector2 = effect.from
 match effect.kind:
  "shot":
   draw_line(p, effect.to, Color(color, alpha * 0.15), 9, true)
   draw_line(p, effect.to, color, 2.2, true)
  "muzzle":
   var direction: Vector2 = (effect.to - p).normalized()
   draw_colored_polygon(PackedVector2Array([p + direction.orthogonal() * 6 * alpha, p + direction * 26 * alpha, p - direction.orthogonal() * 6 * alpha, p - direction * 4]), color)
   draw_circle(p, 16 * alpha, Color(1, 0.76, 0.3, alpha * 0.15))
  "bolt":
   var path := PackedVector2Array([p])
   var normal = (effect.to - p).normalized().orthogonal()
   for i in range(1, 9):
    var zigzag = sin(i * 17.8 + floor(progress * 6) * 4.13) * 12.0
    path.append(p.lerp(effect.to, i / 9.0) + normal * zigzag)
   path.append(effect.to)
   draw_polyline(path, Color(color, alpha * 0.10), 16, true)
   draw_polyline(path, Color(color, alpha * 0.32), 7, true)
   draw_polyline(path, color, 2.8, true)
   draw_circle(effect.to, 8 + progress * 8, Color(color, alpha * 0.25))
   for branch in [3, 6]:
    var endpoint = path[branch] + normal * (18 if branch == 3 else -18)
    draw_line(path[branch], endpoint, Color(color, alpha * 0.65), 1, true)
  "ice":
   var radius: float = effect.radius * (1.0 - pow(1.0 - progress, 3))
   if radius < 1.0: return
   draw_circle(p, radius, Color(color, alpha * 0.08))
   draw_arc(p, radius, 0, TAU, 64, Color(color, alpha * 0.65), 3, true)
   draw_arc(p, radius * 0.83, progress, progress + TAU, 48, Color(color, alpha * 0.25), 5, true)
   for shard in range(12):
    var angle = shard * TAU / 12
    var tip = p + Vector2.from_angle(angle) * radius
    var root = p + Vector2.from_angle(angle) * radius * 0.78
    var side = Vector2.from_angle(angle).orthogonal() * 4 * alpha
    draw_colored_polygon(PackedVector2Array([tip, root + side, root - side]), color)
  "upgrade", "summon":
   var radius: float = effect.radius * progress
   draw_arc(p, radius, 0, TAU, 72, Color(color, alpha * 0.7), 3, true)
   for i in range(10):
    var v = p + Vector2.from_angle(i * TAU / 10 + progress * 0.7) * radius
    draw_circle(v, 3.0 * alpha, color)
  "conduct":
   draw_string(ThemeDB.fallback_font, p + Vector2(-22, -42 - 28 * progress), "+30%", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, color)
  "burst":
   draw_arc(p, (12 + effect.radius * 1.8 * progress), 0, TAU, 28, Color(color, alpha * 0.4), 2, true)
   for i in range(8):
    var offset = Vector2.from_angle(i * TAU / 8 + effect.from.x) * (7 + progress * effect.radius * 1.8)
    draw_colored_polygon(points(p + offset, (2 + i % 3) * alpha, 3, progress * 3 + i), color)
  _:
   for i in range(5):
    var direction = Vector2.from_angle(i * TAU / 5 + p.x)
    draw_line(p + direction * 5, p + direction * (9 + 16 * progress), color, 2 * alpha, true)
