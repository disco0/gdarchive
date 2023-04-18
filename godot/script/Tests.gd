class_name ArchiveTests


const TestArchivesBase := 'res://tests/archives'
const TestDirectoriesBase := 'res://tests/directories'


static func StripTestBase(path: String, roots := [ TestArchivesBase, TestDirectoriesBase ]) -> String:
	if not path.is_abs_path(): return path

	path = path.simplify_path()

	for root in roots:
		var root_dir := (root as String) + "/"
		if path.begins_with(root_dir):
			return path.trim_prefix(root_dir)

		var global_root_dir := ProjectSettings.globalize_path(root as String) + "/"
		if path.begins_with(global_root_dir):
			return path.trim_prefix(global_root_dir)

	return path


static func GetTestArchives(root: String = TestArchivesBase) -> PoolStringArray:
	var paths := PoolStringArray()

	var dir: Directory = Directory.new()
	var open_err := dir.open(root)
	if not open_err == OK:
		assert(open_err == OK, 'Failed to open test archives root directory <%s>' % [ root ])
		return paths

	dir.list_dir_begin(true, true)
	var leaf := dir.get_next()
	var curr_path: String
	while leaf:
		if dir.current_is_dir():
			leaf = dir.get_next()
			continue

		curr_path = dir.get_current_dir().plus_file(leaf)

		paths.push_back(curr_path)

		leaf = dir.get_next()

	return paths


static func GetTestDirectories(root: String = TestDirectoriesBase) -> PoolStringArray:
	var paths := PoolStringArray()

	var dir: Directory = Directory.new()
	var open_err := dir.open(root)
	if not open_err == OK:
		assert(open_err == OK, 'Failed to open test directories root directory <%s>' % [ root ])
		return paths

	dir.list_dir_begin(true, true)
	var leaf := dir.get_next()
	var curr_path: String
	while leaf:
		if dir.current_is_dir():
			paths.push_back(dir.get_current_dir().plus_file(leaf))

		leaf = dir.get_next()

	return paths
