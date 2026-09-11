extends Node
var enabled := true
var players: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var voice := 0

func _ready() -> void:
 for id in ["shot", "hit", "upgrade", "victory", "defeat"]:
  streams[id] = load("res://audio/" + id + ".wav")
 for i in range(10):
  var player := AudioStreamPlayer.new()
  player.volume_db = -15.0
  add_child(player)
  players.append(player)

func play_sound(id: String) -> void:
 if not enabled or not streams.has(id) or players.is_empty(): return
 var player = players[voice % players.size()]
 voice += 1
 player.stream = streams[id]
 player.play()

func stop_all() -> void:
 for player in players: player.stop()
