extends Node2D
# World-space drawing: parallax wasteland, tracked chassis with the reactor, the tower, enemies and effects.
const C = preload("res://scripts/fortress/config.gd")
const Art = preload("res://scripts/fortress/art.gd")
const Grid = preload("res://scripts/fortress/build_grid.gd")
const Combat = preload("res://scripts/fortress/combat.gd")
const MINT = Color("78efce")
const ICE = Color("71dfff")
var game

static func hash01(n: int) -> float:
 var x := (n * 374761393 + 668265263) & 0x7fffffff
 x = ((x ^ (x >> 13)) * 1274126177) & 0x7fffffff
 return float(x % 10000) / 10000.0

func view_rect() -> Rect2:
 return Rect2(game.screen_to_world(Vector2.ZERO), get_viewport_rect().size / game.view_scale)

func _draw() -> void:
 var view := view_rect()
 var s: float = game.scroll()
 var t: float = game.clock
 draw_sky(view, t)
 draw_ranges(view, s)
 draw_ruins(view, s, t)
 draw_ground(view, s)
 draw_chassis(s, t)
 draw_tower(t)
 if game.state == game.State.BUILD: draw_grid_overlay(t)
 for enemy in game.enemies: draw_enemy(enemy, t)
 for shell in game.combat.projectiles: draw_shell(shell)
 for effect in game.effects: draw_effect(effect)
 for effect in game.ui_effects: draw_puff(effect)

func draw_sky(view: Rect2, t: float) -> void:
 var top := Color("060d19")
 var horizon := Color("143044")
 draw_polygon(PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), Vector2(view.end.x, 0), Vector2(view.position.x, 0)]), PackedColorArray([top, top, horizon, horizon]))
 for i in range(70):
  var p := Vector2(view.position.x + hash01(i * 3 + 1) * view.size.x, view.position.y + hash01(i * 3 + 2) * (-260 - view.position.y))
  var a := 0.2 + 0.35 * (0.5 + 0.5 * sin(t * (1.0 + hash01(i) * 2.0) + i))
  draw_circle(p, 1.0 + hash01(i * 7) * 1.4, Color(0.8, 0.95, 1.0, a))
 var sun := Vector2(view.end.x - 150, -C.TOWER_EXTENT + 70)
 for i in range(6, 0, -1): draw_circle(sun, 30 + i * 16, Color(0.35, 0.6, 0.7, 0.025))
 draw_circle(sun, 34, Color("24424f"))
 draw_circle(sun, 26, Color("375f6d"))
 for band in range(3):
  var points := PackedVector2Array()
  var x := view.position.x - 20
  while x <= view.end.x + 40:
   points.append(Vector2(x, -560 + band * 44 + sin(x * 0.006 + t * 0.25 + band * 1.7) * 34 + sin(x * 0.017 - t * 0.4) * 10))
   x += 40
  draw_polyline(points, Color(0.3, 0.95, 0.75, 0.045), 30, true)
  draw_polyline(points, Color(0.45, 1.0, 0.82, 0.08), 5, true)

func draw_ranges(view: Rect2, s: float) -> void:
 for layer in [[0.08, 170.0, 66.0, Color("101e30"), Color("223a52")], [0.2, 100.0, 48.0, Color("0c1726"), Color("1a2d40")]]:
  var offset: float = s * layer[0]
  var step: float = layer[2]
  var x := floorf((view.position.x + offset) / step) * step - offset
  var ridge := PackedVector2Array()
  while x <= view.end.x + step:
   var n := int(roundf((x + offset) / step))
   ridge.append(Vector2(x, -layer[1] * (0.4 + 0.6 * hash01(n + int(layer[1])))))
   x += step
  var shape := ridge.duplicate()
  shape.append(Vector2(ridge[ridge.size() - 1].x, 0))
  shape.append(Vector2(ridge[0].x, 0))
  draw_colored_polygon(shape, layer[3])
  draw_polyline(ridge, layer[4], 2, true)

