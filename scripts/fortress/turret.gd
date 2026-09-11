extends RefCounted
# One mounted weapon: its own cell, pivot, barrel, range and fire timer.
const C = preload("res://scripts/fortress/config.gd")
var kind: String
var cell: Vector2i
var stats: Dictionary
var pivot: Vector2
var aim := 0.0
var cooldown := 0.0
var recoil := 0.0
var shots := 0
var has_target := false

func _init(type: String, at: Vector2i) -> void:
 kind = type
 cell = at
 stats = C.WEAPONS[type]
 pivot = C.cell_center(at) + Vector2(0, 4)

# Tesla discharges from the top of its coil; the other barrels swivel around the pivot.
func origin_toward(point: Vector2) -> Vector2:
 if kind == "tesla": return pivot + Vector2(0, -stats.barrel)
 return pivot + (point - pivot).normalized() * stats.barrel

func muzzle() -> Vector2:
 return origin_toward(pivot + Vector2.from_angle(aim))

# Range is measured from this barrel to the target's edge, inside the forward arc and the visible field.
func can_reach(enemy, field_right: float) -> bool:
 if enemy.hp <= 0 or enemy.pos.x > field_right: return false
 var offset: Vector2 = enemy.pos - origin_toward(enemy.pos)
 if absf(offset.angle()) > C.ARC: return false
 return offset.length() - enemy.stats.size <= stats.range
