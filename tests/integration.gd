extends SceneTree
const Game = preload("res://scripts/game.gd")
const S = preload("res://scripts/save.gd")
const U = preload("res://scripts/upgrades.gd")
const B = preload("res://scripts/balance.gd")
var game
var failures := 0
var checks := 0
var test_path = "user://reactor-test-only.json"

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL: " + message)

func _initialize() -> void:
 call_deferred("run")

func fresh(seed_value: int = 1) -> void:
 game.data = S.defaults()
 game.start_run()
 game.sound.enabled = false
 game.rng.seed = seed_value

func run() -> void:
 game = Game.new()
 game.test_mode = true
 root.add_child(game)
 game.set_process(false)
 await process_frame
 fresh()
 check(game.state == Game.State.RUNNING and game.enemies.is_empty(), "Fresh run")
 var enemy = game.spawn_enemy("heavy", game.center + Vector2(100, 0))
 game.weapons.projectiles.append({"pos": game.center, "destination": enemy.pos, "life": 2.0})
 game.add_effect("hit", enemy.pos, enemy.pos, Color.WHITE, 1)
 game.pause_run()
 var snapshot = [enemy.pos, enemy.hp, game.tower.hp, game.waves.elapsed, game.elapsed, game.weapons.projectiles[0].pos, game.effects[0].left]
 for i in range(180): game.advance(1.0 / 60)
 check(snapshot == [enemy.pos, enemy.hp, game.tower.hp, game.waves.elapsed, game.elapsed, game.weapons.projectiles[0].pos, game.effects[0].left], "Pause freezes every simulation subsystem")
 game.resume_run()
 check(game.state == Game.State.RUNNING, "Resume")
 game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(game.state == Game.State.PAUSED, "App focus loss pauses")
 game.resume_run()
 game._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
 check(game.state == Game.State.PAUSED, "App background pauses")
 game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 check(game.state == Game.State.RUNNING, "Android back resumes paused combat")
 game._notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
 check(game.state == Game.State.PAUSED, "Android back pauses combat")
 fresh()
 game.finish_wave()
 check(game.data.cryo and "cryo" in U.eligible(game.tower, game.data), "Wave 1 unlock is eligible immediately")
 check(not game.data.tesla and "tesla" not in U.eligible(game.tower, game.data), "Tesla locked before wave 3")
 check(game.offered.size() <= 3 and game.offered.size() == unique(game.offered).size(), "Offers unique")
 var selected = game.offered[0]
 var elapsed_before: float = game.elapsed
 game.advance(100)
 check(game.elapsed == elapsed_before, "Upgrade screen freezes time")
 game.choose_upgrade(selected)
 game.choose_upgrade(selected)
 check(game.waves.number == 2 and game.tower.level(selected) == 1, "Double choice ignored")
 game.waves.number = 3
 game.finish_wave()
 check(game.data.tesla and "tesla" in U.eligible(game.tower, game.data), "Wave 3 unlock immediate")
 var unlocks = game.data.duplicate()
 game.start_run()
 check(game.tower.level("cryo") == 0 and game.tower.level("tesla") == 0 and game.data.cryo and game.data.tesla, "New run resets equipment and keeps unlocks")
 var pool = U.eligible(game.tower, game.data)
 check("slow" not in pool and "chain" not in pool and "conduct" not in pool, "Dependencies enforced")
 for id in ["cryo", "tesla", "damage", "rate", "range", "slow", "chain", "conduct", "health"]:
  for i in range(U.CARDS[id][2]): U.apply(id, game.tower)
 check(game.tower.max_hp == B.HEALTH + 100, "Health upgrades additive")
 check(U.eligible(game.tower, game.data).is_empty(), "All maxima excluded")
 game.tower.damage(100)
 check(U.eligible(game.tower, game.data) == ["repair"], "Repair only when damaged")
 U.apply("repair", game.tower)
 check(is_equal_approx(game.tower.hp, game.tower.max_hp - 100 + game.tower.max_hp * 0.35), "Repair percentage")
 U.apply("repair", game.tower)
 check(game.tower.hp == game.tower.max_hp, "Repair clamped")
 game.state = Game.State.UPGRADE
 game.offered = []
 game.next_wave()
 check(game.state == Game.State.RUNNING, "No cards can continue")
 fresh()
 var near = game.spawn_enemy("heavy", game.center + Vector2(60, 0))
 var far = game.spawn_enemy("heavy", game.center + Vector2(90, 0))
 game.tower.levels = {"damage": 2, "rate": 2, "range": 2}
 game.weapons.step(0, game)
 check(is_equal_approx(near.max_hp - near.hp, B.MG.damage * 1.4) and far.hp == far.max_hp, "MG closest target and additive damage")
 check(is_equal_approx(game.weapons.cooldowns.mg, 1.0 / (B.MG.rate * 1.3)), "MG fire rate additive")
 fresh()
 game.tower.levels = {"cryo": 2, "slow": 3, "tesla": 1, "conduct": 1, "chain": 3}
 var targets := []
 for i in range(6): targets.append(game.spawn_enemy("heavy", game.center + Vector2(90 + i * 15, 0)))
 var outside = game.spawn_enemy("heavy", game.center + Vector2(310, 0))
 game.weapons.cryo_explode(game, game.center + Vector2(110, 0))
 check(is_equal_approx(targets[0].max_hp - targets[0].hp, B.CRYO.damage * 1.25), "Cryo weapon level damage")
 check(targets[0].slow == 3.5 and outside.slow == 0 and outside.hp == outside.max_hp, "Cryo area and slow duration")
 var hp_before: float = targets[0].hp
 var hits: Array = game.weapons.fire_tesla(game, targets[0])
 check(hits.size() == 6 and hits.size() == unique(hits).size(), "Tesla unique targets and chain upgrade")
 check(is_equal_approx(hp_before - targets[0].hp, B.TESLA.damage * 1.3), "Conductivity is exactly +30 percent")
 check(game.conductive_hits == 6, "Combination visible counter")
 fresh()
 enemy = game.spawn_enemy("normal", game.center)
 enemy.step(0.01, game.center, game.tower)
 var hp_after: float = game.tower.hp
 for i in range(50): enemy.step(0.01, game.center, game.tower)
 check(game.tower.hp == hp_after, "Enemy contact damage interval")
 game.enemies.clear()
 for i in range(200): game.spawn_enemy("runner")
 check(game.enemies.size() == B.MAX_ENEMIES, "Enemy cap")
 game.waves.number = 9
 game.state = Game.State.UPGRADE
 game.offered.clear()
 game.next_wave()
 check(game.boss != null and game.enemies.size() == B.MAX_ENEMIES, "Boss reserved slot at cap")
 game.enemies = [game.boss]
 game.waves.escort_clock = 0
 game.waves.step(0.1, game)
 check(game.enemies.size() == 4, "Boss escort ability")
 game.elapsed = 310
 game.waves.elapsed = 40
 game.advance(0.01)
 check(game.state == Game.State.RUNNING, "Boss battle continues past five minutes")
 game.boss.hp = 0
 game.advance(0.01)
 game.finish(true)
 check(game.state == Game.State.VICTORY and game.data.wins == 1, "Victory counted once")
 game.start_run()
 check(game.enemies.is_empty() and game.effects.is_empty() and game.weapons.projectiles.is_empty() and game.kills == 0 and game.tower.levels.is_empty(), "Restart clears all run state")
 game.tower.hp = 0
 game.advance(0.01)
 check(game.state == Game.State.GAME_OVER, "Defeat")
 S.write_data(unlocks, test_path)
 check(S.read_data(test_path) == unlocks, "Persisted unlocks round trip")
 var file = FileAccess.open(test_path, FileAccess.WRITE)
 file.store_string("{ broken save")
 file.close()
 check(S.read_data(test_path) == S.defaults(), "Corrupt save safe fallback")
 file = FileAccess.open(test_path, FileAccess.WRITE)
 file.store_string('{"wave": -20, "kills": "bad", "wins": [], "sound": "bad", "cryo": true, "tesla": null}')
 file.close()
 var sanitized = S.read_data(test_path)
 check(sanitized.wave == 0 and sanitized.kills == 0 and sanitized.sound and sanitized.cryo and not sanitized.tesla, "Save fields sanitized")
 S.write_data({"cryo": true, "tesla": true, "wave": 10, "kills": 321, "wins": 2, "sound": false}, test_path)
 var wins := 0
 var summaries := []
 for seed_value in range(1, 21):
  fresh(seed_value)
  var choice_log := []
  var steps := 0
  while game.state in [Game.State.RUNNING, Game.State.UPGRADE] and steps < 60 * 650:
   if game.state == Game.State.UPGRADE:
    var choice = best_choice(game.offered)
    choice_log.append(choice)
    game.choose_upgrade(choice)
    await process_frame
   else:
    game.advance(1.0 / 60.0)
    steps += 1
  if game.state == Game.State.VICTORY: wins += 1
  summaries.append({"seed": seed_value, "win": game.state == Game.State.VICTORY, "wave": game.waves.number, "time": snappedf(game.elapsed, 0.1), "hp": game.tower.hp, "kills": game.kills, "choices": choice_log})
  await process_frame
 check(wins >= 14, "Reasonable upgrade choices win at least 70% of 20 first-save runs")
 DirAccess.make_dir_recursive_absolute("res://test-output")
 file = FileAccess.open("res://test-output/balance.json", FileAccess.WRITE)
 file.store_string(JSON.stringify(summaries, "  "))
 file.close()
 print("INTEGRATION: %d checks, %d failures; full-run wins %d/20" % [checks, failures, wins])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)

func unique(items: Array) -> Array:
 var output := []
 for item in items:
  if item not in output: output.append(item)
 return output

func best_choice(cards: Array) -> String:
 var priorities = {"cryo": 100, "tesla": 98, "conduct": 95, "damage": 70, "rate": 68, "chain": 67, "health": 48, "repair": 30, "range": 40, "slow": 42}
 if game.tower.level("cryo") > 0: priorities.cryo = 60
 if game.tower.level("tesla") > 0: priorities.tesla = 75
 if game.tower.hp < game.tower.max_hp * 0.6: priorities.repair = 110
 var chosen: String = cards[0]
 for id in cards:
  if priorities[id] > priorities[chosen]: chosen = id
 return chosen
