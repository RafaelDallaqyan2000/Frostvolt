extends RefCounted
const WAVE_SECONDS = 30.0
const MAX_ENEMIES = 150
const HEALTH = 180.0
const MG = {"damage": 13.0, "rate": 4.0, "range": 300.0}
const CRYO = {"damage": 22.0, "rate": 0.65, "range": 330.0, "radius": 100.0, "slow": 2.0, "factor": 0.42, "speed": 480.0}
const TESLA = {"damage": 26.0, "rate": 0.85, "range": 280.0, "jump": 145.0, "targets": 3}
const ENEMIES = {
 "normal": {"hp": 30.0, "speed": 37.0, "damage": 4.0, "interval": 1.6, "size": 16.0, "color": Color("f38373")},
 "runner": {"hp": 18.0, "speed": 70.0, "damage": 3.0, "interval": 1.2, "size": 12.0, "color": Color("f8cb6b")},
 "heavy": {"hp": 110.0, "speed": 23.0, "damage": 9.0, "interval": 2.2, "size": 24.0, "color": Color("b898fc")},
 "boss": {"hp": 2200.0, "speed": 17.0, "damage": 13.0, "interval": 2.0, "size": 43.0, "color": Color("ff507e")}}
