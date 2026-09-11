extends RefCounted
# Shared vector art of the fortress: blocks, turrets and reward icons, drawn on any CanvasItem.
const C = preload("res://scripts/fortress/config.gd")
const MINT = Color("78efce")
const ICE = Color("71dfff")
const AMBER = Color("f9db8b")
const VIOLET = Color("b89aff")
const EDGE = Color("09131b")

static func fade(color: Color, alpha: float) -> Color:
 return Color(color.r, color.g, color.b, color.a * alpha)

static func quad(origin: Vector2, angle: float, s: float, rect: Rect2) -> PackedVector2Array:
 var points := PackedVector2Array()
 for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
  points.append(origin + corner.rotated(angle) * s)
 return points

static func ring(center: Vector2, rx: float, ry: float, count: int = 20, rotation: float = 0.0) -> PackedVector2Array:
 var points := PackedVector2Array()
 for i in range(count): points.append(center + Vector2(cos(TAU * i / count + rotation) * rx, sin(TAU * i / count + rotation) * maxf(ry, 0.5)))
 return points

static func closed(points: PackedVector2Array) -> PackedVector2Array:
 var result := points.duplicate()
 result.append(points[0])
 return result

# Bits of `links`: 1 right, 2 left, 4 above, 8 below — sides shared with a cell of the same piece.
static func links_in(cells, cell: Vector2i) -> int:
 var links := 0
 if cells.has(cell + Vector2i(1, 0)): links |= 1
 if cells.has(cell + Vector2i(-1, 0)): links |= 2
 if cells.has(cell + Vector2i(0, 1)): links |= 4
 if cells.has(cell + Vector2i(0, -1)): links |= 8
 return links

static func draw_block(ci: CanvasItem, rect: Rect2, links: int, armed: bool, alpha: float = 1.0, tint: Color = Color.WHITE) -> void:
 var k := rect.size.x / C.CELL
 var bevel := 6.0 * k
 ci.draw_rect(rect, fade(Color("243c4d") * tint, alpha))
 if (links & 4) == 0: ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, bevel)), fade(Color("3b6073") * tint, alpha))
 if (links & 8) == 0: ci.draw_rect(Rect2(rect.position.x, rect.end.y - bevel, rect.size.x, bevel), fade(Color("15242f") * tint, alpha))
 if (links & 2) == 0: ci.draw_rect(Rect2(rect.position, Vector2(bevel * 0.7, rect.size.y)), fade(Color("30505f") * tint, alpha))
 if (links & 1) == 0: ci.draw_rect(Rect2(rect.end.x - bevel * 0.7, rect.position.y, bevel * 0.7, rect.size.y), fade(Color("192b37") * tint, alpha))
 var inner := rect.grow(-rect.size.x * 0.17)
 ci.draw_rect(inner, fade(Color("1b2e3c") * tint, alpha))
 var brace := fade(Color("2e4b5d") * tint, alpha)
 ci.draw_line(inner.position, inner.end, brace, 3.0 * k)
 ci.draw_line(Vector2(inner.end.x, inner.position.y), Vector2(inner.position.x, inner.end.y), brace, 3.0 * k)
 ci.draw_rect(inner, fade(Color("365869") * tint, alpha), false, 1.5 * k)
 for corner in [Vector2(0.1, 0.1), Vector2(0.9, 0.1), Vector2(0.1, 0.9), Vector2(0.9, 0.9)]:
  ci.draw_circle(rect.position + rect.size * corner, 2.2 * k, fade(Color("7fa3aa") * tint, alpha))
 ci.draw_rect(Rect2(rect.get_center().x - 9 * k, rect.end.y - 11 * k, 18 * k, 3 * k), fade(MINT if armed else Color("2c4a4c"), alpha))
 var edge := fade(EDGE, alpha)
 if (links & 4) == 0: ci.draw_line(rect.position, Vector2(rect.end.x, rect.position.y), edge, 3.0 * k)
 if (links & 8) == 0: ci.draw_line(Vector2(rect.position.x, rect.end.y), rect.end, edge, 3.0 * k)
 if (links & 2) == 0: ci.draw_line(rect.position, Vector2(rect.position.x, rect.end.y), edge, 3.0 * k)
 if (links & 1) == 0: ci.draw_line(Vector2(rect.end.x, rect.position.y), rect.end, edge, 3.0 * k)