func draw_ruins(view: Rect2, s: float, t: float) -> void:
 var offset := s * 0.45
 var spacing := 330.0
 var dark := Color("0b1622")
 var line := Color("132536")
 for n in range(int(floorf((view.position.x + offset) / spacing)) - 1, int(ceilf((view.end.x + offset) / spacing)) + 1):
  var x := n * spacing - offset + hash01(n * 5 + 3) * 120.0
  var h := 170.0 + hash01(n) * 80.0
  match int(hash01(n * 5 + 11) * 4.0):
   0:
    for side in [-1.0, 1.0]: draw_line(Vector2(x + side * 26, 0), Vector2(x + side * 6, -h), line, 4)
    var y := -30.0
    while y > -h + 20:
     var w := lerpf(26, 6, -y / h)
     draw_line(Vector2(x - w, y), Vector2(x + w * 0.8, y - 26), line, 2)
     y -= 30.0
    draw_line(Vector2(x - 42, -h + 30), Vector2(x + 42, -h + 30), line, 4)
    if fmod(t + n * 0.37, 2.2) < 0.35: draw_circle(Vector2(x, -h - 4), 3.5, Color(1, 0.35, 0.3, 0.8))
   1:
    var body := PackedVector2Array([Vector2(x - 70, 0), Vector2(x - 48, -80), Vector2(x - 44, -130), Vector2(x - 52, -170), Vector2(x + 36, -170), Vector2(x + 46, -150), Vector2(x + 52, -170), Vector2(x + 44, -130), Vector2(x + 48, -80), Vector2(x + 70, 0)])
    draw_colored_polygon(body, dark)
    for i in range(3):
     var k := fposmod(t * 0.08 + i / 3.0, 1.0)
     draw_circle(Vector2(x - 10 + k * 40, -180 - k * 90), 18 + k * 30, Color(0.6, 0.75, 0.8, 0.035 * (1.0 - k)))
   2:
    draw_line(Vector2(x, 0), Vector2(x, -h), line, 3)
    for side in [-1.0, 1.0]: draw_line(Vector2(x, -h * 0.7), Vector2(x + side * 50, 0), Color(line, 0.6), 1)
    draw_arc(Vector2(x + 8, -h + 10), 18, -PI * 0.2, PI * 0.8, 10, line, 3)
    if fmod(t * 0.9 + n * 0.21, 1.8) < 0.3: draw_circle(Vector2(x, -h - 3), 3, Color(1, 0.75, 0.3, 0.8))

func draw_ground(view: Rect2, s: float) -> void:
 var left := view.position.x - 10
 var width := view.size.x + 20
 draw_rect(Rect2(left, 0, width, 24), Color("1a2935"))
 draw_rect(Rect2(left, 24, width, 40), Color("121f2a"))
 draw_rect(Rect2(left, 64, width, 120), Color("0e1822"))
 draw_rect(Rect2(left, 184, width, view.end.y - 174), Color("0a121b"))
 draw_line(Vector2(left, 0), Vector2(left + width, 0), Color("3f5c68"), 3)
 var step := 120.0
 var x := floorf((left + s) / step) * step - s
 while x < left + width:
  var n := int(roundf((x + s) / step))
  draw_rect(Rect2(x, 9, 44, 4), Color("2e4552"))
  draw_circle(Vector2(x + 70, 1), 9 + hash01(n) * 8, Color(0.75, 0.9, 0.97, 0.1))
  if hash01(n * 3 + 1) > 0.5:
   var p := Vector2(x + hash01(n * 7) * step, 40 + hash01(n * 11) * 110)
   draw_colored_polygon(PackedVector2Array([p + Vector2(-7, 4), p + Vector2(0, -9), p + Vector2(8, 3), p + Vector2(0, 7)]), Color(0.45, 0.85, 1, 0.22))
  if posmod(n, 3) == 0:
   draw_rect(Rect2(x, 96, step * 0.8, 10), Color("16242f"))
   draw_rect(Rect2(x - 3, 93, 8, 16), Color("22343f"))
  if hash01(n * 13 + 5) > 0.7: draw_line(Vector2(x + 20, 150 + hash01(n) * 30), Vector2(x + 90, 160 + hash01(n + 1) * 30), Color(0.47, 0.94, 0.8, 0.08), 2)
  x += step
 # Roadside posts count the same metres as the route bar.
 var post := 600.0
 x = floorf((left + s) / post) * post - s
 while x < left + width:
  var index := int(roundf((x + s) / post))
  if index > 0:
   var p := Vector2(x + 40, 0)
   draw_rect(Rect2(p + Vector2(-2, -64), Vector2(4, 64)), Color("2a3a44"))
   draw_rect(Rect2(p + Vector2(-26, -86), Vector2(52, 24)), Color("1d2e39"))
   draw_rect(Rect2(p + Vector2(-26, -86), Vector2(52, 24)), Color(0.47, 0.94, 0.8, 0.35), false, 1.5)
   draw_string(ThemeDB.fallback_font, p + Vector2(-26, -68), "%d м" % int(index * post / C.UNITS_PER_METER), HORIZONTAL_ALIGNMENT_CENTER, 52, 14, Color(0.7, 0.9, 0.85, 0.8))
  x += post

