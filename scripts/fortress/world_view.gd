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
 draw_polygon(PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), Vector2(view.end.x, 0), Vector2(view.position.x, 0)]), PackedColorArray([Art.SKY_HIGH, Art.SKY_HIGH, Art.SKY_LOW, Art.SKY_LOW]))
 # Hazy sun behind the dust.
 var sun := Vector2(view.end.x - 170, -C.TOWER_EXTENT + 90)
 for i in range(7, 0, -1): draw_circle(sun, 26 + i * 20, Color(1, 0.92, 0.76, 0.028))
 draw_circle(sun, 40, Color(1, 0.95, 0.82, 0.3))
 # Slow dust drifting across the wasteland.
 for i in range(46):
  var drift := fposmod(hash01(i * 5 + 3) * view.size.x - t * (6.0 + hash01(i) * 14.0), view.size.x + 60.0)
  var p := Vector2(view.position.x - 30 + drift, -60 - hash01(i * 3 + 2) * (C.TOWER_EXTENT - 40))
  draw_circle(p, 1.4 + hash01(i * 7) * 2.6, Color(0.98, 0.9, 0.78, 0.06 + 0.06 * hash01(i * 11)))

# Distant city blocks: flat silhouettes, lighter with depth.
func draw_ranges(view: Rect2, s: float) -> void:
 for layer in [[0.08, 250.0, 84.0, Art.CITY_FAR], [0.2, 190.0, 62.0, Art.CITY_MID]]:
  var offset: float = s * layer[0]
  var step: float = layer[2]
  var fill: Color = layer[3]
  var x := floorf((view.position.x + offset) / step) * step - offset
  while x <= view.end.x + step:
   var n := int(roundf((x + offset) / step))
   var w: float = step * (0.62 + 0.32 * hash01(n * 3 + 1))
   var h: float = layer[1] * (0.34 + 0.66 * hash01(n * 7 + 2))
   draw_rect(Rect2(x, -h, w, h), fill)
   draw_rect(Rect2(x, -h, w, 5), fill.lightened(0.12))
   if hash01(n * 13 + 5) > 0.72: draw_rect(Rect2(x + w * 0.35, -h - 26, 7, 26), fill)
   x += step
 # Haze washes the far city out toward the horizon.
 draw_polygon(PackedVector2Array([Vector2(view.position.x, -230), Vector2(view.end.x, -230), Vector2(view.end.x, 0), Vector2(view.position.x, 0)]), PackedColorArray([Color(Art.SKY_LOW, 0.0), Color(Art.SKY_LOW, 0.0), Color(Art.SKY_LOW, 0.55), Color(Art.SKY_LOW, 0.55)]))

func draw_ruins(view: Rect2, s: float, t: float) -> void:
 var offset := s * 0.45
 var spacing := 330.0
 var fill := Art.CITY_NEAR
 var dark := fill.darkened(0.25)
 for n in range(int(floorf((view.position.x + offset) / spacing)) - 1, int(ceilf((view.end.x + offset) / spacing)) + 1):
  var x := n * spacing - offset + hash01(n * 5 + 3) * 120.0
  var h := 200.0 + hash01(n) * 110.0
  match int(hash01(n * 5 + 11) * 3.0):
   0:
    # Gutted tower block with broken windows.
    var w := 108.0
    draw_rect(Rect2(x - w * 0.5, -h, w, h), fill)
    draw_rect(Rect2(x - w * 0.5, -h, w, 6), fill.lightened(0.15))
    for row in range(int(h / 42.0)):
     for col in range(3):
      if hash01(n * 61 + row * 7 + col) > 0.38:
       draw_rect(Rect2(x - w * 0.5 + 14 + col * 28, -h + 18 + row * 42, 16, 22), dark)
   1:
    # Cooling stack with smoke.
    draw_colored_polygon(PackedVector2Array([Vector2(x - 62, 0), Vector2(x - 42, -110), Vector2(x - 38, -h), Vector2(x + 38, -h), Vector2(x + 42, -110), Vector2(x + 62, 0)]), fill)
    draw_rect(Rect2(x - 38, -h, 76, 7), fill.lightened(0.15))
    for i in range(3):
     var k := fposmod(t * 0.07 + i / 3.0, 1.0)
     draw_circle(Vector2(x - 12 + k * 46, -h - 20 - k * 110), 20 + k * 34, Color(0.86, 0.82, 0.76, 0.1 * (1.0 - k)))
   2:
    # Dockside crane over the rubble.
    draw_rect(Rect2(x - 8, -h, 16, h), fill)
    draw_rect(Rect2(x - 70, -h - 14, 150, 14), fill)
    draw_line(Vector2(x + 62, -h), Vector2(x + 62, -h + 54), dark, 4)
    draw_rect(Rect2(x + 50, -h + 54, 24, 20), dark)
    if fmod(t * 0.9 + n * 0.21, 1.8) < 0.35: draw_circle(Vector2(x, -h - 22), 4, Color(1, 0.4, 0.28, 0.9))

