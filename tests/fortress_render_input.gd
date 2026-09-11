extends SceneTree
# Graphical check of the fortress mode: real mouse events through the viewport, real touch events through
# Input (converted by emulate_mouse_from_touch like on Android), layout overlap checks and captures at 9:16 and 9:20.
const Game = preload("res://scripts/fortress/fortress_game.gd")
const C = preload("res://scripts/fortress/config.gd")
const Grid = preload("res://scripts/fortress/build_grid.gd")
const Save = preload("res://scripts/fortress/fortress_save.gd")
const Turret = preload("res://scripts/fortress/turret.gd")
const SAVES = ["user://reactor.json", "user://fortress.json"]
var game
var failures := 0
var checks := 0
var captures := 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL: " + message)

func buttons(node: Node) -> Array:
 var result := []
 if node is Button and node.is_visible_in_tree(): result.append(node)
 for child in node.get_children(): result.append_array(buttons(child))
 return result

func window_point(p: Vector2) -> Vector2:
 return p * Vector2(root.size) / root.get_visible_rect().size

func pointer(kind: String, p: Vector2, pressed: bool, touch: bool) -> void:
 if touch:
  if kind == "move":
   var slide := InputEventScreenDrag.new()
   slide.index = 0
   slide.position = window_point(p)
   Input.parse_input_event(slide)
  else:
   var tap := InputEventScreenTouch.new()
   tap.index = 0
   tap.position = window_point(p)
   tap.pressed = pressed
   Input.parse_input_event(tap)
 elif kind == "move":
  var motion := InputEventMouseMotion.new()
  motion.position = p
  motion.global_position = p
  motion.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
  root.push_input(motion, true)
 else:
  var click := InputEventMouseButton.new()
  click.position = p
  click.global_position = p
  click.button_index = MOUSE_BUTTON_LEFT
  click.pressed = pressed
  click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
  root.push_input(click, true)
 await process_frame

func drag_begin(from: Vector2, to: Vector2, touch: bool) -> void:
 if not touch: await pointer("move", from, false, false)
 await pointer("down", from, true, touch)
 for i in range(1, 9): await pointer("move", from.lerp(to, i / 8.0), true, touch)

func drag_end(to: Vector2, touch: bool) -> void:
 await pointer("up", to, false, touch)
 await process_frame
 await process_frame

func tap(prefix: String, touch: bool = false, by_name: bool = false) -> void:
 await process_frame
 var matches = buttons(game.ui).filter(func(b): return str(b.name).begins_with(prefix) if by_name else b.text.begins_with(prefix))
 check(matches.size() == 1, "Unique button " + prefix)
 if matches.size() != 1: return
 var point: Vector2 = matches[0].get_global_rect().get_center()
 if touch:
  await pointer("down", point, true, true)
  await pointer("up", point, false, true)
 else:
  # Press and release in one frame, so nothing from the desktop can slip in between.
  for pressed in [true, false]:
   var click := InputEventMouseButton.new()
   click.position = point
   click.global_position = point
   click.button_index = MOUSE_BUTTON_LEFT
   click.pressed = pressed
   click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
   root.push_input(click, true)
  await process_frame
 await process_frame

func card_for(id: String):
 for card in game.ui.cards:
  if is_instance_valid(card) and card.item.id == id: return card
 return null

# Where the finger has to be so the lifted part snaps to `origin`.
func drop_point(item: Dictionary, origin: Vector2i) -> Vector2:
 var center := C.piece_center(item.id, origin) if item.type == "piece" else C.cell_center(origin)
 return game.world_to_screen(center) + Vector2(0, C.DRAG_LIFT)

func redraw() -> void:
 game.world.queue_redraw()
 game.drag_view.queue_redraw()
 game.ui.update_hud()

func capture(name: String) -> void:
 # Placement puffs fade in _process, which is off here; drop them so captures show the settled tower.
 game.ui_effects.clear()
 redraw()
 await create_timer(0.3).timeout
 redraw()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-output/" + name + ".png")
 captures += 1
 var screen := Rect2(Vector2.ZERO, game.get_viewport_rect().size)
 for item in buttons(game.ui):
  var rect: Rect2 = item.get_global_rect()
  check(rect.size.y >= 64 and screen.grow(0.5).encloses(rect), "Touch-size button on screen %s: %s" % [name, item.text])

func screen_rect(world: Rect2) -> Rect2:
 return Rect2(game.world_to_screen(world.position), world.size * game.view_scale)

