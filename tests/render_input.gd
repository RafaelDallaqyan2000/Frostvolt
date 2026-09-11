extends SceneTree
const Game = preload("res://scripts/game.gd")
const S = preload("res://scripts/save.gd")
var game
var failures := 0
var checks := 0

func _initialize() -> void:
 call_deferred("run")

func check(condition: bool, message: String) -> void:
 checks += 1
 if not condition:
  failures += 1
  push_error("FAIL: " + message)

func buttons(node: Node) -> Array:
 var result := []
 if node is Button: result.append(node)
 for child in node.get_children(): result.append_array(buttons(child))
 return result

func click_button(prefix: String, by_name: bool = false) -> void:
 await process_frame
 var matches = buttons(game.ui).filter(func(b): return str(b.name).begins_with(prefix) if by_name else b.text.begins_with(prefix))
 check(matches.size() == 1, "Unique button " + prefix)
 if matches.size() != 1: return
 var point: Vector2 = matches[0].get_global_rect().get_center()
 var motion := InputEventMouseMotion.new()
 motion.position = point
 root.push_input(motion, true)
 var press := InputEventMouseButton.new()
 press.position = point
 press.button_index = MOUSE_BUTTON_LEFT
 press.pressed = true
 root.push_input(press, true)
 await process_frame
 var release := InputEventMouseButton.new()
 release.position = point
 release.button_index = MOUSE_BUTTON_LEFT
 release.pressed = false
 root.push_input(release, true)
 await process_frame

func capture(name: String) -> void:
 game.arena.queue_redraw()
 game.ui.update_hud()
 await create_timer(0.3).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://test-output/" + name + ".png")
 for item in buttons(game.ui):
  var rect: Rect2 = item.get_global_rect()
  check(rect.size.y >= 64, "Touch target " + name)
  check(Rect2(Vector2.ZERO, game.get_viewport_rect().size).encloses(rect), "Button on screen " + name)

func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://test-output")
 game = Game.new()
 game.test_mode = true
 root.add_child(game)
 game.set_process(false)
 game.sound.enabled = false
 for aspect in ["9-16", "9-20"]:
  root.size = Vector2i(450, 800 if aspect == "9-16" else 1000)
  await process_frame
  await process_frame
  game.resize()
  game.data = S.defaults()
  game.state = Game.State.MENU
  game.ui.show_menu()
  await capture("menu-" + aspect)
  await click_button("Звук")
  check(not game.data.sound, "Sound button")
  await click_button("Играть")
  check(game.state == Game.State.RUNNING, "Menu to combat click")
  game.rng.seed = 10
  for i in range(27 * 60): game.advance(1.0 / 60)
  await capture("combat-" + aspect)
  await click_button("II")
  check(game.state == Game.State.PAUSED, "Pause button")
  await capture("pause-" + aspect)
  await click_button("Продолжить")
  check(game.state == Game.State.RUNNING, "Resume button")
  while game.state == Game.State.RUNNING: game.advance(1.0 / 60)
  check(game.state == Game.State.UPGRADE, "Timed wave completion")
  await capture("upgrade-" + aspect)
  var card_id: String = game.offered[0]
  await click_button("Card_" + card_id, true)
  check(game.state == Game.State.RUNNING and game.waves.number == 2, "Card click starts next wave: state=%d wave=%d" % [game.state, game.waves.number])
  # A controlled scene exposes all silhouettes and the actual combo effects.
  game.enemies.clear()
  game.effects.clear()
  game.tower.levels = {"cryo": 1, "tesla": 1, "conduct": 1, "chain": 2}
  game.waves.number = 10
  game.waves.elapsed = 18
  game.elapsed = 288
  game.boss = game.spawn_enemy("boss", game.center + Vector2(-115, -200))
  game.spawn_enemy("heavy", game.center + Vector2(180, 100))
  game.spawn_enemy("runner", game.center + Vector2(-230, 30))
  game.spawn_enemy("normal", game.center + Vector2(-175, -130))
  game.spawn_enemy("heavy", game.center + Vector2(-70, -115))
  game.weapons.cryo_explode(game, game.center + Vector2(-120, -145))
  game.weapons.fire_tesla(game, game.boss)
  for effect in game.effects: effect.left *= 0.65
  for enemy in game.enemies: enemy.flash = 0
  game.ui.show_hud()
  await capture("combo-" + aspect)
  game.boss.hp = 0
  game.advance(0.01)
  check(game.state == Game.State.VICTORY, "Boss result")
  await capture("victory-" + aspect)
  await click_button("Ещё раз")
  check(game.state == Game.State.RUNNING and game.enemies.is_empty(), "Replay button")
  game.tower.hp = 0
  game.advance(0.01)
  await capture("defeat-" + aspect)
  await click_button("В меню")
  check(game.state == Game.State.MENU, "Result menu button")
  await click_button("Играть")
  await click_button("II")
  await click_button("В меню")
  check(game.state == Game.State.MENU, "Pause menu button")
 print("RENDER / INPUT: %d checks, %d failures; 14 rendered captures at 9:16 and 9:20" % [checks, failures])
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
