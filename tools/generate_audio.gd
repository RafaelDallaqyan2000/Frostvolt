extends SceneTree
# Deterministic, original PCM effects. Run once; resulting WAVs ship with the game.
func _initialize() -> void:
 DirAccess.make_dir_recursive_absolute("res://audio")
 var rng := RandomNumberGenerator.new()
 rng.seed = 90421
 for id in ["shot", "hit", "upgrade", "victory", "defeat"]:
  var duration = {"shot": 0.065, "hit": 0.14, "upgrade": 0.32, "victory": 1.1, "defeat": 0.85}[id]
  var samples := PackedByteArray()
  var sample_rate := 22050
  samples.resize(int(duration * sample_rate) * 2)
  for i in range(samples.size() / 2):
   var t = float(i) / sample_rate
   var envelope = minf(1, t / 0.006) * pow(1.0 - t / duration, 2)
   var frequency := 440.0
   var signal_value := 0.0
   match id:
    "shot": signal_value = sin(TAU * (180 * t - 700 * t * t)) * 0.5 + rng.randf_range(-1, 1) * 0.45
    "hit": signal_value = rng.randf_range(-1, 1) * 0.5 + sin(TAU * 90 * t) * 0.4
    "upgrade":
     frequency = 523.25 if t < 0.1 else (659.25 if t < 0.2 else 783.99)
     signal_value = sin(TAU * frequency * t) * 0.65
    "victory":
     frequency = [523.25, 659.25, 783.99, 1046.5][mini(3, int(t / 0.18))]
     signal_value = sin(TAU * frequency * t) * 0.5 + sin(TAU * frequency * 0.5 * t) * 0.2
    "defeat": signal_value = sin(TAU * (260 * t - 95 * t * t)) * 0.65
   samples.encode_s16(i * 2, int(clampf(signal_value * envelope, -1, 1) * 22000))
  var stream := AudioStreamWAV.new()
  stream.format = AudioStreamWAV.FORMAT_16_BITS
  stream.mix_rate = sample_rate
  stream.data = samples
  stream.save_to_wav("res://audio/" + id + ".wav")
 print("Generated five original WAV effects.")
 quit()
