extends RefCounted
# Static 4×6 construction above the chassis. Cells are Vector2i(column, row), row 0 rests on the deck.
const C = preload("res://scripts/fortress/config.gd")
enum Fit { OK, OUTSIDE, OVERLAP, LOOSE, NO_BLOCK, TAKEN }
const SIDES = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var blocks: Dictionary = {}
var weapons: Dictionary = {}
var pieces := 0

func inside(cell: Vector2i) -> bool:
 return cell.x >= 0 and cell.x < C.COLS and cell.y >= 0 and cell.y < C.ROWS

func cells_of(shape: String, origin: Vector2i) -> Array:
 var result := []
 for offset in C.SHAPES[shape].cells: result.append(origin + offset)
 return result

# Blocks joined to the chassis through shared sides; corners never connect.
func connected() -> Dictionary:
 var reached := {}
 var queue := []
 for cell in blocks:
  if cell.y == 0:
   reached[cell] = true
   queue.append(cell)
 while not queue.is_empty():
  var cell = queue.pop_back()
  for side in SIDES:
   var next = cell + side
   if blocks.has(next) and not reached.has(next):
    reached[next] = true
    queue.append(next)
 return reached

func check_piece(shape: String, origin: Vector2i) -> int:
 var cells = cells_of(shape, origin)
 for cell in cells:
  if not inside(cell): return Fit.OUTSIDE
 for cell in cells:
  if blocks.has(cell): return Fit.OVERLAP
 var structure = connected()
 for cell in cells:
  if cell.y == 0: return Fit.OK
  for side in SIDES:
   if structure.has(cell + side): return Fit.OK
 return Fit.LOOSE

func place_piece(shape: String, origin: Vector2i) -> bool:
 if check_piece(shape, origin) != Fit.OK: return false
 pieces += 1
 for cell in cells_of(shape, origin): blocks[cell] = pieces
 return true

func check_weapon(cell: Vector2i) -> int:
 if not inside(cell): return Fit.OUTSIDE
 if not blocks.has(cell): return Fit.NO_BLOCK
 if weapons.has(cell): return Fit.TAKEN
 return Fit.OK

func place_weapon(kind: String, cell: Vector2i) -> bool:
 if check_weapon(cell) != Fit.OK: return false
 weapons[cell] = kind
 return true

func piece_spots(shape: String) -> Array:
 var result := []
 for x in range(C.COLS):
  for y in range(C.ROWS):
   if check_piece(shape, Vector2i(x, y)) == Fit.OK: result.append(Vector2i(x, y))
 return result

func weapon_spots() -> Array:
 var result := []
 for cell in blocks:
  if not weapons.has(cell): result.append(cell)
 return result

func is_full() -> bool:
 return blocks.size() >= C.COLS * C.ROWS

func height() -> int:
 var top := 0
 for cell in blocks: top = maxi(top, cell.y + 1)
 return top
