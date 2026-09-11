extends Node2D
const SHADER = preload("res://art/creature.gdshader")
const TEXTURES = {
 "normal": preload("res://art/scarab.png"),
 "runner": preload("res://art/spider.png"),
 "heavy": preload("res://art/brute.png"),
 "boss": preload("res://art/broodmother.png")}
const SIZES = {"normal": 84.0, "runner": 86.0, "heavy": 118.0, "boss": 190.0}
var enemy
var game
var sprite: Sprite2D
var ink: ShaderMaterial
var dying := false
var death_age := 0.0

func _ready() -> void:
 sprite = Sprite2D.new()
 sprite.texture = TEXTURES[enemy.kind]
 ink = ShaderMaterial.new()
 ink.shader = SHADER
 sprite.material = ink
 add_child(sprite)
 sync()

func sync() -> void:
 if dying: return
 position = enemy.pos
 var speed = {"normal": 1.0, "runner": 1.65, "heavy": 0.55, "boss": 0.45}[enemy.kind]
 var phase: float = enemy.motion_clock * speed + fmod(enemy.max_hp, 3.0)
 var entering = clampf(enemy.age / 0.28, 0.0, 1.0)
 var moving: bool = enemy.pos.distance_to(game.center) > 40 + enemy.stats.size
 var stride = sin(phase * 10.0) * (1.0 if moving else 0.12)
 var breath = sin(phase * 3.0) * 0.018
 var attack_push = sin((1.0 - enemy.lunge / 0.3) * PI) * 10.0 if enemy.lunge > 0 else 0.0
 var recoil_push: float = enemy.recoil / 0.18 * 3.0
 sprite.rotation = enemy.facing + stride * 0.045 + (PI if enemy.kind == "runner" else 0.0)
 sprite.position = Vector2(0, -attack_push + recoil_push).rotated(enemy.facing)
 var base_scale = SIZES[enemy.kind] / sprite.texture.get_width()
 sprite.scale = Vector2(1.0 + breath - stride * 0.035, 1.0 - breath + stride * 0.028) * base_scale * lerpf(0.6, 1.0, entering)
 sprite.modulate.a = entering
 ink.set_shader_parameter("motion_phase", phase)
 ink.set_shader_parameter("gait_strength", 1.0 if moving else 0.12)
 ink.set_shader_parameter("slow_amount", 1.0 if enemy.slow > 0 else 0.0)
 ink.set_shader_parameter("hit_flash", enemy.flash / 0.1)
 queue_redraw()

func die() -> void:
 dying = true
 death_age = 0
 ink.set_shader_parameter("hit_flash", 0.6)

func step_death(dt: float) -> bool:
 death_age += dt
 sprite.modulate.a = maxf(0, 1.0 - death_age / 0.38)
 sprite.rotation += dt * 1.6
 sprite.scale *= pow(0.25, dt)
 ink.set_shader_parameter("dissolve", death_age / 0.38)
 queue_redraw()
 return death_age >= 0.38

func _draw() -> void:
 if dying: return
 var radius: float = SIZES[enemy.kind] * 0.30
 draw_set_transform(Vector2(0, 7), 0, Vector2(1, 0.62))
 draw_circle(Vector2.ZERO, radius, Color(0, 0, 0, 0.4))
 draw_set_transform(Vector2.ZERO)
 if enemy.age < 0.35:
  draw_arc(Vector2.ZERO, radius + 16.0 * (1.0 - enemy.age / 0.35), 0, TAU, 32, Color(enemy.stats.color, 0.65 * (1.0 - enemy.age / 0.35)), 2, true)
 if enemy.slow > 0:
  draw_arc(Vector2.ZERO, radius + 5, 0, TAU, 32, Color(0.35, 0.8, 1, 0.5), 1.6, true)
 if enemy.hp < enemy.max_hp and enemy.kind != "boss":
  var bar_pos = Vector2(-20, radius + 14)
  draw_rect(Rect2(bar_pos, Vector2(40, 4)), Color("101621"))
  draw_rect(Rect2(bar_pos, Vector2(40 * maxf(0, enemy.hp / enemy.max_hp), 4)), Color("76d9ff") if enemy.slow > 0 else enemy.stats.color)
