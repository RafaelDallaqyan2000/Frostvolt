extends Node2D
# «Кочевой бастион»: the reactor carrier rolls to the right, stops to build, fights and meets the carrier boss.
const C = preload("res://scripts/fortress/config.gd")
const Grid = preload("res://scripts/fortress/build_grid.gd")
const Turret = preload("res://scripts/fortress/turret.gd")
const Foe = preload("res://scripts/fortress/foe.gd")
const Route = preload("res://scripts/fortress/route.gd")
const Combat = preload("res://scripts/fortress/combat.gd")
const Save = preload("res://scripts/fortress/fortress_save.gd")
const Sound = preload("res://scripts/fortress/fortress_sound.gd")
const WorldView = preload("res://scripts/fortress/world_view.gd")
const DragView = preload("res://scripts/fortress/drag_view.gd")
const Interface = preload("res://scripts/fortress/fortress_ui.gd")
const CLASSIC_SCENE = "res://main.tscn"
enum State { MENU, BUILD, COMBAT, PAUSED, VICTORY, DEFEAT }
var state := State.MENU
var paused_from := State.COMBAT
var grid = Grid.new()
var route = Route.new()
var combat = Combat.new()
var rng := RandomNumberGenerator.new()
var turrets: Array = []
var enemies: Array = []
var effects: Array = []
var ui_effects: Array = []
var inventory: Array = []
var boss = null
var hp := C.HEALTH
var max_hp := C.HEALTH
var stop := 0
var kills := 0
var gold := 0
var skipped := 0
var elapsed := 0.0
var energy := C.ENERGY_START
var rapid_left := 0.0
var hit_flash := 0.0
var clock := 0.0
var field_right := C.VIEW_WIDTH
var view_scale := 1.0
var hud_bottom := 0.0
var panel_top := 0.0
var drag = null
var returning = null
var data: Dictionary
var test_mode := false
# Window tests turn this off so a desktop focus change cannot pause scripted input.
var pause_on_focus := true
var sound
var world
var drag_view
var ui

func _ready() -> void:
 rng.randomize()
 data = Save.read_data()
 sound = Sound.new()
 add_child(sound)
 sound.enabled = data.sound
 world = WorldView.new()
 world.game = self
 add_child(world)
 ui = Interface.new()
 ui.game = self
 add_child(ui)
 # The dragged part is drawn above the build panel it was picked from.
 var layer := CanvasLayer.new()
 layer.layer = 10
 add_child(layer)
 drag_view = DragView.new()
 drag_view.game = self
 layer.add_child(drag_view)
 reset_run()
 get_viewport().size_changed.connect(resize)
 resize()
 ui.show_menu()

# One transform maps the world to the screen; drawing, dragging and tests all go through it.
func resize() -> void:
 var size := get_viewport_rect().size
 ui.update_safe_area()
 hud_bottom = ui.safe.y + C.HUD_HEIGHT
 panel_top = size.y - ui.safe.w - C.PANEL_HEIGHT
 var ground := panel_top - 10.0
 view_scale = minf(1.0, minf(size.x / C.VIEW_WIDTH, (ground - hud_bottom - 8.0) / C.TOWER_EXTENT))
 world.position = Vector2(maxf(6.0, ui.safe.x - 22.0), ground)
 world.scale = Vector2.ONE * view_scale
 field_right = (size.x - world.position.x) / view_scale

func world_to_screen(point: Vector2) -> Vector2:
 return world.position + point * view_scale

func screen_to_world(point: Vector2) -> Vector2:
 return (point - world.position) / view_scale

func battle_rect() -> Rect2:
 return Rect2(0, hud_bottom, get_viewport_rect().size.x, panel_top - hud_bottom)

func scroll() -> float:
 return clock * C.SPEED if state == State.MENU else route.distance

func reset_run() -> void:
 grid = Grid.new()
 route = Route.new()
 combat = Combat.new()
 turrets.clear()
 enemies.clear()
 effects.clear()
 ui_effects.clear()
 inventory.clear()
 boss = null
 drag = null
 returning = null
 stop = 0
 kills = 0
 gold = 0
 skipped = 0
 elapsed = 0
 energy = C.ENERGY_START
 rapid_left = 0
 hit_flash = 0
 grid.place_piece("1x1", C.START_BLOCK)
 grid.place_weapon(C.START_WEAPON, C.START_BLOCK)
 turrets.append(Turret.new(C.START_WEAPON, C.START_BLOCK))
 max_hp = C.HEALTH + C.HP_PER_CELL * grid.blocks.size()
 hp = max_hp

