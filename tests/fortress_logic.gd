extends SceneTree
# Headless checks of the fortress mode: build rules, turrets, loop, boss, results, saves and seeded full runs.
const Game = preload("res://scripts/fortress/fortress_game.gd")
const C = preload("res://scripts/fortress/config.gd")
const Grid = preload("res://scripts/fortress/build_grid.gd")
const Turret = preload("res://scripts/fortress/turret.gd")
const Foe = preload("res://scripts/fortress/foe.gd")
const Save = preload("res://scripts/fortress/fortress_save.gd")
const CLASSIC_SAVE = "user://reactor.json"
var game
var failures := 0
var checks := 0
var test_path := "user://fortress-test-only.json"

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL: " + message)

func _initialize() -> void:
 call_deferred("run")

func fresh(seed_value: int = 1) -> void:
 game.data = Save.defaults()
 game.start_run()
 game.sound.enabled = false
 game.rng.seed = seed_value

# A still enemy that never strikes, for deterministic weapon checks.
func dummy(kind: String, at: Vector2):
 var enemy = game.spawn_enemy(kind, at)
 enemy.goal = at
 enemy.attack = 1000.0
 return enemy

func snapshot() -> Array:
 var result := [game.route.distance, game.route.clock, game.route.spawn_clock, game.elapsed, game.hp, game.kills]
 for enemy in game.enemies: result.append([enemy.pos, enemy.hp, enemy.attack, enemy.slow])
 for shell in game.combat.projectiles: result.append(shell.pos)
 for turret in game.turrets: result.append(turret.cooldown)
 return result

func last_effect(kind: String):
 for i in range(game.effects.size() - 1, -1, -1):
  if game.effects[i].kind == kind: return game.effects[i]
 return null