func draw_chassis(s: float, t: float) -> void:
 var track := PackedVector2Array()
 for i in range(13): track.append(Vector2(330, -31) + Vector2.from_angle(-PI / 2 + PI * i / 12.0) * 27)
 for i in range(13): track.append(Vector2(40, -31) + Vector2.from_angle(PI / 2 + PI * i / 12.0) * 27)
 draw_colored_polygon(track, Color("10171e"))
 # The lower run of the track rests on the road, the upper run travels forward.
 var link := 290.0 / 16.0
 for i in range(16):
  draw_rect(Rect2(40 + fposmod(i * link - s, 290.0) - 5, -8, 10, 5), Color("2b3b45"))
  draw_rect(Rect2(40 + fposmod(i * link + s, 290.0) - 5, -58, 10, 5), Color("2b3b45"))
 draw_polyline(Art.closed(track), Color("34505c"), 3, true)
 for x in [82.0, 136.0, 190.0, 244.0, 292.0]: draw_wheel(Vector2(x, -21), 15, s)
 draw_sprocket(Vector2(40, -31), 21, s)
 draw_sprocket(Vector2(330, -31), 21, s)
 var hull := PackedVector2Array([Vector2(12, -60), Vector2(346, -60), Vector2(370, -82), Vector2(354, -112), Vector2(26, -112), Vector2(8, -94)])
 draw_colored_polygon(hull, Color("1c2e3b"))
 draw_colored_polygon(PackedVector2Array([Vector2(26, -112), Vector2(354, -112), Vector2(361, -101), Vector2(19, -101)]), Color("2c4758"))
 for x in [104.0, 264.0]: draw_line(Vector2(x, -100), Vector2(x, -62), Color("132230"), 2)
 for i in range(14): draw_circle(Vector2(26 + i * 24, -67), 2, Color("5f808a"))
 for i in range(4):
  var a := Vector2(348 + i * 5.5, -62 - i * 5)
  draw_colored_polygon(PackedVector2Array([a, a + Vector2(5, -4.5), a + Vector2(-3, -12), a + Vector2(-8, -7.5)]), Color("e8b04a") if i % 2 == 0 else Color("1a1a1a"))
 draw_polyline(Art.closed(hull), Art.EDGE, 3, true)
 draw_rect(Rect2(20, -118, 336, 6), Color("3a5566"))
 draw_line(Vector2(20, -118), Vector2(356, -118), Color("5d8290"), 2)
 draw_reactor(C.REACTOR, t)
 var lamp := Vector2(368, -86)
 draw_colored_polygon(PackedVector2Array([lamp + Vector2(0, -4), lamp + Vector2(210, 60), lamp + Vector2(210, 86), lamp + Vector2(0, 5)]), Color(1, 0.9, 0.6, 0.045))
 draw_circle(lamp, 5, Color("ffe7a8"))
 draw_rect(Rect2(14, -136, 10, 24), Color("2a3f4c"))
 for i in range(3):
  var k := fposmod(t * 0.7 + i / 3.0, 1.0)
  draw_circle(Vector2(19 - k * 30, -140 - k * 60), 6 + k * 14, Color(0.7, 0.8, 0.85, 0.08 * (1.0 - k)))

func draw_wheel(p: Vector2, r: float, s: float) -> void:
 draw_circle(p, r, Color("1e2b34"))
 draw_arc(p, r, 0, TAU, 20, Color("4b6570"), 2.5, true)
 for i in range(3): draw_line(p, p + Vector2.from_angle(s / r + i * TAU / 3) * (r - 3), Color("5d7a84"), 2.5)
 draw_circle(p, 4.5, Color("8fb0b6"))