func draw_ground(view: Rect2, s: float) -> void:
 var left := view.position.x - 10
 var width := view.size.x + 20
 draw_rect(Rect2(left, 0, width, 26), Art.ROAD)
 draw_rect(Rect2(left, 26, width, 46), Art.ROAD_DARK)
 draw_rect(Rect2(left, 72, width, 130), Art.SOIL)
 draw_rect(Rect2(left, 202, width, view.end.y - 192), Art.SOIL.darkened(0.3))
 draw_line(Vector2(left, 0), Vector2(left + width, 0), Color("c47a53"), 3)
 var step := 120.0
 var x := floorf((left + s) / step) * step - s
 while x < left + width:
  var n := int(roundf((x + s) / step))
  draw_rect(Rect2(x, 10, 44, 5), Art.ROAD.darkened(0.22))
  # Rubble scattered along the roadside.
  for i in range(2):
   var r := 2.0 + hash01(n * 17 + i * 5) * 4.0
   draw_circle(Vector2(x + hash01(n * 7 + i) * step, -r * 0.4), r, Art.ROAD_DARK.lightened(0.08))
  if posmod(n, 3) == 0:
   draw_rect(Rect2(x, 104, step * 0.8, 11), Art.SOIL.lightened(0.12))
   draw_rect(Rect2(x - 3, 100, 8, 18), Art.SOIL.lightened(0.2))
  if hash01(n * 13 + 5) > 0.7: draw_line(Vector2(x + 20, 160 + hash01(n) * 30), Vector2(x + 90, 170 + hash01(n + 1) * 30), Color(0.78, 0.5, 0.36, 0.25), 2)
  x += step
 # Roadside posts count the same metres as the route bar.
 var post := 600.0
 x = floorf((left + s) / post) * post - s
 while x < left + width:
  var index := int(roundf((x + s) / post))
  if index > 0:
   var p := Vector2(x + 40, 0)
   draw_rect(Rect2(p + Vector2(-2, -64), Vector2(4, 64)), Color("6b5348"))
   draw_rect(Rect2(p + Vector2(-26, -86), Vector2(52, 24)), Color("e8d6b6"))
   draw_rect(Rect2(p + Vector2(-26, -86), Vector2(52, 24)), Color("8d6a4f"), false, 2)
   draw_string(ThemeDB.fallback_font, p + Vector2(-26, -68), "%d м" % int(index * post / C.UNITS_PER_METER), HORIZONTAL_ALIGNMENT_CENTER, 52, 14, Color("6d4636"))
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
 draw_colored_polygon(hull, Color("8f4736"))
 draw_colored_polygon(PackedVector2Array([Vector2(26, -112), Vector2(354, -112), Vector2(361, -101), Vector2(19, -101)]), Color("b5613f"))
 for x in [104.0, 264.0]: draw_line(Vector2(x, -100), Vector2(x, -62), Color("6b3327"), 2)
 for i in range(14): draw_circle(Vector2(26 + i * 24, -67), 2, Color("d99a6c"))
 for i in range(4):
  var a := Vector2(348 + i * 5.5, -62 - i * 5)
  draw_colored_polygon(PackedVector2Array([a, a + Vector2(5, -4.5), a + Vector2(-3, -12), a + Vector2(-8, -7.5)]), Color("e8b04a") if i % 2 == 0 else Color("1a1a1a"))
 draw_polyline(Art.closed(hull), Art.EDGE, 3, true)
 draw_rect(Rect2(20, -118, 336, 6), Color("e8d6b6"))
 draw_line(Vector2(20, -118), Vector2(356, -118), Color("a98a63"), 2)
 draw_reactor(C.REACTOR, t)
 var lamp := Vector2(368, -86)
 draw_colored_polygon(PackedVector2Array([lamp + Vector2(0, -4), lamp + Vector2(210, 60), lamp + Vector2(210, 86), lamp + Vector2(0, 5)]), Color(1, 0.9, 0.6, 0.045))
 draw_circle(lamp, 5, Color("ffe7a8"))
 draw_rect(Rect2(14, -136, 10, 24), Color("6b3327"))
 for i in range(3):
  var k := fposmod(t * 0.7 + i / 3.0, 1.0)
  draw_circle(Vector2(19 - k * 30, -140 - k * 60), 6 + k * 14, Color(0.55, 0.48, 0.42, 0.1 * (1.0 - k)))

