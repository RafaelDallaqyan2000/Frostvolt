extends RefCounted
const PATH = "user://reactor.json"
static func defaults() -> Dictionary:
 return {"cryo": false, "tesla": false, "wave": 0, "kills": 0, "wins": 0, "sound": true}
static func read_data(path: String = PATH) -> Dictionary:
 var result = defaults()
 if not FileAccess.file_exists(path): return result
 var parser := JSON.new()
 if parser.parse(FileAccess.get_file_as_string(path)) != OK: return result
 var parsed = parser.data
 if not parsed is Dictionary: return result
 for key in ["cryo", "tesla", "sound"]:
  if parsed.get(key) is bool: result[key] = parsed[key]
 for key in ["wave", "kills", "wins"]:
  var value = parsed.get(key)
  if (value is float or value is int) and is_finite(float(value)):
   result[key] = clampi(int(value), 0, 10 if key == "wave" else 100000000)
 return result
static func write_data(data: Dictionary, path: String = PATH) -> void:
 var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
 if file == null: return
 file.store_string(JSON.stringify(data))
 file.close()
 DirAccess.rename_absolute(path + ".tmp", path)
