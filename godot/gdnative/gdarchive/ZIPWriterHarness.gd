tool
class_name ZIPWriter


###
### Typed wrapper for gdnative ZIPWriter
###


#section members


const ERR_BYTEARRAY := PoolByteArray()

var _instance = GDNativeZipFileWriter.new()

var source_dir: String
var output_path: String
var trace: bool setget set_trace, get_trace


#section lifecycle


#section methods


func get_trace() -> bool:
	return _instance.trace if _instance != null else false


func set_trace(value: bool) -> void:
	if _instance == null: return

	_instance.trace = value


func write_zip(source_dir: String = self.source_dir, output_path: String = self.output_path) -> int:
	if source_dir.empty():
		push_error("Empty source_dir.")
		return ERR_INVALID_PARAMETER

	_instance.source_dir = source_dir

	if output_path.empty():
		push_error("Empty output_path.")
		return ERR_INVALID_PARAMETER

	_instance.output_path = output_path

	return _instance.write_zip()