func draw_wheel(p: Vector2, r: float, s: float) -> void:
 draw_circle(p, r, Color("3a2119"))
 draw_circle(p, r - 3, Art.RUST)
 for i in range(3): draw_line(p, p + Vector2.from_angle(s / r + i * TAU / 3) * (r - 5), Color("a8401b"), 3)
 draw_circle(p, 4.5, Color("f2b06a"))

func draw_sprocket(p: Vector2, r: float, s: float) -> void:
 var a := s / r
 for i in range(8): draw_colored_polygon(Art.quad(p, a + i * TAU / 8, 1.0, Rect2(r - 4, -3, 7, 6)), Color("5c3226"))
 draw_circle(p, r - 2, Color("3a2119"))
 draw_circle(p, r - 5, Art.RUST)
 for i in range(4): draw_line(p, p + Vector2.from_angle(a + i * PI / 2) * (r - 7), Color("a8401b"), 3)
 draw_circle(p, 6, Color("f2b06a"))

# The old arena reactor, set into the hull as the base of the fortress.
func draw_reactor(p: Vector2, t: float) -> void:
 var shell := Art.ring(p, 27, 27, 6, PI / 6)
 draw_colored_polygon(shell, Color("4a2419"))
 draw_polyline(Art.closed(shell), Color("8a5a3a"), 2.5, true)
 var pulse := 0.7 + 0.3 * sin(t * 2.2)
 for i in range(4, 0, -1): draw_circle(p, 14 + i * 5, Color(1.0, 0.62, 0.2, 0.06 * pulse))
 draw_colored_polygon(Art.ring(p, 19, 19, 6, PI / 6), Color("b5551f"))
 draw_colored_polygon(Art.ring(p, 13, 13, 6, PI / 6), Color("f0932b"))
 draw_colored_polygon(Art.ring(p, 6, 6, 6, PI / 6), Color("ffe4a8"))
 draw_arc(p, 23, t * 0.5, t * 0.5 + PI * 1.5, 32, Color("d97a2b"), 2, true)
 for dx in [-70.0, 70.0]: draw_line(p + Vector2(dx * 0.35, -12), Vector2(p.x + dx, -112), Color(0.95, 0.6, 0.25, 0.3 + 0.2 * pulse), 2)

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
   draw_line(Vector2(rect.end.x, rect.position.y + 6), Vector2(rect.end.x, rect.end.y - 6), Color("a98a63"), 3)
   for y in [0.3, 0.7]: draw_circle(Vector2(rect.end.x, rect.position.y + rect.size.y * y), 3.5, Color("d9bf92"))
  if grid.blocks.get(cell + Vector2i(0, 1), grid.blocks[cell]) != grid.blocks[cell]:
   draw_line(Vector2(rect.position.x + 6, rect.position.y), Vector2(rect.end.x - 6, rect.position.y), Color("a98a63"), 3)
   for x in [0.3, 0.7]: draw_circle(Vector2(rect.position.x + rect.size.x * x, rect.position.y), 3.5, Color("d9bf92"))
 for turret in game.turrets: Art.draw_turret(self, turret.kind, turret.pivot, turret.aim, t, turret.recoil)
 draw_crew(t)

# Highest crate, leftmost on its floor: where the builder stands and the crane is anchored.
func top_cell() -> Vector2i:
 var best: Vector2i = C.START_BLOCK
 for cell in game.grid.blocks:
  if cell.y > best.y or (cell.y == best.y and cell.x < best.x): best = cell
 return best

