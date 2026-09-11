extends Node2D
const B = preload("res://scripts/balance.gd")
const Tower = preload("res://scripts/tower.gd")
const Enemy = preload("res://scripts/enemy.gd")
const Waves = preload("res://scripts/waves.gd")
const Weapons = preload("res://scripts/weapons.gd")
const Upgrades = preload("res://scripts/upgrades.gd")
const Save = preload("res://scripts/save.gd")
const Interface = preload("res://scripts/interface.gd")
const Sound = preload("res://scripts/sound.gd")
const Arena = preload("res://scripts/arena.gd")
enum State { MENU, RUNNING, UPGRADE, PAUSED, GAME_OVER, VICTORY }
var state := State.MENU
var tower = Tower.new()
var waves = Waves.new()
var weapons = Weapons.new()
var rng := RandomNumberGenerator.new()
var enemies: Array = []
var effects: Array = []
var data: Dictionary
var offered: Array = []
var kills := 0
var elapsed := 0.0
var conductive_hits := 0
var boss = null
var center := Vector2(360, 680)
var arena_rect := Rect2(30, 275, 660, 785)
var sound
var ui
var arena
var test_mode := false

func _ready() -> void:
 rng.randomize()
 data = Save.read_data()
 sound = Sound.new()
 add_child(sound)
 sound.enabled = data.sound
 arena = Arena.new()
 arena.game = self
 add_child(arena)
 ui = Interface.new()
 ui.game = self
 add_child(ui)
 get_viewport().size_changed.connect(resize)
 resize()
 ui.show_menu()

func resize() -> void:
 var size = get_viewport_rect().size
 center = Vector2(size.x * 0.5, size.y * 0.535)
 arena_rect = Rect2(30, 280, size.x - 60, size.y - 500)
 if ui != null: ui.update_safe_area()

func start_run() -> void:
 sound.stop_all()
 enemies.clear()
 effects.clear()
 offered.clear()
 tower = Tower.new()
 waves = Waves.new()
 weapons = Weapons.new()
 boss = null
 kills = 0
 elapsed = 0
 conductive_hits = 0
 state = State.RUNNING
 data.wave = maxi(data.wave, 1)
 persist()
 ui.show_hud()
 ui.announce("ВОЛНА 01", "Система обороны активна")

func _process(dt: float) -> void:
 if state == State.RUNNING: advance(dt)
 arena.queue_redraw()
 ui.update_hud()

func advance(dt: float) -> void:
 if state != State.RUNNING: return
 elapsed += dt
 # Only this method advances simulation. UI animation remains independent.
 var wave_finished: bool = waves.step(dt, self)
 weapons.step(dt, self)
 for enemy in enemies:
  if enemy.hp > 0: enemy.step(dt, center, tower)
 for i in range(enemies.size() - 1, -1, -1):
  var enemy = enemies[i]
  if enemy.hp <= 0:
   kills += 1
   add_effect("burst", enemy.pos, enemy.pos, enemy.stats.color, 0.42, enemy.stats.size)
   enemies.remove_at(i)
 for i in range(effects.size() - 1, -1, -1):
  effects[i].left -= dt
  if effects[i].left <= 0: effects.remove_at(i)
 # On a simultaneous lethal trade, the reactor must survive to win.
 if tower.hp <= 0:
  finish(false)
 elif boss != null and boss.hp <= 0:
  finish(true)
 elif wave_finished:
  finish_wave()

func spawn_enemy(kind: String, position: Vector2 = Vector2.INF):
 if enemies.size() >= B.MAX_ENEMIES: return null
 if position == Vector2.INF:
  var side = rng.randi_range(0, 3)
  var along = rng.randf()
  match side:
   0: position = Vector2(arena_rect.position.x, lerpf(arena_rect.position.y, arena_rect.end.y, along))
   1: position = Vector2(arena_rect.end.x, lerpf(arena_rect.position.y, arena_rect.end.y, along))
   2: position = Vector2(lerpf(arena_rect.position.x, arena_rect.end.x, along), arena_rect.position.y)
   3: position = Vector2(lerpf(arena_rect.position.x, arena_rect.end.x, along), arena_rect.end.y)
 var enemy = Enemy.new(kind, position, waves.number)
 enemies.append(enemy)
 return enemy