func draw_sprocket(p: Vector2, r: float, s: float) -> void:
 var a := s / r
 for i in range(8): draw_colored_polygon(Art.quad(p, a + i * TAU / 8, 1.0, Rect2(r - 4, -3, 7, 6)), Color("3a505b"))
 draw_circle(p, r - 2, Color("22323c"))
 draw_arc(p, r - 2, 0, TAU, 24, Color("56727c"), 2, true)
 for i in range(4): draw_line(p, p + Vector2.from_angle(a + i * PI / 2) * (r - 6), Color("4a646e"), 3)
 draw_circle(p, 6, Color("8fb0b6"))

# The old arena reactor, set into the hull as the base of the fortress.
func draw_reactor(p: Vector2, t: float) -> void:
 var shell := Art.ring(p, 27, 27, 6, PI / 6)
 draw_colored_polygon(shell, Color("152633"))
 draw_polyline(Art.closed(shell), Color("31564f"), 2.5, true)
 var pulse := 0.7 + 0.3 * sin(t * 2.2)
 for i in range(4, 0, -1): draw_circle(p, 14 + i * 5, Color(0.27, 1.0, 0.69, 0.05 * pulse))
 draw_colored_polygon(Art.ring(p, 19, 19, 6, PI / 6), Color("337e68"))
 draw_colored_polygon(Art.ring(p, 13, 13, 6, PI / 6), MINT)
 draw_colored_polygon(Art.ring(p, 6, 6, 6, PI / 6), Color("ddfff0"))
 draw_arc(p, 23, t * 0.5, t * 0.5 + PI * 1.5, 32, Color("418f7a"), 2, true)
 for dx in [-70.0, 70.0]: draw_line(p + Vector2(dx * 0.35, -12), Vector2(p.x + dx, -112), Color(0.47, 0.94, 0.8, 0.3 + 0.2 * pulse), 2)

func draw_tower(t: float) -> void:
 var grid = game.grid
 var tint := Color.WHITE.lerp(Color(1.6, 0.7, 0.7), clampf(game.hit_flash * 4.0, 0, 1))
 for cell in grid.blocks:
  var piece: int = grid.blocks[cell]
  var links := 0
  for pair in [[Vector2i(1, 0), 1], [Vector2i(-1, 0), 2], [Vector2i(0, 1), 4], [Vector2i(0, -1), 8]]:
   if grid.blocks.get(cell + pair[0], -1) == piece: links |= pair[1]
  Art.draw_block(self, C.cell_rect(cell), links, grid.weapons.has(cell), 1.0, tint)
 # Bolted joints where two separate parts meet.
 for cell in grid.blocks:
  var rect := C.cell_rect(cell)
  if grid.blocks.get(cell + Vector2i(1, 0), grid.blocks[cell]) != grid.blocks[cell]:
   draw_line(Vector2(rect.end.x, rect.position.y + 6), Vector2(rect.end.x, rect.end.y - 6), Color("6d949c"), 3)
   for y in [0.3, 0.7]: draw_circle(Vector2(rect.end.x, rect.position.y + rect.size.y * y), 3.5, Color("9fbfc4"))
  if grid.blocks.get(cell + Vector2i(0, 1), grid.blocks[cell]) != grid.blocks[cell]:
   draw_line(Vector2(rect.position.x + 6, rect.position.y), Vector2(rect.end.x - 6, rect.position.y), Color("6d949c"), 3)
   for x in [0.3, 0.7]: draw_circle(Vector2(rect.position.x + rect.size.x * x, rect.position.y), 3.5, Color("9fbfc4"))
 for turret in game.turrets: Art.draw_turret(self, turret.kind, turret.pivot, turret.aim, t, turret.recoil)

func draw_grid_overlay(t: float) -> void:
 var area := C.grid_rect()
 for x in range(C.COLS):
  for y in range(C.ROWS):
   if not game.grid.blocks.has(Vector2i(x, y)): draw_rect(C.cell_rect(Vector2i(x, y)).grow(-3), Color(0.47, 0.94, 0.8, 0.1), false, 1.5)
 draw_rect(area, Color(0.47, 0.94, 0.8, 0.3), false, 2)
 draw_string(ThemeDB.fallback_font, area.position + Vector2(0, -10), "СЕТКА 4×6 · ПРЕДЕЛ БАШНИ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.47, 0.94, 0.8, 0.55))
 var item = game.drag.item if game.drag != null else null
 if item != null and item.type == "weapon":
  var pulse := 0.5 + 0.5 * sin(t * 6.0)
  for cell in game.grid.weapon_spots(): draw_rect(C.cell_rect(cell).grow(-5), Color(0.47, 0.94, 0.8, 0.35 + 0.35 * pulse), false, 3)
  return
 # Crosses mark free cells a part can attach to.
 for x in range(C.COLS):
  for y in range(C.ROWS):
   var cell := Vector2i(x, y)
   if game.grid.check_piece("1x1", cell) != Grid.Fit.OK: continue
   var c := C.cell_center(cell)
   draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), Color(0.47, 0.94, 0.8, 0.4), 2)
   draw_line(c + Vector2(0, -7), c + Vector2(0, 7), Color(0.47, 0.94, 0.8, 0.4), 2)