func tower_rect() -> Rect2:
 var rect := Rect2(Vector2(8, -136), Vector2(362, 136))
 for cell in game.grid.blocks: rect = rect.merge(C.cell_rect(cell))
 for turret in game.turrets: rect = rect.merge(Rect2(turret.pivot - Vector2(40, 44), Vector2(80, 64)))
 return screen_rect(rect)

func enemy_rect(enemy) -> Rect2:
 var r: float = enemy.stats.size
 if enemy.kind == "boss": return screen_rect(Rect2(enemy.pos + Vector2(-r * 1.7, -r * 1.55 - 60), Vector2(r * 3.4, r * 1.55 + 60 - enemy.pos.y)))
 return screen_rect(Rect2(enemy.pos - Vector2(r * 2, r + 20), Vector2(r * 4, r * 2 + 24)))

func check_layout(tag: String) -> void:
 await process_frame
 check(is_instance_valid(game.ui.hud_root), "HUD present " + tag)
 if not is_instance_valid(game.ui.hud_root): return
 var hud: Rect2 = game.ui.hud_root.get_global_rect()
 check(hud.end.y <= game.hud_bottom + 0.5, "HUD content stays inside its strip " + tag)
 var tower := tower_rect()
 check(tower.position.y >= game.hud_bottom and tower.end.y <= game.panel_top and tower.position.x >= 0 and tower.end.x <= game.get_viewport_rect().size.x, "Whole tower between HUD and panel " + tag)
 if is_instance_valid(game.ui.panel_root):
  check(game.ui.panel_root.get_global_rect().position.y >= game.world_to_screen(Vector2.ZERO).y, "Build panel below the road " + tag)
 for enemy in game.enemies:
  check(enemy_rect(enemy).position.y >= game.hud_bottom, "%s below the HUD %s" % [enemy.kind, tag])
 for shell in game.combat.projectiles:
  check(game.world_to_screen(shell.pos).y >= game.hud_bottom, "Shell below the HUD " + tag)

func watchdog() -> void:
 push_error("FAIL: watchdog timeout, %d checks done" % checks)
 quit(2)