func finish_wave() -> void:
 if state != State.RUNNING or waves.number >= 10: return
 state = State.UPGRADE
 sound.stop_all()
 var unlock := ""
 if waves.number == 1 and not data.cryo:
  data.cryo = true
  unlock = "ОТКРЫТО ОРУДИЕ: КРИОПУШКА"
 if waves.number == 3 and not data.tesla:
  data.tesla = true
  unlock = "ОТКРЫТО ОРУДИЕ: ТЕСЛА"
 save_records()
 offered = Upgrades.offer(tower, data, rng)
 ui.show_upgrades(offered, unlock)

func choose_upgrade(id: String) -> void:
 if state != State.UPGRADE or id not in offered: return
 Upgrades.apply(id, tower)
 offered.clear()
 next_wave()

func next_wave() -> void:
 if state != State.UPGRADE: return
 # With no eligible cards the UI exposes this same continuation.
 if not offered.is_empty(): return
 waves.next()
 state = State.RUNNING
 if waves.number == 10:
  boss = spawn_enemy("boss", Vector2(center.x, arena_rect.position.y))
  # Reserve a boss slot even in artificially saturated arenas.
  if boss == null:
   enemies.pop_back()
   boss = spawn_enemy("boss", Vector2(center.x, arena_rect.position.y))
  for i in range(4): spawn_enemy("normal")
 save_records()
 sound.play_sound("upgrade")
 ui.show_hud()
 ui.announce("ВОЛНА %02d" % waves.number, "Носитель. Уничтожьте ядро." if waves.number == 10 else "Периметр снова открыт")

func pause_run() -> void:
 if state != State.RUNNING: return
 state = State.PAUSED
 sound.stop_all()
 save_records()
 ui.show_pause()

func resume_run() -> void:
 if state != State.PAUSED: return
 state = State.RUNNING
 ui.show_hud()

func to_menu() -> void:
 save_records()
 state = State.MENU
 enemies.clear()
 effects.clear()
 weapons.projectiles.clear()
 sound.stop_all()
 boss = null
 ui.show_menu()

func finish(won: bool) -> void:
 if state != State.RUNNING: return
 state = State.VICTORY if won else State.GAME_OVER
 if won: data.wins += 1
 save_records()
 sound.stop_all()
 sound.play_sound("victory" if won else "defeat")
 ui.show_result(won)

func save_records() -> void:
 data.wave = maxi(data.wave, waves.number)
 data.kills = maxi(data.kills, kills)
 persist()

func persist() -> void:
 if not test_mode: Save.write_data(data)

func toggle_sound() -> void:
 data.sound = not data.sound
 sound.enabled = data.sound
 if not data.sound: sound.stop_all()
 persist()
 ui.show_menu()

func add_effect(kind: String, from: Vector2, to: Vector2, color: Color, duration: float, radius: float = 15) -> void:
 if effects.size() >= 220: effects.pop_front()
 effects.append({"kind": kind, "from": from, "to": to, "color": color, "left": duration, "duration": duration, "radius": radius})

func _unhandled_key_input(event: InputEvent) -> void:
 if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_P]:
  if state == State.RUNNING: pause_run()
  elif state == State.PAUSED: resume_run()
  get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
 if what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT]:
  if ui != null and state == State.RUNNING: pause_run()
 elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
  if state == State.RUNNING: pause_run()
  elif state == State.PAUSED: resume_run()
  elif state == State.MENU: get_tree().quit()
 elif what == NOTIFICATION_WM_CLOSE_REQUEST:
  if ui != null and state != State.MENU: save_records()
  get_tree().quit()