func draw_enemy(e, t: float) -> void:
 var color: Color = e.stats.color
 if e.slow > 0: color = color.lerp(ICE, 0.55)
 if e.flash > 0: color = Color.WHITE
 match e.kind:
  "normal": draw_crawler(e, color)
  "runner": draw_hornet(e, color)
  "heavy": draw_armored(e, color)
  "boss": draw_carrier(e, color, t)
 var r: float = e.stats.size
 if e.slow > 0: draw_arc(e.pos, r + 8, 0, TAU, 24, Color(0.45, 0.85, 1, 0.5), 1.5, true)
 if e.kind != "boss" and e.hp < e.max_hp:
  var top: Vector2 = e.pos + Vector2(-r, -r - 16)
  draw_rect(Rect2(top, Vector2(r * 2, 4)), Color("243343"))
  draw_rect(Rect2(top, Vector2(r * 2 * clampf(e.hp / e.max_hp, 0, 1), 4)), color)

func draw_crawler(e, color: Color) -> void:
 var p: Vector2 = e.pos
 var r: float = e.stats.size
 for i in range(4):
  var hip := p + Vector2(-r * 0.7 + i * r * 0.5, r * 0.3)
  var swing: float = e.phase * 2.0 + i * PI * 0.5
  var foot := Vector2(hip.x + sin(swing) * r * 0.35, -1 - maxf(0, -cos(swing)) * 5)
  draw_polyline(PackedVector2Array([hip, hip.lerp(foot, 0.5) + Vector2(-4, -6), foot]), color.darkened(0.3), 2.5, true)
 var body := Art.ring(p, r * 1.3, r * 0.78, 18)
 draw_colored_polygon(body, color.darkened(0.6))
 for i in range(3): draw_arc(p + Vector2(-r * 0.2 + i * r * 0.35, 0), r * 0.62, -PI * 0.85, -PI * 0.15, 8, color.darkened(0.2), 1.6, true)
 draw_polyline(Art.closed(body), color, 2.2, true)
 var head := p + Vector2(-r * 1.25, -r * 0.05)
 draw_circle(head, r * 0.5, color.darkened(0.6))
 draw_arc(head, r * 0.5, 0, TAU, 14, color, 2, true)
 draw_circle(head + Vector2(-r * 0.2, -r * 0.1), r * 0.14, Color("ffe6d8"))
 draw_line(head + Vector2(-r * 0.4, r * 0.2), head + Vector2(-r * 0.75, r * 0.35 + sin(e.phase * 4.0) * 2), color, 2)

func draw_hornet(e, color: Color) -> void:
 var p: Vector2 = e.pos + Vector2(0, sin(e.phase * 1.3) * 5)
 var r: float = e.stats.size
 draw_colored_polygon(Art.ring(Vector2(p.x, -2), r * 1.1, 3, 12), Color(0, 0, 0, 0.3 * clampf(1.0 + p.y / 600.0, 0.1, 1)))
 var flap := absf(sin(e.phase * 9.0))
 for side in [-1.0, 1.0]:
  var wing := Art.ring(p + Vector2(side * 3, -r * 0.7), r * 0.95, r * (0.25 + 0.5 * flap), 12)
  draw_colored_polygon(wing, Color(0.85, 0.95, 1.0, 0.28))
  draw_polyline(Art.closed(wing), Color(0.9, 1, 1, 0.5), 1, true)
 var abdomen := Art.ring(p + Vector2(r * 0.45, 0), r * 0.9, r * 0.52, 14)
 draw_colored_polygon(abdomen, color.darkened(0.45))
 for i in range(2): draw_line(p + Vector2(r * (0.2 + i * 0.45), -r * 0.45), p + Vector2(r * (0.2 + i * 0.45), r * 0.45), Color("241a0e"), 3)
 draw_polyline(Art.closed(abdomen), color, 1.8, true)
 draw_colored_polygon(PackedVector2Array([p + Vector2(r * 1.3, -3), p + Vector2(r * 1.85, 0), p + Vector2(r * 1.3, 3)]), color)
 draw_circle(p + Vector2(-r * 0.55, 0), r * 0.48, color.darkened(0.3))
 draw_circle(p + Vector2(-r * 0.75, -r * 0.1), r * 0.16, Color("fff4c8"))

