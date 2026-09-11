extends SceneTree
func _initialize() -> void:
 var data = preload("res://scripts/save.gd").read_data("user://reactor-test-only.json")
 var ok = data.cryo and data.tesla and data.wave == 10 and data.kills == 321 and data.wins == 2 and not data.sound
 print("SEPARATE PROCESS SAVE RELOAD: ", "PASS" if ok else "FAIL")
 quit(0 if ok else 1)