static func draw_turret(ci: CanvasItem, kind: String, pivot: Vector2, aim: float, t: float, recoil: float = 0.0, s: float = 1.0, alpha: float = 1.0) -> void:
 match kind:
  "mg":
   ci.draw_colored_polygon(PackedVector2Array([pivot + Vector2(-19, 16) * s, pivot + Vector2(19, 16) * s, pivot + Vector2(13, 2) * s, pivot + Vector2(-13, 2) * s]), fade(Color("2e4654"), alpha))
   var back := -recoil * 45.0
   var housing := quad(pivot, aim, s, Rect2(-12, -9, 26, 18))
   ci.draw_colored_polygon(housing, fade(Color("5b7a86"), alpha))
   ci.draw_polyline(closed(housing), fade(EDGE, alpha), 2.0 * s)
   for y in [-6.0, 2.0]:
    ci.draw_colored_polygon(quad(pivot, aim, s, Rect2(12 + back, y, 20, 4)), fade(Color("c9d6cf"), alpha))
   var drum := pivot + Vector2(-3, 5).rotated(aim) * s
   ci.draw_circle(drum, 5.0 * s, fade(Color("3b5560"), alpha))
   ci.draw_circle(drum, 2.0 * s, fade(AMBER, alpha))
   ci.draw_circle(pivot, 3.0 * s, fade(Color("9fb8bd"), alpha))
  "cryo":
   var base := ring(pivot + Vector2(0, 8) * s, 19 * s, 13 * s, 6, PI / 6)
   ci.draw_colored_polygon(base, fade(Color("1d4f60"), alpha))
   ci.draw_polyline(closed(base), fade(EDGE, alpha), 2.0 * s)
   var length := 30.0 - recoil * 60.0
   var tube := quad(pivot, aim, s, Rect2(0, -8, length, 16))
   ci.draw_colored_polygon(tube, fade(Color("3f8da3"), alpha))
   ci.draw_polyline(closed(tube), fade(EDGE, alpha), 2.0 * s)
   ci.draw_colored_polygon(quad(pivot, aim, s, Rect2(length - 9, -9, 4, 18)), fade(Color("a6ecff"), alpha))
   var glow := 0.6 + 0.4 * sin(t * 3.0)
   ci.draw_circle(pivot, 13.0 * s, fade(Color(ICE, 0.22 * glow), alpha))
   ci.draw_circle(pivot, 8.0 * s, fade(ICE, alpha))
   ci.draw_circle(pivot, 3.5 * s, fade(Color.WHITE, alpha))
  "tesla":
   var plinth := Rect2(pivot + Vector2(-16, 8) * s, Vector2(32, 10) * s)
   ci.draw_rect(plinth, fade(Color("2b2946"), alpha))
   ci.draw_rect(plinth, fade(EDGE, alpha), false, 2.0 * s)
   ci.draw_rect(Rect2(pivot + Vector2(-3, -24) * s, Vector2(6, 32) * s), fade(Color("4a4270"), alpha))
   for i in range(3):
    var coil := ring(pivot + Vector2(0, 4.0 - i * 9.0) * s, (14.0 - i * 2.0) * s, 4.0 * s, 16)
    ci.draw_colored_polygon(coil, fade(Color("514174"), alpha))
    ci.draw_polyline(closed(coil), fade(Color("c6a6ff"), alpha), 1.6 * s)
   var top := pivot + Vector2(0, -26) * s
   var pulse := 0.6 + 0.4 * sin(t * 5.0)
   ci.draw_circle(top, 15.0 * s, fade(Color(VIOLET, 0.18 * pulse), alpha))
   ci.draw_circle(top, 8.0 * s, fade(Color("d9c9ff"), alpha))
   ci.draw_circle(top, 4.0 * s, fade(Color.WHITE, alpha))
   for i in range(2):
    var a := t * 7.0 + i * PI
    var spark := PackedVector2Array([top, top + Vector2.from_angle(a) * 8.0 * s + Vector2(0, -3) * s, top + Vector2.from_angle(a + 0.4) * 15.0 * s])
    ci.draw_polyline(spark, fade(Color(VIOLET, 0.7 * pulse), alpha), 1.4 * s)

static func draw_piece_icon(ci: CanvasItem, shape: String, center: Vector2, cell: float, alpha: float = 1.0) -> void:
 var size := C.shape_size(shape)
 var cells: Array = C.SHAPES[shape].cells
 for offset in cells:
  var rect := Rect2(center.x + (offset.x - size.x * 0.5) * cell, center.y + (size.y * 0.5 - offset.y - 1) * cell, cell, cell)
  draw_block(ci, rect, links_in(cells, offset), false, alpha)

static func draw_weapon_icon(ci: CanvasItem, kind: String, center: Vector2, cell: float, t: float, alpha: float = 1.0) -> void:
 var s := cell / C.CELL
 draw_turret(ci, kind, center + Vector2(0, 4) * s, -0.3, t, 0.0, s, alpha)