func run() -> void:
 var classic_before := FileAccess.get_file_as_string(CLASSIC_SAVE) if FileAccess.file_exists(CLASSIC_SAVE) else "<none>"
 game = Game.new()
 game.test_mode = true
 root.add_child(game)
 game.set_process(false)
 await process_frame
 check(game.state == Game.State.MENU, "Scene opens in its menu")
 check(game.sound.players.size() == 10 and game.sound.streams.has("zap"), "Classic sound pool reused with fortress cues")

 # Coordinates: one transform for drawing, dragging and weapons.
 var probe := Vector2(123, -321)
 check(game.screen_to_world(game.world_to_screen(probe)).is_equal_approx(probe), "World and screen transforms are inverse")
 check(game.world_to_screen(Vector2(0, -C.TOWER_EXTENT)).y >= game.hud_bottom and game.world_to_screen(Vector2.ZERO).y <= game.panel_top, "Maximum tower height fits between HUD and build panel")

 fresh()
 check(game.state == Game.State.BUILD and game.stop == 0, "Run opens with the depot build")
 check(game.grid.blocks.keys() == [C.START_BLOCK] and game.grid.weapons.get(C.START_BLOCK) == "mg" and game.turrets.size() == 1, "One block with a machine gun on the chassis")
 check(game.inventory.size() == 2 and game.inventory[0].type == "piece" and game.inventory[1].type == "weapon", "Depot gives one block and one weapon")
 check(game.enemies.is_empty() and game.combat.projectiles.is_empty(), "No enemies before the first battle")
 game.depart()
 check(game.state == Game.State.BUILD, "Cannot leave with unhandled rewards")

 # Placement rules.
 var g = Grid.new()
 check(g.check_piece("1x1", Vector2i(2, 3)) == Grid.Fit.LOOSE, "Floating part rejected")
 check(g.check_piece("1x1", Vector2i(0, 0)) == Grid.Fit.OK, "Row 0 rests on the chassis")
 g.place_piece("1x1", Vector2i(1, 0))
 check(g.check_piece("1x1", Vector2i(1, 0)) == Grid.Fit.OVERLAP, "Overlap rejected")
 check(g.check_piece("2x1", Vector2i(3, 0)) == Grid.Fit.OUTSIDE, "Right boundary")
 check(g.check_piece("1x2", Vector2i(0, 5)) == Grid.Fit.OUTSIDE, "Top boundary")
 check(g.check_piece("1x1", Vector2i(-1, 0)) == Grid.Fit.OUTSIDE, "Left boundary")
 check(g.check_piece("1x1", Vector2i(2, 1)) == Grid.Fit.LOOSE and g.check_piece("1x1", Vector2i(0, 1)) == Grid.Fit.LOOSE, "Corner-only contact is not a connection")
 check(g.check_piece("1x1", Vector2i(1, 1)) == Grid.Fit.OK, "Side contact above a block")
 check(g.check_piece("2x1", Vector2i(2, 1)) == Grid.Fit.LOOSE and g.check_piece("2x1", Vector2i(0, 1)) == Grid.Fit.OK, "Horizontal part needs a shared side")
 check(g.check_piece("1x2", Vector2i(2, 1)) == Grid.Fit.LOOSE and g.check_piece("1x2", Vector2i(1, 1)) == Grid.Fit.OK, "Vertical part needs a shared side")
 check(g.check_piece("L", Vector2i(2, 0)) == Grid.Fit.OK and g.check_piece("L", Vector2i(3, 0)) == Grid.Fit.OUTSIDE, "L part inside and beyond the grid")
 check(g.check_piece("L", Vector2i(1, 0)) == Grid.Fit.OVERLAP, "L part cannot overlap")
 check(not g.place_piece("1x1", Vector2i(3, 4)) and g.blocks.size() == 1, "Failed placement changes nothing")
 var detached = Grid.new()
 detached.blocks[Vector2i(2, 3)] = 99
 check(detached.check_piece("1x1", Vector2i(2, 4)) == Grid.Fit.LOOSE, "Only structure joined to the chassis supports parts")

 fresh()
 check(not game.place_item(0, Vector2i(3, 3)) and game.inventory.size() == 2, "Loose drop refused and kept")
 check(not game.place_item(0, Vector2i(3, 0) + Vector2i(1, 0)) and game.inventory.size() == 2, "Out-of-grid drop refused and kept")
 check(not game.place_item(0, C.START_BLOCK) and game.inventory.size() == 2, "Overlapping drop refused and kept")
 check(not game.place_item(1, Vector2i(0, 0)), "Weapon needs a built block")
 check(not game.place_item(1, C.START_BLOCK), "One weapon per block")
 var max_before: float = game.max_hp
 check(game.place_item(0, Vector2i(1, 1)), "Block placed on the start block")
 check(game.inventory.size() == 1 and game.inventory[0].id == C.REWARDS[0].weapon, "Part spent only after success")
 check(game.max_hp == max_before + C.HP_PER_CELL, "Each block cell adds fortress health")
 check(game.place_item(0, Vector2i(1, 1)), "Weapon mounted on the new block")
 check(game.turrets.size() == 2 and game.grid.weapons[Vector2i(1, 1)] == C.REWARDS[0].weapon, "Mounted weapon joins the turret list")
 var twin = Grid.new()
 twin.place_piece("2x1", Vector2i(0, 0))
 check(twin.place_weapon("mg", Vector2i(0, 0)) and twin.place_weapon("mg", Vector2i(1, 0)), "Several weapons of one kind in different cells")
 game.depart()
 check(game.state == Game.State.COMBAT and game.route.stage == 1, "Depart starts segment 1")

 # Full grid: rewards can be skipped and the route continues.
 fresh()
 for x in range(C.COLS):
  for y in range(C.ROWS):
   game.grid.blocks[Vector2i(x, y)] = 90
   game.grid.weapons[Vector2i(x, y)] = "mg"
 check(game.grid.is_full(), "Grid can be completely filled")
 var no_room := true
 for shape in C.SHAPES: no_room = no_room and game.grid.piece_spots(shape).is_empty()
 check(no_room and not game.has_room(game.inventory[0]) and not game.has_room(game.inventory[1]), "Full grid leaves no spot for any part or weapon")
 game.ui.rebuild_cards()
 check(game.ui.skip_button != null and not game.ui.skip_button.disabled and game.ui.go_button.disabled, "Skip is offered while rewards remain")
 game.hp = game.max_hp - 100
 game.skip_rewards()
 check(game.inventory.is_empty() and game.hp == game.max_hp - 100 + 2 * C.SKIP_REPAIR, "Skip spends rewards as repair")
 game.depart()
 check(game.state == Game.State.COMBAT, "Full grid never blocks the route")

 # Each turret fires from its own barrel with its own range and timer.
 fresh()
 game.inventory.clear()
 for y in range(C.ROWS): game.grid.blocks[Vector2i(0, y)] = 70
 var high = Turret.new("mg", Vector2i(0, 5))
 var low = game.turrets[0]
 game.turrets.append(high)
 game.depart()
 var reach: float = high.stats.barrel + high.stats.range + C.ENEMIES.heavy.size - 5
 var target = dummy("heavy", high.pivot + Vector2.from_angle(-0.1) * reach)
 check(high.can_reach(target, game.field_right) and not low.can_reach(target, game.field_right), "Range is measured from each barrel")
 game.combat.step(0.0, game)
 check(high.shots == 1 and low.shots == 0, "Only the turret that reaches the target fires")
 var tracer = last_effect("shot")
 check(tracer != null and tracer.from.is_equal_approx(high.muzzle()) and high.muzzle().distance_to(high.pivot) > 20, "Tracer starts at the firing barrel")
 check(is_equal_approx(high.cooldown, 1.0 / C.WEAPONS.mg.rate) and low.cooldown == 0.0, "Each turret keeps its own fire timer")
 check(is_equal_approx(target.max_hp - target.hp, C.WEAPONS.mg.damage - C.ENEMIES.heavy.armor), "Armour reduces every hit")
 var side = Turret.new("mg", Vector2i(3, 2))
 check(not side.can_reach(Foe.new("normal", side.pivot + Vector2(-80, 0), side.pivot), 2000.0), "Weapons never fire backwards")
 check(side.can_reach(Foe.new("normal", side.pivot + Vector2(200, 0), side.pivot), 2000.0), "Forward target in range is reachable")
 check(not side.can_reach(Foe.new("normal", side.pivot + Vector2(200, 0), side.pivot), side.pivot.x + 100), "Enemies outside the battle field are not targeted")
 game.enemies.clear()
 var near = dummy("normal", low.pivot + Vector2(140, 20))
 var far = dummy("normal", low.pivot + Vector2(260, 20))
 game.turrets = [low]
 low.cooldown = 0
 game.combat.step(0.0, game)
 check(near.hp < near.max_hp and far.hp == far.max_hp, "Machine gun hits the nearest single target")

 fresh()
 check(game.place_item(0, Vector2i(2, 0)) and game.place_item(0, Vector2i(2, 0)), "Cryo mounted at the front")
 game.depart()
 var cryo = game.turrets[1]
 game.turrets = [cryo]
 var a = dummy("heavy", Vector2(470, -40))
 var b = dummy("heavy", Vector2(500, -40))
 var outside = dummy("heavy", Vector2(720, -40))
 game.combat.step(0.0, game)
 check(game.combat.projectiles.size() == 1 and game.combat.projectiles[0].from.is_equal_approx(cryo.muzzle()), "Cryo shell leaves its own barrel")
 var flight := 0
 while not game.combat.projectiles.is_empty() and flight < 120:
  game.combat.step(1.0 / 60, game)
  flight += 1
 check(is_equal_approx(a.max_hp - a.hp, C.WEAPONS.cryo.damage - C.ENEMIES.heavy.armor) and b.hp < b.max_hp, "Cryo blast damages a group")
 check(a.slow > 0 and b.slow > 0 and outside.slow == 0 and outside.hp == outside.max_hp, "Blast radius slows only nearby enemies")
 var walker = game.spawn_enemy("normal", Vector2(600, -28))
 walker.slow = 5.0
 var start_x: float = walker.pos.x
 walker.step(1.0, game)
 check(is_equal_approx(start_x - walker.pos.x, C.ENEMIES.normal.speed * C.WEAPONS.cryo.factor), "Slow reduces movement speed")

 fresh()
 game.inventory.clear()
 game.depart()
 game.enemies.clear()
 var tesla = Turret.new("tesla", C.START_BLOCK)
 var line := []
 for i in range(6): line.append(dummy("normal", Vector2(240 + i * 45, -28)))
 line[1].slow = 1.0
 var hits: Array = game.combat.fire_tesla(game, tesla, line[0])
 var distinct := []
 for enemy in hits:
  if enemy not in distinct: distinct.append(enemy)
 check(hits.size() == C.WEAPONS.tesla.targets and distinct.size() == hits.size(), "Tesla chain hits several distinct targets")
 check(is_equal_approx(line[1].max_hp - line[1].hp, C.WEAPONS.tesla.damage * C.WEAPONS.tesla.slowed_bonus) and is_equal_approx(line[0].max_hp - line[0].hp, C.WEAPONS.tesla.damage), "Tesla bonus only against slowed targets")
 var first_bolt = null
 for effect in game.effects:
  if effect.kind == "bolt":
   first_bolt = effect
   break
 check(first_bolt != null and first_bolt.from.is_equal_approx(tesla.pivot + Vector2(0, -tesla.stats.barrel)), "Discharge starts at the coil")
 game.enemies = [line[4], line[5]]
 check(game.combat.fire_tesla(game, tesla, line[4]).size() == 2, "Each target at most once per discharge")

 # A weapon installed at a stop really fights.
 fresh()
 game.place_item(0, Vector2i(3, 0))
 game.place_item(0, Vector2i(3, 0))
 game.depart()
 var added = game.turrets[1]
 dummy("normal", Vector2(560, -28))
 for i in range(60): game.advance(1.0 / 60)
 check(added.kind == C.REWARDS[0].weapon and added.shots > 0, "Newly installed turret takes part in combat")

 # Enemies walk to the fortress and strike on an interval.
 fresh()
 game.inventory.clear()
 game.depart()
 game.turrets.clear()
 var attacker = game.spawn_enemy("normal")
 var guard := 0
 while not attacker.engaged and guard < 2000:
  attacker.step(1.0 / 60, game)
  guard += 1
 check(attacker.engaged and absf(attacker.pos.x - C.CHASSIS_FRONT) < 60, "Walker stops at the chassis front")
 var hp_start: float = game.hp
 attacker.attack = 0.001
 attacker.step(0.01, game)
 check(game.hp == hp_start - C.ENEMIES.normal.damage, "Contact strike")
 for i in range(int(C.ENEMIES.normal.interval / 0.01) - 5): attacker.step(0.01, game)
 check(game.hp == hp_start - C.ENEMIES.normal.damage, "Strikes wait for the interval")
 var flier = game.spawn_enemy("runner")
 check(flier.flying and flier.pos.y <= C.FLIGHT_BAND.y and flier.pos.y >= C.FLIGHT_BAND.x and flier.goal.x < flier.pos.x, "Fast enemy flies in at altitude")
 game.enemies.clear()
 for i in range(200): game.spawn_enemy("runner")
 check(game.enemies.size() == C.MAX_ENEMIES, "Active enemy cap")
 var inside := true
 for enemy in game.enemies: inside = inside and enemy.pos.x <= game.field_right + enemy.stats.size + C.SPAWN_MARGIN + 0.01 and enemy.pos.y < 0 and enemy.pos.y >= -C.TOWER_EXTENT
 check(inside, "Spawns stay inside the battle bounds")

 # Stops freeze everything and keep survivors; pause and app focus behave the same way.
 fresh(2)
 game.place_item(0, Vector2i(2, 0))
 game.place_item(0, Vector2i(2, 0))
 game.depart()
 for i in range(60 * 5): game.advance(1.0 / 60)
 var frozen := snapshot()
 game.pause_run()
 for i in range(120): game.advance(1.0 / 60)
 check(game.state == Game.State.PAUSED and snapshot() == frozen, "Pause freezes movement, enemies, shells and timers")
 game.resume_run()
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(game.state == Game.State.PAUSED, "Focus loss pauses combat")
 game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 check(game.state == Game.State.COMBAT, "Android back resumes")
 var survivor = game.spawn_enemy("heavy", Vector2(game.field_right - 20, -40))
 survivor.max_hp = 1000000.0
 survivor.hp = 1000000.0
 guard = 0
 while game.state == Game.State.COMBAT and guard < 60 * 40:
  game.advance(1.0 / 60)
  guard += 1
 check(game.state == Game.State.BUILD and game.stop == 1, "Segment ends at a build stop")
 check(absf(game.route.clock - C.SEGMENT_SECONDS) < 0.05, "Regular segment lasts about 25 seconds")
 check(game.inventory.size() == 2 and game.inventory[0].id == C.REWARDS[1].piece and game.inventory[1].id == C.REWARDS[1].weapon, "Stop gives one part and one weapon")
 check(survivor in game.enemies, "Survivors carry over to the stop")
 frozen = snapshot()
 for i in range(120): game.advance(1.0 / 60)
 check(snapshot() == frozen, "Building freezes enemies, shells and timers")
 game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 check(game.state == Game.State.PAUSED and game.paused_from == Game.State.BUILD, "Back during building opens pause")
 game.resume_run()
 check(game.state == Game.State.BUILD, "Pause returns to building")
 var survivor_x: float = survivor.pos.x
 game.skip_rewards()
 game.depart()
 game.advance(0.5)
 check(game.route.stage == 2 and survivor.pos.x < survivor_x, "Survivors resume after departure")

 # Boss: reserved slot, telegraphed summon, victory and defeat priority.
 fresh()
 for i in range(C.MAX_ENEMIES): game.enemies.append(Foe.new("normal", Vector2(600, -28), Vector2(600, -28)))
 game.inventory.clear()
 game.stop = C.SEGMENTS.size()
 game.depart()
 check(game.route.is_boss() and game.boss != null and game.boss in game.enemies and game.enemies.size() <= C.MAX_ENEMIES, "Boss gets a slot in a saturated field")
 check(not game.route.rolling(), "The carrier stops the column")
 game.enemies = [game.boss]
 game.route.summon_clock = C.BOSS.warning - 0.05
 game.advance(0.01)
 check(game.boss.warn > 0, "Summon is telegraphed first")
 game.route.summon_clock = 0.001
 game.advance(0.01)
 check(game.enemies.size() == 1 + C.BOSS.summon.size() and game.boss.warn == 0.0, "Boss summons reinforcements")
 game.boss.hp = 0
 game.advance(0.01)
 check(game.state == Game.State.VICTORY and game.data.wins == 1, "Destroying the boss wins")
 game.finish(true)
 check(game.data.wins == 1, "Victory counted once")
 fresh()
 game.inventory.clear()
 game.stop = C.SEGMENTS.size()
 game.depart()
 game.boss.hp = 0
 game.hp = 0
 game.advance(0.01)
 check(game.state == Game.State.DEFEAT, "Simultaneous boss and fortress loss is a defeat")
 game.start_run()
 check(game.state == Game.State.BUILD and game.enemies.is_empty() and game.effects.is_empty() and game.combat.projectiles.is_empty(), "Restart clears enemies and shells")
 check(game.grid.blocks.size() == 1 and game.turrets.size() == 1 and game.route.distance == 0 and game.route.stage == 0 and game.elapsed == 0 and game.kills == 0 and game.boss == null, "Restart clears construction and timers")
 game.inventory.clear()
 game.depart()
 game.hp = 0
 game.advance(0.01)
 check(game.state == Game.State.DEFEAT, "Zero health is a defeat")
 game.to_menu()
 check(game.state == Game.State.MENU and game.grid.blocks.size() == 1, "Menu resets the construction")

 # Saves: separate file, safe reading.
 var record := {"version": 1, "runs": 7, "wins": 3, "best_stage": 4, "best_distance": 270, "fastest_win": 171, "sound": false}
 Save.write_data(record, test_path)
 check(Save.read_data(test_path) == record, "Fortress record round trip")
 var file = FileAccess.open(test_path, FileAccess.WRITE)
 file.store_string("{ broken")
 file.close()
 check(Save.read_data(test_path) == Save.defaults(), "Corrupt fortress save falls back")
 file = FileAccess.open(test_path, FileAccess.WRITE)
 file.store_string('{"cryo": true, "tesla": true, "wave": 10, "kills": 321, "wins": 2, "sound": false}')
 file.close()
 check(Save.read_data(test_path) == Save.defaults(), "Classic-format data is not read as a fortress record")
 file = FileAccess.open(test_path, FileAccess.WRITE)
 file.store_string('{"version": 1, "runs": -4, "wins": "x", "best_stage": 99, "best_distance": 1e40, "fastest_win": null, "sound": 3}')
 file.close()
 var clean = Save.read_data(test_path)
 check(clean.runs == 0 and clean.wins == 0 and clean.best_stage == 4 and clean.fastest_win == 0 and clean.sound, "Fortress save fields sanitised")
 check(Save.PATH != "user://reactor.json", "Fortress uses its own save file")

 # Seeded full runs: a thoughtful builder, a naive one (first free spot) and one that skips every reward.
 var summaries := []
 var wins := 0
 for seed_value in range(1, 21):
  var result = await full_run(seed_value, "smart")
  summaries.append(result)
  if result.win: wins += 1
 var naive_wins := 0
 for seed_value in range(1, 11):
  var result = await full_run(seed_value, "naive")
  summaries.append(result)
  if result.win: naive_wins += 1
 var skip_wins := 0
 for seed_value in range(1, 11):
  var result = await full_run(seed_value, "skip")
  summaries.append(result)
  if result.win: skip_wins += 1
 check(wins >= 16, "Reasonable building wins at least 80%% of 20 seeded runs (%d)" % wins)
 check(skip_wins < wins, "Building matters: skipping every reward wins less often (%d/10)" % skip_wins)
 print("NAIVE BUILDER WINS %d/10" % naive_wins)
 DirAccess.make_dir_recursive_absolute("res://test-output")
 file = FileAccess.open("res://test-output/fortress-balance.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(summaries, "  "))
 file.close()
 var classic_after := FileAccess.get_file_as_string(CLASSIC_SAVE) if FileAccess.file_exists(CLASSIC_SAVE) else "<none>"
 check(classic_after == classic_before, "Classic save untouched")
 print("FORTRESS LOGIC: %d checks, %d failures; builder wins %d/20, skipper wins %d/10" % [checks, failures, wins, skip_wins])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)