func draw_armored(e, color: Color) -> void:
 var p: Vector2 = e.pos
 var r: float = e.stats.size
 for i in range(3):
  var hip := p + Vector2(-r * 0.8 + i * r * 0.8, r * 0.45)
  draw_line(hip, Vector2(hip.x + sin(e.phase * 1.6 + i * 2.1) * r * 0.2, -2), color.darkened(0.35), 6)
 var shell := PackedVector2Array()
 for i in range(15): shell.append(p + Vector2(cos(PI + PI * i / 14.0) * r * 1.45, sin(PI + PI * i / 14.0) * r * 0.95))
 shell.append(p + Vector2(r * 1.45, r * 0.5))
 shell.append(p + Vector2(-r * 1.45, r * 0.5))
 draw_colored_polygon(shell, color.darkened(0.62))
 for i in range(3): draw_arc(p + Vector2(-r * 0.6 + i * r * 0.6, r * 0.1), r * 0.75, PI * 1.05, PI * 1.95, 10, color.darkened(0.15), 3, true)
 draw_polyline(Art.closed(shell), color, 2.5, true)
 draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 1.35, -r * 0.1), p + Vector2(-r * 1.95, -r * 0.35), p + Vector2(-r * 1.4, r * 0.25)]), color)
 draw_line(p + Vector2(-r * 1.2, r * 0.05), p + Vector2(-r * 0.85, r * 0.05), Color("ffe1ff"), 3)

func draw_carrier(e, color: Color, t: float) -> void:
 var p: Vector2 = e.pos
 var r: float = e.stats.size
 for i in range(4):
  var side := -1.0 if i < 2 else 1.0
  var hip := p + Vector2((-0.55 + i * 0.37) * r, r * 0.35)
  var foot := Vector2(hip.x + side * 30 + sin(e.phase * 0.9 + i * 1.7) * 16, -2)
  var leg := PackedVector2Array([hip, Vector2((hip.x + foot.x) * 0.5 + side * 26, hip.y - 30), foot])
  draw_polyline(leg, color.darkened(0.45), 9, true)
  draw_polyline(leg, color.darkened(0.1), 3, true)
 var pod := Art.ring(p + Vector2(r * 0.25, -r * 0.6), r * 0.75, r * 0.5, 20)
 draw_colored_polygon(pod, Color("2c1320"))
 draw_polyline(Art.closed(pod), color.darkened(0.2), 2.5, true)
 for i in range(5): draw_circle(p + Vector2(r * (-0.2 + i * 0.22), -r * (0.55 + 0.12 * sin(i * 2.0))), r * 0.07, Color("12060c"))
 var body := Art.ring(p, r * 1.2, r * 0.72, 26)
 draw_colored_polygon(body, Color("3a1424"))
 draw_polyline(Art.closed(body), color, 3, true)
 var pulse := 0.6 + 0.4 * sin(t * 3.0)
 var core := p + Vector2(0, r * 0.05)
 for i in range(4, 0, -1): draw_circle(core, r * 0.2 + i * 7, Color(color, 0.08 * pulse))
 draw_circle(core, r * 0.28, color.darkened(0.2))
 draw_circle(core, r * 0.14, Color("ffd0dc"))
 var mouth := p + Vector2(-r * 1.15, r * 0.1)
 var jaw := sin(e.phase * 2.0) * r * 0.12
 draw_polyline(PackedVector2Array([mouth + Vector2(0, -r * 0.15), mouth + Vector2(-r * 0.32, -r * 0.2 - jaw), mouth + Vector2(-r * 0.12, -r * 0.02)]), color, 4, true)
 draw_polyline(PackedVector2Array([mouth + Vector2(0, r * 0.12), mouth + Vector2(-r * 0.32, r * 0.2 + jaw), mouth + Vector2(-r * 0.12, r * 0.04)]), color, 4, true)
 draw_circle(p + Vector2(-r * 0.85, -r * 0.2), r * 0.08, Color("ffe6ee"))
 # Summon telegraph: stays in the battle area, the boss health bar lives in the HUD.
 if e.warn > 0:
  var k: float = 1.0 - e.warn / C.BOSS.warning
  var blink := 0.5 + 0.5 * sin(t * 18.0)
  draw_arc(p, r * (1.3 + 0.25 * k), 0, TAU, 40, Color(1, 0.85, 0.3, 0.4 + 0.5 * blink), 4, true)
  var sign := p + Vector2(0, -r * 1.55)
  draw_colored_polygon(PackedVector2Array([sign + Vector2(0, -26), sign + Vector2(24, 16), sign + Vector2(-24, 16)]), Color(1, 0.8, 0.25, 0.6 + 0.35 * blink))
  draw_string(ThemeDB.fallback_font, sign + Vector2(-20, 12), "!", HORIZONTAL_ALIGNMENT_CENTER, 40, 30, Color("2a1400"))
  draw_string(ThemeDB.fallback_font, sign + Vector2(-80, -36), "ПРИЗЫВ", HORIZONTAL_ALIGNMENT_CENTER, 160, 22, Color(1, 0.85, 0.4))

