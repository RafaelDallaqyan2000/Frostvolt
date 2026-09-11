extends "res://scripts/sound.gd"
# Classic voice pool plus the construction and Tesla cues of the fortress mode.
const EXTRA = ["build", "deny", "zap"]
const MIN_GAP_MS = 45
var last_played: Dictionary = {}

func _ready() -> void:
 super()
 for id in EXTRA: streams[id] = load("res://audio/" + id + ".wav")

func play_sound(id: String) -> void:
 # Several guns firing in the same frame would otherwise stack identical samples.
 var now := Time.get_ticks_msec()
 if now - int(last_played.get(id, -100000)) < MIN_GAP_MS: return
 last_played[id] = now
 super(id)
