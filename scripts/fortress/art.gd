extends RefCounted
# Shared vector art of the fortress: blocks, turrets and reward icons, drawn on any CanvasItem.
const C = preload("res://scripts/fortress/config.gd")
# Warm wasteland palette: hazy daylight over a rusted city, cream crates on the tower.
const SKY_HIGH = Color("8e8880")
const SKY_LOW = Color("cdbead")
const CITY_FAR = Color("b0a49b")
const CITY_MID = Color("9a8a82")
const CITY_NEAR = Color("7d6a63")
const ROAD = Color("9c5340")
const ROAD_DARK = Color("6d3a2d")
const SOIL = Color("53291f")
const CRATE = Color("e8d6b6")
const CRATE_DARK = Color("c4a985")
const CRATE_INNER = Color("8d4f3c")
const STEEL = Color("6b5f58")
const RUST = Color("e2622f")
const MINT = Color("78efce")
const ICE = Color("71dfff")
const AMBER = Color("f9db8b")
const VIOLET = Color("b89aff")
const EDGE = Color("3a241c")

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

# A cream crate: light frame around a dark recess where the gun sits.
static func draw_block(ci: CanvasItem, rect: Rect2, links: int, armed: bool, alpha: float = 1.0, tint: Color = Color.WHITE) -> void:
 var k := rect.size.x / C.CELL
 var frame := 9.0 * k
 ci.draw_rect(rect, fade(CRATE * tint, alpha))
 var inner := Rect2(rect.position + Vector2(frame, frame), rect.size - Vector2(frame, frame) * 2.0)
 ci.draw_rect(inner, fade(CRATE_INNER * tint, alpha))
 ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, 4.0 * k)), fade(Color("6d3729") * tint, alpha))
 # Plank shading on the frame and a lip under the floor above.
 ci.draw_rect(Rect2(rect.position.x, rect.end.y - frame, rect.size.x, frame), fade(CRATE_DARK * tint, alpha))
 if (links & 4) == 0: ci.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3.0 * k)), fade(Color("f5e9d2") * tint, alpha))
 for corner in [Vector2(0.07, 0.09), Vector2(0.93, 0.09), Vector2(0.07, 0.91), Vector2(0.93, 0.91)]:
  ci.draw_circle(rect.position + rect.size * corner, 2.6 * k, fade(Color("a98a63") * tint, alpha))
 if armed: ci.draw_rect(Rect2(rect.position.x + frame, rect.end.y - frame - 3.0 * k, 14.0 * k, 3.0 * k), fade(RUST, alpha))
 var edge := fade(EDGE, alpha)
 ci.draw_rect(rect, edge, false, 2.6 * k)
 ci.draw_rect(inner, fade(Color("4d2419") * tint, alpha), false, 2.0 * k)

static func draw_turret(ci: CanvasItem, kind: String, pivot: Vector2, aim: float, t: float, recoil: float = 0.0, s: float = 1.0, alpha: float = 1.0) -> void:
 match kind:
  "mg":
   ci.draw_colored_polygon(PackedVector2Array([pivot + Vector2(-19, 16) * s, pivot + Vector2(19, 16) * s, pivot + Vector2(13, 2) * s, pivot + Vector2(-13, 2) * s]), fade(Color("4b3f39"), alpha))
   var back := -recoil * 45.0
   var housing := quad(pivot, aim, s, Rect2(-12, -9, 26, 18))
   ci.draw_colored_polygon(housing, fade(Color("8a7a6d"), alpha))
   ci.draw_polyline(closed(housing), fade(EDGE, alpha), 2.0 * s)
   for y in [-6.0, 2.0]:
    ci.draw_colored_polygon(quad(pivot, aim, s, Rect2(12 + back, y, 20, 4)), fade(Color("ddd2c4"), alpha))
   var drum := pivot + Vector2(-3, 5).rotated(aim) * s
   ci.draw_circle(drum, 5.0 * s, fade(Color("5c4c42"), alpha))
   ci.draw_circle(drum, 2.0 * s, fade(AMBER, alpha))
   ci.draw_circle(pivot, 3.0 * s, fade(Color("b6a695"), alpha))
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