func draw_shell(shell: Dictionary) -> void:
 for i in range(3, 0, -1):
  var trail := shell.duplicate()
  trail.t = maxf(0.0, shell.t - i * 0.04)
  draw_circle(Combat.shell_position(trail), 6 - i, Color(0.45, 0.88, 1, 0.12 * (4 - i)))
 draw_circle(shell.pos, 13, Color(0.35, 0.8, 1, 0.15))
 draw_circle(shell.pos, 6, ICE)
 draw_circle(shell.pos, 2.5, Color.WHITE)

func draw_effect(effect: Dictionary) -> void:
 var alpha: float = effect.left / effect.duration
 var progress := 1.0 - alpha
 var color: Color = effect.color
 color.a = alpha
 var p: Vector2 = effect.from
 match effect.kind:
  "shot": draw_line(p, effect.to, color, 2.5, true)
  "flash":
   for i in range(4): draw_line(p, p + Vector2.from_angle(i * PI / 2 + 0.4) * effect.radius * (0.6 + alpha), color, 3, true)
   draw_circle(p, effect.radius * 0.5 * alpha + 1, color)
  "bolt":
   var points := PackedVector2Array([p])
   var normal: Vector2 = (effect.to - p).normalized().orthogonal()
   for i in range(1, 6): points.append(p.lerp(effect.to, i / 6.0) + normal * (10 if i % 2 == 0 else -10))
   points.append(effect.to)
   draw_polyline(points, Color(color, alpha * 0.2), 11, true)
   draw_polyline(points, color, 3, true)
  "ice":
   draw_circle(p, effect.radius * progress, Color(color, alpha * 0.12))
   draw_arc(p, effect.radius * progress, 0, TAU, 48, color, 3, true)
  "conduct": draw_string(ThemeDB.fallback_font, p + Vector2(-22, -30 - 25 * progress), "+30%", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, color)
  "spark":
   for i in range(5): draw_line(p, p + Vector2.from_angle(PI * 0.6 + i * 0.35) * (6 + progress * effect.radius * 1.6), color, 2, true)
  "summon": draw_arc(p, effect.radius * (0.4 + progress), 0, TAU, 40, color, 5, true)
  _:
   for i in range(6): draw_circle(p + Vector2.from_angle(i * TAU / 6) * (8 + progress * effect.radius * 1.8), 3 * alpha + 1, color)

func draw_puff(effect: Dictionary) -> void:
 var k: float = 1.0 - effect.left / effect.duration
 draw_arc(effect.at, 20 + k * 30, 0, TAU, 24, Color(0.47, 0.94, 0.8, 0.6 * (1.0 - k)), 3, true)
 for i in range(6): draw_circle(effect.at + Vector2.from_angle(i * TAU / 6) * (16 + k * 26), 3 * (1.0 - k) + 0.5, Color(0.75, 1, 0.9, 0.6 * (1.0 - k)))
