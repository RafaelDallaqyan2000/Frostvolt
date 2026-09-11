extends SceneTree
# Deterministic, original PCM cues for the fortress mode. The five classic sounds are not regenerated.
func _initialize() -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = 51207
 for id in ["build", "deny", "zap"]:
  var duration = {"build": 0.22, "deny": 0.2, "zap": 0.18}[id]
  var sample_rate := 22050
  var samples := PackedByteArray()
  samples.resize(int(duration * sample_rate) * 2)
  for i in range(samples.size() / 2):
   var t = float(i) / sample_rate
   var envelope = minf(1, t / 0.004) * pow(1.0 - t / duration, 2)
   var value := 0.0
   match id:
    "build":
     value = sin(TAU * (120 * t - 160 * t * t)) * 0.7 + sin(TAU * 1250 * t) * 0.14 * exp(-t * 40)
     if t < 0.03: value += rng.randf_range(-1, 1) * 0.35
    "deny":
     var gate = 1.0 if t < 0.08 or t > 0.11 else 0.0
     value = (1.0 if fmod(t * 140, 1.0) < 0.5 else -1.0) * 0.3 * gate
    "zap": value = rng.randf_range(-1, 1) * 0.4 * (0.5 + 0.5 * sin(TAU * 60 * t)) + sin(TAU * (900 - 2600 * t) * t) * 0.3
   samples.encode_s16(i * 2, int(clampf(value * envelope, -1, 1) * 22000))
  var stream := AudioStreamWAV.new()
  stream.format = AudioStreamWAV.FORMAT_16_BITS
  stream.mix_rate = sample_rate
  stream.data = samples
  stream.save_to_wav("res://audio/" + id + ".wav")
 print("Generated three fortress cues.")
 quit()
