tool
class_name ZIPWriter


###
### Typed wrapper for gdnative ZIPWriter
###


#section members

const ERR_BYTEARRAY := PoolByteArray()

var _instance = GDNativeZipFileWriter.new()

var source_dir: String
var out_file: String


#section lifecycle


func _init() -> void:
	pass


#section methods


func write_zip(source_dir: String = self.source_dir, out_file: String = self.out_file) -> int:
	if source_dir.empty():
		push_error("Empty source_dir.")
		return ERR_INVALID_PARAMETER
	if out_file.empty():
		push_error("Empty out_file.")
		return ERR_INVALID_PARAMETER

	return _instance.write_zip(source_dir, out_file)
