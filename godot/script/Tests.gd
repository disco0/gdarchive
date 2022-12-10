class_name Tests


const TestsBaseDir := 'res://tests'
const TestArchivesBaseDir := TestsBaseDir + '/archives'


static func GetTestArchives(root: String = TestArchivesBaseDir) -> PoolStringArray:
	var paths := PoolStringArray()

	var dir: Directory = Directory.new()
	assert(dir.open(root) == OK, 'Failed to open test archives dir <%s>' % [ root ])

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