func start_run() -> void:
 sound.stop_all()
 reset_run()
 ui.note_until = 0.0
 data.runs += 1
 persist()
 open_stop(0)

func open_stop(index: int) -> void:
 state = State.BUILD
 stop = index
 if index > 0: hp = minf(max_hp, hp + max_hp * C.STOP_REPAIR)
 # Survivors and shells stay frozen in place; only finished visual traces are dropped.
 effects.clear()
 inventory = [{"type": "piece", "id": C.REWARDS[index].piece}, {"type": "weapon", "id": C.REWARDS[index].weapon}]
 save_records()
 sound.stop_all()
 if index > 0: play("upgrade")
 ui.show_build()
 if index > 0: ui.flash_note("Остановка: движение и бой заморожены, ремонт +%d%%" % int(C.STOP_REPAIR * 100))

func depart() -> void:
 if state != State.BUILD or not inventory.is_empty() or drag != null: return
 route.begin(stop + 1)
 state = State.COMBAT
 if route.is_boss(): spawn_boss()
 play("upgrade")
 ui.show_hud()
 ui.flash_note("Носитель перекрыл дорогу!" if route.is_boss() else "Участок %d: противник справа" % route.stage)

func spawn_boss() -> void:
 # The carrier always gets a slot, even in a saturated field.
 while enemies.size() >= C.MAX_ENEMIES: enemies.pop_back()
 boss = spawn_enemy("boss")
 for kind in C.BOSS.escort: spawn_enemy(kind)

func spawn_enemy(kind: String, at: Vector2 = Vector2.INF):
 if enemies.size() >= C.MAX_ENEMIES: return null
 var stats: Dictionary = C.ENEMIES[kind]
 if at == Vector2.INF:
  var y: float = -stats.lift
  if stats.get("flying", false): y = rng.randf_range(C.FLIGHT_BAND.x, C.FLIGHT_BAND.y)
  at = Vector2(field_right + stats.size + C.SPAWN_MARGIN, y)
 var enemy = Foe.new(kind, at, attack_point(kind, at), growth(kind))
 enemies.append(enemy)
 return enemy

func growth(kind: String) -> float:
 if kind == "boss": return 1.0
 return 1.0 + C.HP_GROWTH * (clampi(route.stage, 1, C.SEGMENTS.size()) - 1)

func attack_point(kind: String, at: Vector2) -> Vector2:
 var stats: Dictionary = C.ENEMIES[kind]
 if kind == "boss": return Vector2(C.CHASSIS_FRONT + C.BOSS.stop, at.y)
 if not stats.get("flying", false): return Vector2(C.CHASSIS_FRONT + stats.size * 0.9 + rng.randf_range(0, 24), at.y)
 # Fliers strike the outermost block at their altitude, or the hull front.
 var best := Vector2(C.CHASSIS_FRONT + stats.size, -86)
 for row in range(C.ROWS):
  var front := -1
  for col in range(C.COLS):
   if grid.blocks.has(Vector2i(col, row)): front = col
  if front < 0: continue
  var point := Vector2(C.GRID_X + (front + 1) * C.CELL + stats.size, C.cell_center(Vector2i(front, row)).y)
  if absf(point.y - at.y) < absf(best.y - at.y): best = point
 return best + Vector2(rng.randf_range(0, 10), rng.randf_range(-12, 12))

func summon(carrier) -> void:
 var index := 0
 for kind in C.BOSS.summon:
  var stats: Dictionary = C.ENEMIES[kind]
  var y: float = carrier.pos.y - 70 if stats.get("flying", false) else -stats.lift
  spawn_enemy(kind, Vector2(carrier.pos.x - 40 - index * 26, y))
  index += 1
 add_effect("summon", carrier.pos, carrier.pos, carrier.stats.color, 0.7, 130)
 play("hit")

func _process(dt: float) -> void:
 clock += dt
 if state == State.COMBAT: advance(dt)
 for i in range(ui_effects.size() - 1, -1, -1):
  ui_effects[i].left -= dt
  if ui_effects[i].left <= 0: ui_effects.remove_at(i)
 if returning != null:
  returning.t += dt / 0.22
  if returning.t >= 1.0:
   returning = null
   ui.refresh_build()
 world.queue_redraw()
 drag_view.queue_redraw()
 ui.update_hud()