# The builder rides the top crate; the crane arm above him lifts the next one.
func draw_crew(t: float) -> void:
 var rect := C.cell_rect(top_cell())
 var feet := Vector2(rect.get_center().x + 6, rect.position.y)
 var bob := sin(t * 2.1) * 1.6
 # Crane: mast, angled jib and a glowing lamp at the tip.
 var mast := feet + Vector2(-26, -4)
 var elbow := mast + Vector2(-6, -74)
 var tip := elbow + Vector2(56, -34)
 draw_line(mast, elbow, Color("a8402c"), 11)
 draw_line(elbow, tip, Color("a8402c"), 9)
 draw_line(mast, elbow, Color("d4593a"), 5)
 draw_line(elbow, tip, Color("d4593a"), 4)
 draw_circle(elbow, 6, Color("6d2718"))
 var glow := 0.65 + 0.35 * sin(t * 3.4)
 draw_circle(tip, 15, Color(1.0, 0.65, 0.2, 0.2 * glow))
 draw_circle(tip, 8, Color("ffb03a"))
 draw_circle(tip, 4, Color("fff0c4"))
 # Builder: boots, coat, head under a wide hat, rifle resting toward the road.
 var hip := feet + Vector2(0, -22 + bob)
 draw_line(feet + Vector2(-5, 0), hip + Vector2(-3, 0), Color("3d2a1e"), 6)
 draw_line(feet + Vector2(5, 0), hip + Vector2(3, 0), Color("3d2a1e"), 6)
 draw_colored_polygon(PackedVector2Array([hip + Vector2(-9, 2), hip + Vector2(9, 2), hip + Vector2(7, -20), hip + Vector2(-7, -20)]), Color("6f9a4e"))
 draw_line(hip + Vector2(-9, -6), hip + Vector2(9, -6), Color("4e7038"), 3)
 var head := hip + Vector2(1, -28)
 draw_circle(head, 8, Color("f0c193"))
 draw_line(head + Vector2(-12, -4), head + Vector2(12, -4), Color("d8a860"), 5)
 draw_colored_polygon(PackedVector2Array([head + Vector2(-8, -4), head + Vector2(8, -4), head + Vector2(6, -13), head + Vector2(-6, -13)]), Color("d8a860"))
 draw_line(head + Vector2(6, 4), head + Vector2(26, 10), Color("4b3f39"), 5)
 draw_line(head + Vector2(16, 7), head + Vector2(30, 9), Color("8a7a6d"), 3)

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

# Raider on foot: marches left toward the bastion, rifle forward.
func draw_crawler(e, color: Color) -> void:
 var p: Vector2 = e.pos
 var r: float = e.stats.size
 var dark := color.darkened(0.42)
 var swing := sin(e.phase * 2.4)
 for side in [-1.0, 1.0]:
  var hip := p + Vector2(side * r * 0.22, r * 0.5)
  draw_line(hip, Vector2(hip.x + swing * side * r * 0.55, -2), dark, 6)
 var torso := Rect2(p + Vector2(-r * 0.52, -r * 0.55), Vector2(r * 1.04, r * 1.12))
 draw_rect(torso, color)
 draw_rect(Rect2(torso.position, Vector2(torso.size.x, r * 0.26)), color.lightened(0.16))
 draw_rect(torso, Art.EDGE, false, 2.2)
 draw_line(p + Vector2(-r * 0.45, r * 0.05), p + Vector2(-r * 1.15, r * 0.2 + swing * 2.0), dark, 5)
 draw_rect(Rect2(p + Vector2(-r * 1.5, r * 0.05), Vector2(r * 0.5, r * 0.16)), Color("4b3f39"))
 var head := p + Vector2(-r * 0.08, -r * 0.95)
 draw_circle(head, r * 0.4, Color("f0c193"))
 draw_colored_polygon(PackedVector2Array([head + Vector2(-r * 0.48, -r * 0.08), head + Vector2(r * 0.42, -r * 0.08), head + Vector2(r * 0.34, -r * 0.46), head + Vector2(-r * 0.4, -r * 0.46)]), dark)
 draw_circle(head + Vector2(-r * 0.16, r * 0.04), r * 0.09, Color("3a241c"))

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
  "damage":
   var rise := p + Vector2(0, -34 * progress)
   draw_string_outline(ThemeDB.fallback_font, rise, str(int(round(effect.radius))), HORIZONTAL_ALIGNMENT_CENTER, 80, 26, 6, Color(0.16, 0.09, 0.06, alpha))
   draw_string(ThemeDB.fallback_font, rise, str(int(round(effect.radius))), HORIZONTAL_ALIGNMENT_CENTER, 80, 26, color)
  "spark":
   for i in range(5): draw_line(p, p + Vector2.from_angle(PI * 0.6 + i * 0.35) * (6 + progress * effect.radius * 1.6), color, 2, true)
  "summon": draw_arc(p, effect.radius * (0.4 + progress), 0, TAU, 40, color, 5, true)
  _:
   for i in range(6): draw_circle(p + Vector2.from_angle(i * TAU / 6) * (8 + progress * effect.radius * 1.8), 3 * alpha + 1, color)

func draw_puff(effect: Dictionary) -> void:
 var k: float = 1.0 - effect.left / effect.duration
 draw_arc(effect.at, 20 + k * 30, 0, TAU, 24, Color(0.47, 0.94, 0.8, 0.6 * (1.0 - k)), 3, true)
 for i in range(6): draw_circle(effect.at + Vector2.from_angle(i * TAU / 6) * (16 + k * 26), 3 * (1.0 - k) + 0.5, Color(0.75, 1, 0.9, 0.6 * (1.0 - k)))
