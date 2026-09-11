extends RefCounted
# Kept apart from the classic reactor.json: the two formats are incompatible.
const PATH = "user://fortress.json"
const VERSION = 1
const LIMITS = {"runs": 100000000, "wins": 100000000, "best_stage": 4, "best_distance": 100000, "fastest_win": 36000}

static func defaults() -> Dictionary:
 return {"version": VERSION, "runs": 0, "wins": 0, "best_stage": 0, "best_distance": 0, "fastest_win": 0, "sound": true}

static func read_data(path: String = PATH) -> Dictionary:
 var result = defaults()
 if not FileAccess.file_exists(path): return result
 var parser := JSON.new()
 if parser.parse(FileAccess.get_file_as_string(path)) != OK: return result
 var parsed = parser.data
 if not parsed is Dictionary: return result
 var version = parsed.get("version")
 if not (version is float or version is int) or int(version) != VERSION: return result
 if parsed.get("sound") is bool: result.sound = parsed.sound
 for key in LIMITS:
  var value = parsed.get(key)
  if (value is float or value is int) and is_finite(float(value)):
   result[key] = clampi(int(value), 0, LIMITS[key])
 return result

static func write_data(data: Dictionary, path: String = PATH) -> void:
 var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
 if file == null: return
 file.store_string(JSON.stringify(data))
 file.close()
 DirAccess.rename_absolute(path + ".tmp", path)