func advance(dt: float) -> void:
 if state != State.COMBAT: return
 # The only place where combat time moves; building, pause and menus leave all of it untouched.
 elapsed += dt
 energy = minf(C.ENERGY_MAX, energy + C.ENERGY_RATE * dt)
 rapid_left = maxf(0, rapid_left - dt)
 hit_flash = maxf(0, hit_flash - dt)
 var segment_done: bool = route.step(dt, self)
 combat.step(dt, self)
 for enemy in enemies:
  if enemy.hp > 0: enemy.step(dt, self)
 for i in range(enemies.size() - 1, -1, -1):
  var enemy = enemies[i]
  if enemy.hp <= 0:
   kills += 1
   gold += int(enemy.stats.get("gold", 0))
   add_effect("burst", enemy.pos, enemy.pos, enemy.stats.color, 0.45, enemy.stats.size)
   enemies.remove_at(i)
 for i in range(effects.size() - 1, -1, -1):
  effects[i].left -= dt
  if effects[i].left <= 0: effects.remove_at(i)
 # On a simultaneous lethal trade the reactor must survive to win.
 if hp <= 0: finish(false)
 elif boss != null and boss.hp <= 0: finish(true)
 elif segment_done: open_stop(route.stage)

func ability(index: int) -> Dictionary:
 return C.ABILITIES[index] if index >= 0 and index < C.ABILITIES.size() else {}

func can_use(index: int) -> bool:
 var card := ability(index)
 return state == State.COMBAT and not card.is_empty() and energy >= card.cost

# Ability cards spend energy earned during the battle; they never fire while building or paused.
func use_ability(index: int) -> bool:
 if not can_use(index): return false
 var card := ability(index)
 energy -= card.cost
 match card.id:
  "grenade":
   var target = null
   for enemy in enemies:
    if enemy.hp > 0 and enemy.pos.x <= field_right and (target == null or enemy.pos.x < target.pos.x): target = enemy
   if target == null:
    energy += card.cost
    return false
   for enemy in enemies:
    if enemy.hp > 0 and enemy.pos.distance_to(target.pos) <= card.radius: enemy.hit(card.damage)
   add_effect("ice", target.pos, target.pos, Color("ffb03a"), 0.5, card.radius)
   play("hit")
  "burst":
   for enemy in enemies:
    if enemy.hp > 0 and enemy.pos.x <= field_right:
     enemy.hit(card.damage)
     add_effect("burst", enemy.pos, enemy.pos, Color("ff8a3a"), 0.4, enemy.stats.size)
   play("hit")
  "rapid":
   rapid_left = card.seconds
   play("upgrade")
 return true

func damage_fortress(amount: float, point: Vector2) -> void:
 if state != State.COMBAT: return
 hp = maxf(0, hp - amount)
 hit_flash = 0.2
 add_effect("spark", point, point, Color("ffb36b"), 0.3, 14)

func fit_of(item: Dictionary, origin: Vector2i) -> int:
 return grid.check_piece(item.id, origin) if item.type == "piece" else grid.check_weapon(origin)

func has_room(item: Dictionary) -> bool:
 if item.type == "piece": return not grid.piece_spots(item.id).is_empty()
 if not grid.weapon_spots().is_empty(): return true
 # A part waiting at the same stop will create a new mount.
 for other in inventory:
  if other.type == "piece" and not grid.piece_spots(other.id).is_empty(): return true
 return false

# A reward is spent only by a successful placement.
func place_item(index: int, origin: Vector2i) -> bool:
 if state != State.BUILD or index < 0 or index >= inventory.size(): return false
 var item: Dictionary = inventory[index]
 var cells := [origin]
 if item.type == "piece":
  if not grid.place_piece(item.id, origin): return false
  cells = grid.cells_of(item.id, origin)
  max_hp += C.HP_PER_CELL * cells.size()
  hp += C.HP_PER_CELL * cells.size()
 else:
  if not grid.place_weapon(item.id, origin): return false
  turrets.append(Turret.new(item.id, origin))
 inventory.remove_at(index)
 for cell in cells: ui_effects.append({"kind": "puff", "at": C.cell_center(cell), "left": 0.45, "duration": 0.45})
 play("build")
 ui.refresh_build()
 return true

func skip_rewards() -> void:
 if state != State.BUILD or inventory.is_empty() or drag != null: return
 hp = minf(max_hp, hp + C.SKIP_REPAIR * inventory.size())
 skipped += inventory.size()
 inventory.clear()
 play("upgrade")
 ui.refresh_build()