func run() -> void:
 create_timer(420.0).timeout.connect(watchdog)
 # Real desktop mouse events pass through this window: only the scripted input below reaches the game.
 DisplayServer.window_set_mouse_passthrough(PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1)]))
 DirAccess.make_dir_recursive_absolute("res://test-output")
 check(ProjectSettings.get_setting("application/run/main_scene") == "res://fortress.tscn", "Fortress is the main scene")
 game = Game.new()
 game.test_mode = true
 game.pause_on_focus = false
 root.add_child(game)
 game.set_process(false)
 game.sound.enabled = false
 for aspect in ["9-16", "9-20"]:
  root.size = Vector2i(450, 800 if aspect == "9-16" else 1000)
  await process_frame
  await process_frame
  game.data = Save.defaults()
  game.state = Game.State.MENU
  game.reset_run()
  game.ui.show_menu()
  await capture("fortress-menu-" + aspect)
  await tap("В путь")
  check(game.state == Game.State.BUILD and game.stop == 0, "Menu starts the depot build " + aspect)
  await process_frame
  await capture("fortress-build-" + aspect)
  await check_layout("build " + aspect)

  # Mouse: the block over a floating spot shows red and returns to the panel.
  var block: Dictionary = game.inventory[0]
  var card = card_for(block.id)
  var from: Vector2 = card.get_global_rect().get_center()
  await drag_begin(from, drop_point(block, Vector2i(3, 4)), false)
  check(game.drag != null and game.drag.near and game.drag.fit == Grid.Fit.LOOSE, "Mouse drag previews a loose spot as invalid " + aspect)
  await capture("fortress-drag-invalid-" + aspect)
  await drag_end(drop_point(block, Vector2i(3, 4)), false)
  check(game.drag == null and game.inventory.size() == 2 and game.grid.blocks.size() == 1, "Invalid mouse drop returns the part " + aspect)
  game._process(0.3)
  # Mouse: out of the grid, over an occupied cell, then a valid spot.
  await drag_begin(from, drop_point(block, Vector2i(4, 0)), false)
  check(game.drag.fit == Grid.Fit.OUTSIDE, "Out-of-grid spot rejected " + aspect)
  await drag_end(drop_point(block, Vector2i(4, 0)), false)
  await drag_begin(from, drop_point(block, C.START_BLOCK), false)
  check(game.drag.fit == Grid.Fit.OVERLAP, "Occupied spot rejected " + aspect)
  await drag_end(drop_point(block, C.START_BLOCK), false)
  check(game.inventory.size() == 2 and game.grid.blocks.size() == 1, "Rejected drops spend nothing " + aspect)
  game._process(0.3)
  await drag_begin(from, drop_point(block, Vector2i(1, 1)), false)
  check(game.drag.near and game.drag.fit == Grid.Fit.OK, "Mouse drag previews a valid spot " + aspect)
  await capture("fortress-drag-valid-" + aspect)
  await drag_end(drop_point(block, Vector2i(1, 1)), false)
  check(game.grid.blocks.has(Vector2i(1, 1)) and game.inventory.size() == 1, "Mouse drop places the block " + aspect)
  await process_frame

  # Touch: the weapon onto an empty cell returns, onto the new block it mounts.
  var weapon: Dictionary = game.inventory[0]
  card = card_for(weapon.id)
  check(card != null, "Weapon card rebuilt after placement " + aspect)
  from = card.get_global_rect().get_center()
  await drag_begin(from, drop_point(weapon, Vector2i(3, 0)), true)
  check(game.drag != null and game.drag.fit == Grid.Fit.NO_BLOCK, "Touch drag previews a weapon without a block as invalid " + aspect)
  await drag_end(drop_point(weapon, Vector2i(3, 0)), true)
  check(game.inventory.size() == 1 and game.turrets.size() == 1, "Invalid touch drop returns the weapon " + aspect)
  game._process(0.3)
  await drag_begin(from, drop_point(weapon, C.START_BLOCK), true)
  check(game.drag.fit == Grid.Fit.TAKEN, "Touch drag rejects a block that already has a weapon " + aspect)
  await drag_end(drop_point(weapon, C.START_BLOCK), true)
  game._process(0.3)
  await drag_begin(from, drop_point(weapon, Vector2i(1, 1)), true)
  check(game.drag.fit == Grid.Fit.OK, "Touch drag previews the new block as valid " + aspect)
  await capture("fortress-touch-weapon-" + aspect)
  await drag_end(drop_point(weapon, Vector2i(1, 1)), true)
  check(game.grid.weapons.get(Vector2i(1, 1)) == weapon.id and game.inventory.is_empty() and game.turrets.size() == 2, "Touch drop mounts the weapon " + aspect)
  await process_frame
  await tap("В путь", true)
  check(game.state == Game.State.COMBAT and game.route.stage == 1, "Touch tap departs " + aspect)

  game.rng.seed = 7
  for i in range(60 * 9): game.advance(1.0 / 60)
  var fired := true
  for turret in game.turrets: fired = fired and turret.shots > 0
  check(fired, "Every installed weapon fires " + aspect)
  await capture("fortress-combat-" + aspect)
  await check_layout("combat " + aspect)
  await tap("PauseButton", false, true)
  check(game.state == Game.State.PAUSED, "Pause button " + aspect)
  await capture("fortress-pause-" + aspect)
  await tap("Продолжить")
  check(game.state == Game.State.COMBAT, "Resume button " + aspect)
  var guard := 0
  while game.state == Game.State.COMBAT and guard < 60 * 30:
   game.advance(1.0 / 60)
   guard += 1
  check(game.state == Game.State.BUILD and game.stop == 1, "Segment ends at a stop " + aspect)
  await process_frame
  await capture("fortress-stop-" + aspect)
  await check_layout("stop " + aspect)

  # Later stops: build like a player, one more drag per stop, then the boss.
  var stops := 0
  while game.state == Game.State.BUILD and stops < 6:
   stops += 1
   var item: Dictionary = game.inventory[0] if not game.inventory.is_empty() else {}
   var spots: Array = game.grid.piece_spots(item.id) if item.get("type") == "piece" else []
   card = card_for(item.get("id", ""))
   if not spots.is_empty() and card != null:
    var best: Vector2i = spots[0]
    for spot in spots:
     if spot.y * 10 + spot.x > best.y * 10 + best.x: best = spot
    await drag_begin(card.get_global_rect().get_center(), drop_point(item, best), game.stop % 2 == 0)
    await drag_end(drop_point(item, best), game.stop % 2 == 0)
    check(game.grid.blocks.has(best), "Stop %d part placed by drag %s" % [game.stop, aspect])
   var mounts: Array = game.grid.weapon_spots()
   if not game.inventory.is_empty() and game.inventory[0].type == "weapon" and not mounts.is_empty():
    # Tesla goes to the front edge where its short range reaches the road; the other guns go high.
    var tesla: bool = game.inventory[0].id == "tesla"
    var top: Vector2i = mounts[0]
    for spot in mounts:
     var better: bool = (spot.x * 10 - spot.y > top.x * 10 - top.y) if tesla else (spot.y * 10 + spot.x > top.y * 10 + top.x)
     if better: top = spot
    game.place_item(0, top)
   check(game.inventory.is_empty(), "Stop %d rewards installed %s" % [game.stop, aspect])
   game.skip_rewards()
   await process_frame
   await tap("В путь")
   # Balance is covered by the logic test; here the fortress is kept alive to reach every screen.
   var ticks := 0
   while game.state == Game.State.COMBAT and not game.route.is_boss() and ticks < 60 * 40:
    game.hp = maxf(game.hp, game.max_hp * 0.3)
    game.advance(1.0 / 60)
    ticks += 1
  check(game.state == Game.State.COMBAT and game.route.is_boss() and game.boss != null, "Boss fight reached " + aspect)
  if game.boss == null: continue
  check(game.grid.height() >= 4 and game.turrets.size() == 5, "Tower grew to several floors and five weapons " + aspect)
  for i in range(60 * 6): game.advance(1.0 / 60)
  game.route.summon_clock = C.BOSS.warning * 0.5
  game.advance(0.01)
  check(game.boss.warn > 0, "Summon warning visible " + aspect)
  await capture("fortress-boss-" + aspect)
  await check_layout("boss " + aspect)
  var bar: Rect2 = game.ui.boss_meter.get_global_rect()
  check(game.ui.boss_meter.is_visible_in_tree() and bar.end.y <= game.hud_bottom and not bar.intersects(enemy_rect(game.boss)), "Boss bar in the HUD, clear of the boss and its warning " + aspect)
  game.boss.hp = 0
  game.advance(0.01)
  check(game.state == Game.State.VICTORY, "Boss defeat is a victory " + aspect)
  await capture("fortress-victory-" + aspect)
  await tap("Ещё раз")
  check(game.state == Game.State.BUILD and game.grid.blocks.size() == 1 and game.enemies.is_empty() and game.combat.projectiles.is_empty() and game.route.distance == 0, "Replay starts a clean run " + aspect)

  # The tallest possible tower still fits, and a full grid can be skipped.
  for x in range(C.COLS):
   for y in range(C.ROWS):
    game.grid.blocks[Vector2i(x, y)] = 60 + x
    if not game.grid.weapons.has(Vector2i(x, y)):
     game.grid.weapons[Vector2i(x, y)] = ["mg", "cryo", "tesla"][(x + y) % 3]
     game.turrets.append(Turret.new(game.grid.weapons[Vector2i(x, y)], Vector2i(x, y)))
  game.ui.show_build()
  await process_frame
  await capture("fortress-max-" + aspect)
  await check_layout("max tower " + aspect)
  await tap("Пропустить")
  check(game.inventory.is_empty(), "Skip works on a full grid " + aspect)
  await tap("В путь")
  check(game.state == Game.State.COMBAT, "Full grid does not block the route " + aspect)
  game.hp = 0
  game.advance(0.01)
  check(game.state == Game.State.DEFEAT, "Defeat " + aspect)
  await capture("fortress-defeat-" + aspect)
  await tap("В меню")
  check(game.state == Game.State.MENU, "Result menu button " + aspect)
 game.queue_free()
 await process_frame
 await process_frame

 # Real scene switching between the two modes; the player's saves are restored afterwards.
 var backup := {}
 for path in SAVES: backup[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
 change_scene_to_file("res://fortress.tscn")
 for i in range(4): await process_frame
 check(current_scene != null and current_scene.scene_file_path == "res://fortress.tscn", "Main scene loads the fortress menu")
 game = current_scene
 game.sound.enabled = false
 await tap("Прежний режим")
 for i in range(4): await process_frame
 check(current_scene != null and current_scene.scene_file_path == "res://main.tscn" and current_scene.state == current_scene.State.MENU, "Classic mode launches from the fortress menu")
 game = current_scene
 await tap("← Бастион")
 for i in range(4): await process_frame
 check(current_scene != null and current_scene.scene_file_path == "res://fortress.tscn", "Classic menu returns to the fortress")
 for path in SAVES:
  if backup[path] == null:
   if FileAccess.file_exists(path): DirAccess.remove_absolute(path)
  else:
   var file = FileAccess.open(path, FileAccess.WRITE)
   file.store_string(backup[path])
   file.close()
 print("FORTRESS RENDER / INPUT: %d checks, %d failures; %d captures at 9:16 and 9:20" % [checks, failures, captures])
 quit(0 if failures == 0 else 1)
