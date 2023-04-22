tool
class_name ZIPReader


###
### Typed wrapper for gdnative ZIPReader
###


#section members


const ERR_BYTEARRAY := PoolByteArray()

var _instance
var path: String setget , _get_zip_path
var trace: bool setget set_trace, get_trace


#section lifecycle


func _init() -> void:
	_instance = GDNativeZipFileReader.new()


#section methods


func get_trace() -> bool:
	return _instance.trace if _instance != null else false


func set_trace(value: bool) -> void:
	if _instance == null: return

	_instance.trace = value


func read(path: String) -> int:
	return _instance.open(path)


func open(path: String) -> int:
	return _instance.open(path)


func close() -> void:
	_instance.close()


func get_paths() -> PoolStringArray:
	return _instance.get_paths()


func get_dirs() -> PoolStringArray:
	return _instance.get_dirs()


func get_files() -> PoolStringArray:
	return _instance.get_files()


func read_file(path: String, case_sensitive: bool = false) -> PoolByteArray:
	return _instance.read_file(path) #, case_sensitive)


func has_path(path: String) -> bool:
	return _instance.has_path(path) as bool


func has_file(path: String) -> bool:
	return not path.ends_with('/') and _instance.has_path(path)


func uncompress(path: String) -> PoolByteArray:
	return read_file(path) as PoolByteArray # , false) as PoolByteArray


func _get_zip_path() -> String:
	return _instance.path as String