func begin_drag(index: int, point: Vector2) -> void:
 if state != State.BUILD or drag != null or index < 0 or index >= inventory.size(): return
 returning = null
 drag = {"index": index, "item": inventory[index], "screen": point, "center": Vector2.ZERO, "origin": Vector2i.ZERO, "fit": Grid.Fit.OUTSIDE, "near": false}
 update_drag(point)
 ui.refresh_build()

# The part floats a little above the finger so the snapped preview stays visible.
func update_drag(point: Vector2) -> void:
 if drag == null: return
 drag.screen = point
 var center := screen_to_world(point + Vector2(0, -C.DRAG_LIFT))
 drag.center = center
 var item: Dictionary = drag.item
 if item.type == "piece":
  var size := C.shape_size(item.id)
  drag.origin = Vector2i(roundi((center.x - C.GRID_X) / C.CELL - size.x * 0.5), roundi((C.DECK_Y - center.y) / C.CELL - size.y * 0.5))
 else:
  drag.origin = Vector2i(floori((center.x - C.GRID_X) / C.CELL), floori((C.DECK_Y - center.y) / C.CELL))
 drag.fit = fit_of(item, drag.origin)
 drag.near = C.grid_rect().grow(C.CELL * 0.6).has_point(center)
 ui.update_hint()

func end_drag(point: Vector2) -> bool:
 if drag == null: return false
 update_drag(point)
 var index: int = drag.index
 var placed := false
 if drag.near and drag.fit == Grid.Fit.OK: placed = place_item(index, drag.origin)
 if not placed:
  returning = {"index": index, "item": drag.item, "from": drag.screen, "t": 0.0}
  if drag.near: play("deny")
 drag = null
 ui.refresh_build()
 return placed

func cancel_drag() -> void:
 if drag == null: return
 drag = null
 returning = null
 ui.refresh_build()

func pause_run() -> void:
 if state not in [State.BUILD, State.COMBAT]: return
 cancel_drag()
 paused_from = state
 state = State.PAUSED
 sound.stop_all()
 save_records()
 ui.show_pause()

func resume_run() -> void:
 if state != State.PAUSED: return
 state = paused_from
 if state == State.BUILD: ui.show_build()
 else: ui.show_hud()

func to_menu() -> void:
 save_records()
 sound.stop_all()
 state = State.MENU
 reset_run()
 ui.show_menu()

func open_classic() -> void:
 save_records()
 sound.stop_all()
 get_tree().change_scene_to_file(CLASSIC_SCENE)

func finish(won: bool) -> void:
 if state != State.COMBAT: return
 state = State.VICTORY if won else State.DEFEAT
 if won:
  data.wins += 1
  data.fastest_win = int(elapsed) if data.fastest_win == 0 else mini(data.fastest_win, int(elapsed))
 save_records()
 sound.stop_all()
 play("victory" if won else "defeat")
 ui.show_result(won)

func meters() -> int:
 return int(route.distance / C.UNITS_PER_METER)

func save_records() -> void:
 data.best_stage = maxi(data.best_stage, route.stage)
 data.best_distance = maxi(data.best_distance, meters())
 persist()

func persist() -> void:
 if not test_mode: Save.write_data(data)

func toggle_sound() -> void:
 data.sound = not data.sound
 sound.enabled = data.sound
 if not data.sound: sound.stop_all()
 persist()
 ui.show_menu()

func play(id: String) -> void:
 if sound != null: sound.play_sound(id)

func add_effect(kind: String, from: Vector2, to: Vector2, color: Color, duration: float, radius: float = 15) -> void:
 if effects.size() >= C.MAX_EFFECTS: effects.pop_front()
 effects.append({"kind": kind, "from": from, "to": to, "color": color, "left": duration, "duration": duration, "radius": radius})

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]:
  if state in [State.BUILD, State.COMBAT]: pause_run()
  elif state == State.PAUSED: resume_run()
  get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
  if ui == null or not pause_on_focus: return
  if state == State.COMBAT: pause_run()
  elif state == State.BUILD: cancel_drag()
 elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
  if state in [State.BUILD, State.COMBAT]: pause_run()
  elif state == State.PAUSED: resume_run()
  elif state in [State.VICTORY, State.DEFEAT]: to_menu()
  elif state == State.MENU: get_tree().quit()
 elif what == NOTIFICATION_WM_CLOSE_REQUEST:
  if ui != null and state != State.MENU: save_records()
  get_tree().quit()