func full_run(seed_value: int, mode: String) -> Dictionary:
 fresh(seed_value)
 var segments := []
 var boss_start := 0.0
 var steps := 0
 var min_hp: float = game.hp
 while game.state in [Game.State.BUILD, Game.State.COMBAT] and steps < 60 * 400:
  if game.state == Game.State.BUILD:
   if game.stop > 0: segments.append(snappedf(game.route.clock, 0.01))
   if mode == "skip": game.skip_rewards()
   else: bot_build(mode == "naive")
   game.depart()
   if game.route.is_boss(): boss_start = game.elapsed
   await process_frame
  else:
   game.advance(1.0 / 60.0)
   min_hp = minf(min_hp, game.hp)
   steps += 1
 return {"seed": seed_value, "mode": mode, "win": game.state == Game.State.VICTORY, "stage": game.route.stage, "time": snappedf(game.elapsed, 0.1), "boss_time": snappedf(game.elapsed - boss_start, 0.1) if boss_start > 0 else 0.0, "segments": segments, "hp": snappedf(game.hp, 0.1), "min_hp": snappedf(min_hp, 0.1), "max_hp": game.max_hp, "kills": game.kills, "blocks": game.grid.blocks.size(), "turrets": game.turrets.size(), "floors": game.grid.height()}

# Smart: builds upward and forward, keeps the Tesla in front and the guns high. Naive: first free spot.
func bot_build(naive: bool = false) -> void:
 while not game.inventory.is_empty():
  var item: Dictionary = game.inventory[0]
  var spots: Array = game.grid.piece_spots(item.id) if item.type == "piece" else game.grid.weapon_spots()
  if spots.is_empty():
   game.skip_rewards()
   return
  var best: Vector2i = spots[0]
  if not naive:
   for spot in spots:
    if score(item, spot) > score(item, best): best = spot
  game.place_item(0, best)

func score(item: Dictionary, spot: Vector2i) -> float:
 if item.type == "weapon" and item.id == "tesla": return spot.x * 10 - spot.y
 return spot.y * 10 + spot.x
