extends SceneTree
# A deterministic visual fixture using the real gameplay, assets and shaders.
# Produces frame sequences to inspect motion; it never writes the player's save.
const Game = preload("res://scripts/game.gd")
var game
var failures := 0

func _initialize() -> void:
 call_deferred("run")

func run() -> void:
 DirAccess.make_dir_recursive_absolute("res://test-output/motion")
 root.size = Vector2i(450, 800)
 game = Game.new()
 game.test_mode = true
 root.add_child(game)
 game.set_process(false)
 await process_frame
 game.start_run()
 game.data.sound = false
 game.sound.enabled = false
 game.rng.seed = 822
 game.tower.levels = {"cryo": 1, "tesla": 1, "conduct": 1, "chain": 2}
 game.waves.number = 10
 game.elapsed = 280
 game.boss = game.spawn_enemy("boss", game.center + Vector2(-75, -255))
 # Widely spaced silhouettes make the species readable in the preview.
 game.spawn_enemy("heavy", game.center + Vector2(218, 150))
 game.spawn_enemy("normal", game.center + Vector2(-270, 30))
 game.spawn_enemy("runner", game.center + Vector2(245, -170))
 for enemy in game.enemies: enemy.age = 1.0
 game.ui.show_hud()
 await create_timer(0.35).timeout
 for frame in range(144):
  # Fixed steps decouple the recording speed from rendering performance.
  game.advance(1.0 / 24.0)
  if frame % 30 == 0:
   game.spawn_enemy("normal", game.center + Vector2(-280, 190))
   game.spawn_enemy("runner", game.center + Vector2(255, -190))
  game.arena.sync_creatures()
  game.arena.queue_redraw()
  game.arena.foreground.queue_redraw()
  game.ui.update_hud()
  await process_frame
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://test-output/motion/frame_%03d.png" % frame)
  if frame == 48: root.get_texture().get_image().save_png("res://test-output/new-art-showcase.png")
 var tracked = game.boss
 game.pause_run()
 await process_frame
 var before: Transform2D = game.arena.creatures[tracked.get_instance_id()].sprite.transform
 var phase: float = tracked.motion_clock
 await create_timer(0.25).timeout
 var after: Transform2D = game.arena.creatures[tracked.get_instance_id()].sprite.transform
 if before != after or phase != tracked.motion_clock:
  failures += 1
  push_error("Animation continued on pause")
 game.resume_run()
 game.start_run()
 await process_frame
 if not game.arena.creatures.is_empty() or not game.arena.fading.is_empty():
  failures += 1
  push_error("Creature visuals survived restart")
 print("ANIMATION: pause and restart checks, failures=", failures, "; 144 actual rendered frames")
 game.queue_free()
 await process_frame
 quit(0 if failures == 0 else 1)
