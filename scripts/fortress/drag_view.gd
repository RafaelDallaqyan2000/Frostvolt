extends Node2D
# Top layer above the build panel: the snapped green/red preview on the grid, the part under the finger
# while it is away from the grid, and its flight back to the card.
const C = preload("res://scripts/fortress/config.gd")
const Art = preload("res://scripts/fortress/art.gd")
const Grid = preload("res://scripts/fortress/build_grid.gd")
const OK_COLOR = Color("4be38a")
const BAD_COLOR = Color("ff4d5e")
var game

func _draw() -> void:
 if game.drag != null:
  if game.drag.near: draw_preview(game.drag)
  else: draw_item(game.drag.item, game.world_to_screen(game.drag.center), 0.85)
 elif game.returning != null:
  var t: float = ease(clampf(game.returning.t, 0, 1), 0.5)
  var from: Vector2 = game.returning.from + Vector2(0, -C.DRAG_LIFT)
  draw_item(game.returning.item, from.lerp(game.ui.card_center(game.returning.index), t), 0.8 * (1.0 - t * 0.7))

func draw_item(item: Dictionary, center: Vector2, alpha: float) -> void:
 var cell: float = C.CELL * game.view_scale
 if item.type == "piece": Art.draw_piece_icon(self, item.id, center, cell, alpha)
 else: Art.draw_weapon_icon(self, item.id, center, cell, game.clock, alpha)

# Drawn in world units through the same transform as the world view.
func draw_preview(drag: Dictionary) -> void:
 draw_set_transform(game.world.position, 0.0, game.world.scale)
 var ok: bool = drag.fit == Grid.Fit.OK
 var color := OK_COLOR if ok else BAD_COLOR
 var piece: bool = drag.item.type == "piece"
 var cells: Array = game.grid.cells_of(drag.item.id, drag.origin) if piece else [drag.origin]
 for cell in cells:
  var rect := C.cell_rect(cell)
  if piece: Art.draw_block(self, rect, Art.links_in(cells, cell), false, 0.55)
  draw_rect(rect, Color(color, 0.34))
  draw_rect(rect.grow(-1.5), Color(color, 0.95), false, 3)
 if not piece: Art.draw_turret(self, drag.item.id, C.cell_center(drag.origin) + Vector2(0, 4), 0.0, game.clock, 0.0, 1.0, 0.75 if ok else 0.45)
 draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
