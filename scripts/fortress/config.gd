extends RefCounted
# Tuning of the «Кочевой бастион» mode. World units: road surface at y = 0, up is negative,
# the carrier stays near x = 0 and the world scrolls under it.

# Tower grid above the chassis deck.
const COLS = 4
const ROWS = 6
const CELL = 72.0
const GRID_X = 30.0
const DECK_Y = -118.0
const START_BLOCK = Vector2i(1, 0)
const START_WEAPON = "mg"

# Chassis and battle field.
const CHASSIS_FRONT = 368.0
const REACTOR = Vector2(184, -88)
const TOWER_EXTENT = 590.0
const VIEW_WIDTH = 760.0
const SPAWN_MARGIN = 12.0
const FLIGHT_BAND = Vector2(-470, -170)
const MAX_ENEMIES = 40
const MAX_EFFECTS = 220

# Screen layout in viewport pixels (720 px wide base, taller on 9:20).
const HUD_HEIGHT = 244.0
const PANEL_HEIGHT = 392.0
const DRAG_LIFT = 40.0

# Fortress and route.
const HEALTH = 200.0
const HP_PER_CELL = 12.0
const STOP_REPAIR = 0.1
const SKIP_REPAIR = 20.0
const SPEED = 36.0
const UNITS_PER_METER = 10.0
const SEGMENT_SECONDS = 25.0
const SPAWN_CUTOFF = 0.88
const HP_GROWTH = 0.15
# Weapons swivel inside the forward half-plane only.
const ARC = 1.54

const SHAPES = {
 "1x1": {"name": "Блок 1×1", "text": "Одна клетка — опора для орудия", "cells": [Vector2i(0, 0)]},
 "2x1": {"name": "Балка 2×1", "text": "Расширяет этаж на две клетки", "cells": [Vector2i(0, 0), Vector2i(1, 0)]},
 "1x2": {"name": "Стойка 1×2", "text": "Поднимает башню на этаж выше", "cells": [Vector2i(0, 0), Vector2i(0, 1)]},
 "L": {"name": "Уголок", "text": "Три клетки: этаж и подъём сразу", "cells": [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)]}}

const WEAPONS = {
 "mg": {"name": "Пулемёт", "text": "Часто бьёт одну цель", "damage": 8.0, "rate": 5.0, "range": 430.0, "barrel": 32.0},
 "cryo": {"name": "Криопушка", "text": "Снаряд по области, замедляет", "damage": 22.0, "rate": 0.55, "range": 470.0, "barrel": 30.0, "radius": 90.0, "slow": 2.2, "factor": 0.45, "speed": 520.0},
 "tesla": {"name": "Тесла", "text": "Цепной разряд, +30% по замедленным", "damage": 18.0, "rate": 0.75, "range": 320.0, "barrel": 26.0, "jump": 150.0, "targets": 4, "slowed_bonus": 1.3}}

# lift: body centre above the road; armor: flat reduction of every hit; slow_factor overrides the cryo slow;
# gold: scrap paid out when the enemy dies.
const ENEMIES = {
 "normal": {"name": "Трутень", "hp": 46.0, "speed": 48.0, "damage": 5.0, "interval": 1.4, "size": 20.0, "lift": 28.0, "armor": 0.0, "gold": 6, "color": Color("e0553a")},
 "runner": {"name": "Шершень", "hp": 24.0, "speed": 92.0, "damage": 4.0, "interval": 1.0, "size": 14.0, "lift": 0.0, "armor": 0.0, "flying": true, "gold": 8, "color": Color("f0a33c")},
 "heavy": {"name": "Панцирник", "hp": 220.0, "speed": 36.0, "damage": 12.0, "interval": 2.0, "size": 30.0, "lift": 40.0, "armor": 4.0, "gold": 22, "color": Color("9a6bd8")},
 "boss": {"name": "Носитель", "hp": 1300.0, "speed": 24.0, "damage": 16.0, "interval": 2.4, "size": 84.0, "lift": 150.0, "armor": 2.0, "slow_factor": 0.85, "gold": 250, "color": Color("3f86c4")}}

# Enemies arrive in packs: every `every` seconds a pack of pack.x..pack.y, PACK_GAP seconds apart.
const PACK_GAP = 0.35
const SEGMENTS = [
 {"every": 3.2, "pack": Vector2i(2, 3), "mix": {"normal": 0.85, "runner": 0.15}},
 {"every": 3.0, "pack": Vector2i(3, 4), "mix": {"normal": 0.6, "runner": 0.3, "heavy": 0.1}},
 {"every": 2.8, "pack": Vector2i(3, 5), "mix": {"normal": 0.5, "runner": 0.3, "heavy": 0.2}}]

const BOSS = {"escort": ["normal", "normal", "runner"], "summon": ["normal", "runner", "normal"], "summon_every": 9.0, "warning": 1.3, "stop": 96.0}

# Energy builds up during a battle and pays for the ability cards under the road.
const ENERGY_MAX = 20
const ENERGY_RATE = 0.8
const ENERGY_START = 4.0
const ABILITIES = [
 {"id": "grenade", "name": "Граната", "cost": 2, "text": "Взрыв по ближним врагам", "damage": 60.0, "radius": 130.0},
 {"id": "burst", "name": "Залп", "cost": 8, "text": "Урон всем врагам на поле", "damage": 120.0},
 {"id": "rapid", "name": "Шквал", "cost": 10, "text": "Вдвое быстрее стрельба, 6 с", "seconds": 6.0}]

# Stop 0 is the depot before the first battle; stops 1..3 follow the regular segments.
const REWARDS = [
 {"piece": "1x1", "weapon": "cryo"},
 {"piece": "2x1", "weapon": "tesla"},
 {"piece": "1x2", "weapon": "mg"},
 {"piece": "L", "weapon": "tesla"}]

static func cell_rect(cell: Vector2i) -> Rect2:
 return Rect2(GRID_X + cell.x * CELL, DECK_Y - (cell.y + 1) * CELL, CELL, CELL)

static func cell_center(cell: Vector2i) -> Vector2:
 return cell_rect(cell).get_center()

static func grid_rect() -> Rect2:
 return Rect2(GRID_X, DECK_Y - ROWS * CELL, COLS * CELL, ROWS * CELL)

static func shape_size(shape: String) -> Vector2i:
 var size := Vector2i.ONE
 for cell in SHAPES[shape].cells: size = Vector2i(maxi(size.x, cell.x + 1), maxi(size.y, cell.y + 1))
 return size

static func piece_center(shape: String, origin: Vector2i) -> Vector2:
 var size = shape_size(shape)
 return Vector2(GRID_X + (origin.x + size.x * 0.5) * CELL, DECK_Y - (origin.y + size.y * 0.5) * CELL)

static func route_length() -> float:
 return SEGMENTS.size() * SEGMENT_SECONDS * SPEED
