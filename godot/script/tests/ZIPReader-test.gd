class_name ZIPReaderTest
extends PanelContainer

const ERR_BYTEARRAY := PoolByteArray()

onready var run_button := $"Content/Header/Run"
onready var output := $"Content/OutputScroll/Output"
onready var tree := get_tree()
onready var timer: Stopwatch
onready var sub_timer: Stopwatch

var TestName := 'ZIPReaderTest'


func _ready() -> void:
	timer = Stopwatch.new()
	add_child(timer)
	
	sub_timer = Stopwatch.new()
	add_child(sub_timer)


func output(msg: String, no_ui: = false) -> void:
	#print('[%s] %s' % [ TestName, msg ])
	if no_ui: return

	output.bbcode_text += msg + '\n'


func output_color(msg: String, color) -> void:
	output(BB.Color(msg, color))


func output_error(msg: String, no_ui: = false) -> void:
	output(BB.BoldColor('ERROR: %s' % [ msg ], '#FF0000'))


func output_section(name: String, no_ui: = false) -> void:
	#print('\n\n[%s] %s' % [ TestName, name ])
	if no_ui: return

	output.bbcode_text += '\n\n%s\n' % [ BB.BoldColor(name, '#0088FF') ]


const TimerSections := { 
	PathEnum = "Path Enumeration"
}


func test() -> void:
	var instance := ZIPReader.new()
	assert(is_instance_valid(instance), 'Failed to create ZIPReader instance.')

	output_section("Testing Path Enumeration:")
	timer.start()
	var read_tree_error_file := test_archives_read_tree()
	timer.stop()
	if read_tree_error_file.empty():
		output("  Parsed tree in all archives.")
	else:
		output("  Failed on archive: %s" % [ read_tree_error_file ])

	output_section("Testing File Decompression:")
	yield(get_tree(), "idle_frame")
	yield(test_archives_expansion(), "completed")

	#output_section("Testing File Extraction")
	#var result = yield(test_archive_extraction(), "completed")

	#if result != true:
	#	var msg := "Expansion test failed with return value: %s " % [ result ]
	#	output_error(msg)
	#	assert(result == true, msg)


func test_archives_read_tree(archive_paths := Tests.GetTestArchives()) -> String:
	var instance = ZIPReader.new()
	var target: String
	for path in archive_paths:
		target = ProjectSettings.globalize_path(path.simplify_path())
		assert(not target.empty(), "Empty target path.")
		if not instance.open(target):
			output('\t- %s' % [ target ])
			output('\t  X Failed to open')
			return path

		# Read path property
		var instance_path: String = instance.path
		assert(not instance_path.empty(), "Empty path property on native object.")
		output('\t- %s' % [ instance_path ])

		#output('    Enumerating files')
		var files = instance.get_files() as PoolStringArray
		if files.empty():
			output('\t    X No files')
			return path
		else:
			for zip_leaf in files:
				output('\t\t- ./%s' % [ zip_leaf ], true)

	return ""


func test_archives_expansion():
	var TEST_ALL_FILES = [ '<ALL>' ]
	var tests := {
		"test-pack-fixture.zip":
			TEST_ALL_FILES,
		"test-pack-gauntlet.zip":
			TEST_ALL_FILES,
		"test-basic-level.zip":
			TEST_ALL_FILES,
		"test-basic-mod.zip":
			TEST_ALL_FILES,
		"test-level-fixture.zip":
			TEST_ALL_FILES,
		"test-mod-fixture.zip":
			TEST_ALL_FILES,
	}
	var zip_path: String
	var file_list: Array

	var full_start_usec := Time.get_ticks_usec()
	sub_timer.clear()
	var longest := {
		zip = "",
		path = "",
		usecs = 0,
		size = 0,
	}

	for archive_name in tests.keys():
		zip_path = Tests.TestArchivesBaseDir.plus_file(archive_name)

		file_list = tests[archive_name]

		output('Loading %s' % [ zip_path ])
		yield(tree, "idle_frame")

		var zip := ZIPReader.new()

		sub_timer.start()
		var zip_opened = zip.open(zip_path)
		sub_timer.stop()

		if not zip_opened:
			output('\t X | LOAD FAILED')
			yield(tree, "idle_frame")
			continue

		if file_list == TEST_ALL_FILES:
			sub_timer.start()
			file_list = Array(zip.get_files())
			sub_timer.stop()

		for leaf in file_list:
			#yield(tree.create_timer(0.1), "timeout")
			output('\t - %s' % [ leaf ])

			if not leaf in file_list:
				output_error('\t   X | FILE NOT FOUND')
				continue

			# yield(tree, "idle_frame")

			var start_usec := Time.get_ticks_usec()
			sub_timer.start()
			var result: PoolByteArray = zip.read_file(leaf, false)
			sub_timer.stop()
			# Update longest decompression time
			if sub_timer.last_time > longest.usecs:
				longest = {
					path  = leaf,
					usecs = sub_timer.last_time,
					zip   = zip_path,
					size  = result.size()
				}
			#var end_usec := Time.get_ticks_usec()
			var elapsed_msec := Stopwatch.UsecToMsec(sub_timer.last_time) # (end_usec - start_usec) / 1_000.0

			if result == ERR_BYTEARRAY:
				output('\t X | ERR_BYTEARRAY')
				yield(tree, "idle_frame")
				continue

			output_color('\t\tSUCCESS (%.2f %s)\n' % 
							[ elapsed_msec / (1000.0 if elapsed_msec > 1000.0 else 1.0),
							  ('sec' if elapsed_msec > 1000.0 else 'ms') ],
						"#88CCAA")
			yield(tree, "idle_frame")

	# Sum laps in stopwatch
	var full_elapsed_usec := 0.0
	for time in sub_timer.times:
		full_elapsed_usec += time
	var full_elapsed_msec: float = Stopwatch.UsecToMsec(full_elapsed_usec)
	#var full_end_usec := Time.get_ticks_usec()
	#var full_elapsed_msec := (full_end_usec - full_start_usec) / 1_000.0
	output_color('\n--------\nSUCCESS (%.2f %s)\n--------' 
				% [
					full_elapsed_msec / (1000.0 if full_elapsed_msec > 1000.0 else 1.0),
					('sec' if full_elapsed_msec > 1000.0 else 'ms')
				], 
				"#00FF33")
	
	if not longest.usecs == 0:
		var out := PoolStringArray([
			"\tLongest Decompression:",
			"\t\tTime:  %.2fms" % [ Stopwatch.UsecToMsec(longest.usecs) ],
			"\t\tSize:  %dMB"   % [ longest.size / 1_000_000.0 ],
			"\t\tFile:  %s"     % [ longest.path ],
			"\t\tZip:   %s"     % [ longest.zip  ],
		])
		output_color(out.join('\n'), '#55FF88')


###
### Handles zip content extraction. Cleanup of copied files is not handled on failure,
### and needs to be handled by caller.
###
### `strict` disables overwriting, and should be passed an empty (or non-existent) directory path
###
func test_archive_extraction(archive_paths := Tests.GetTestArchives(), out_dir = "res://test-output"):
	out_dir =  ProjectSettings.globalize_path(out_dir.simplify_path())
	var dir: Directory = Directory.new()

	output('Extracting archives to path: %s' % [ out_dir ])

	# Prepare out_dir
	if not dir.dir_exists(out_dir):
		var file_exists := dir.file_exists(out_dir)
		if file_exists:
			var msg := 'Output directory path exists and is file: %s' % [ out_dir ]
			assert(false, msg)

			#dprint.error(msg, '_copy_zip_content')
			return false

		var mkdirp_err := dir.make_dir_recursive(out_dir)
		assert(mkdirp_err == OK, 'Error creating output directory: %s (%s)' % [ mkdirp_err, out_dir ])
		if mkdirp_err != OK:

			#dprint.error('Failed to create output directory: <%s>' % [ out_dir ], '_install_zip_content')
			assert(false, 'Failed to create output directory: <%s>' % [ out_dir ])
			return false

	#return true

	###
	### Prepare for tests, clean output dir (except .gdignore)
	###
	assert(dir.open(out_dir) == OK)
	dir.list_dir_begin(true, true)
	var leaf = dir.get_next()
	var leaf_path: String
	while not leaf.empty():
		leaf_path = dir.get_current_dir().plus_file(leaf)
		output('[clearing %s]' % [ leaf ])

		if leaf != '.gdignore':
			RecursiveRemove(leaf_path)

		leaf = dir.get_next()


	var archive_path: String
	var archive_file_name: String
	#var zip_out_dir: String
	for archive_idx in archive_paths.size():
		archive_path = archive_paths[archive_idx]
		archive_file_name = archive_path.get_file().get_basename()

		output('Archive %s' % [ archive_path ])

		var zip := ZIPReader.new()
		assert(dir.file_exists(archive_path))
		assert(zip.open(archive_path))
		var file_paths = zip.get_files()

		output(' <%s> File Paths' % [ file_paths.size() ])

		var zip_leaf:    String
		var target_path: String
		var target_dir: String = out_dir.plus_file(archive_file_name)
		for idx in file_paths.size():
			zip_leaf = file_paths[idx]
			#output('   %d' % [ idx ])
			# Directory paths have been filtered out, or should have been already.
			# @NOTE: I just checked String#get_base_dir and nothing would break if directories
			#        were passed into here
			assert(not zip_leaf.ends_with('/'))

			target_path = target_dir.plus_file(zip_leaf)

			output('\t -  %s' % [ zip_leaf ])
			#output(' -> %s' % [ target_path ])

			###
			### Check zip actually has path
			###
			var zip_has_file := zip.has_file(zip_leaf)
			if not zip_has_file:
				var msg := 'File path not found in archive file tree: %s' % [ zip_leaf ]
				output_error(msg)
				assert(zip_has_file, msg)
				return false


			###
			### Create output folder if needed
			###
			if not dir.dir_exists(target_path.get_base_dir()):
				var file_dir_mkdirp_err := dir.make_dir_recursive(target_path.get_base_dir())
				if file_dir_mkdirp_err != OK:
					output_error('Failed to create output directory for file <%s>/%s'
									% [ target_path.get_base_dir(), target_path.get_basename() ])
					return false

			###
			### Strict mode check
			###
			# if strict and dir.file_exists(target_path):
			# 	var msg := 'Called in strict mode, and file path already exists: <%s>' % [ target_path ]
			# 	dprint.error(msg, '_install_zip_content')
			# 	assert(false, msg)
			# 	return false

			###
			### Finally start file write process
			###
			#output('  Decompressing %s' % [ zip_leaf ])
			timer.start()
			var file_buf := zip.uncompress(zip_leaf)
			timer.stop()
			#output('   -> Decompressed %s' % [ zip_leaf ])
			assert(file_buf != ZIPReader.ERR_BYTEARRAY)

			var file: File = File.new()
			if file.open(target_path, File.WRITE) != OK:
				var msg := 'Failed to open file path for write: <%s>' % [ target_path ]
				output_error(msg)

				assert(false, msg)
				return false

			#output('  Storing %s' % [ zip_leaf ])
			#file.store_buffer(file_buf)
			#file.close()

			yield(get_tree(), "idle_frame")

		yield(get_tree(), "idle_frame")

	return true


func _on_Run_pressed() -> void:
	yield(test(), "completed")
	
	return
	# (Using per-test section timers for now)
	var elapsed_msec := timer.total / 1_000.0
	var msg := "Total Time: %.2f %s" % [
			elapsed_msec / (1000.0 if elapsed_msec > 1000.0 else 1.0),
			('sec' if elapsed_msec > 1000.0 else 'ms')
	]
	output("\n" + BB.BoldColor(msg, '#CC0088'))
	print(msg)


#section statics


###
### Recursively delete items in directory tree. Fails on project uris as a safety precaution.
###
### @TODO: Move to Utils
###
static func RecursiveRemove(dir_path: String) -> int:
	if dir_path.begins_with('res:'):
		assert(not dir_path.begins_with('res:'), "Attempted removal of project rooted file")
		return ERR_FILE_NO_PERMISSION

	assert(dir_path != '..' and dir_path != '.')

	if dir_path.begins_with('user:'):
		dir_path = ProjectSettings.globalize_path(dir_path)

	var dir: Directory = Directory.new()

	# Added for these tests
	if dir.file_exists(dir_path):
		var removed := dir.remove(dir_path)
		if not removed:
			assert(removed, 'Failed to remove file: %s' % [ dir_path ])

	assert(dir.dir_exists(dir_path))
	assert(dir.open(dir_path) == OK)

	assert(OK == dir.list_dir_begin(true, true))

	var file_name: String = dir.get_next()
	var curr_path: String
	var curr_dir:  String
	var fs_err:    int
	while not file_name.empty():
		curr_dir = dir.get_current_dir()
		curr_path = curr_dir.plus_file(file_name)
		if dir.current_is_dir():
			fs_err = RecursiveRemove(curr_path)

		else:
			#print('Removing %s' % [ curr_path ])
			fs_err = dir.remove(curr_path)

		if fs_err != OK:
			return fs_err

		file_name = dir.get_next()

	dir.list_dir_end()

	return dir.remove(dir_path)


#section classes


class ArchiveTests:
	const TestBase := 'res://test/archives/'
	const TEST_ALL_FILES := [ '<ALL>' ]

	const TestFilesFull := {
		"test-pack-fixture.zip":
			TEST_ALL_FILES,
		"test-pack-gauntlet.zip":
			TEST_ALL_FILES,
		"test-basic-level.zip":
			TEST_ALL_FILES,
		"test-basic-mod.zip":
			TEST_ALL_FILES,
		"test-level-fixture.zip":
			TEST_ALL_FILES,
		"test-mod-fixture.zip":
			TEST_ALL_FILES,
	}

	const TestFilesSimple := {
		"test-mod-fixture.zip":
			TEST_ALL_FILES,
		"test-pack-fixture.zip":
		[
			"levels/__TEST_LEVEL/__TEST_LEVEL.tscn"
		]
	}
	
	static func StripTestBase(path: String) -> String:
		return path.trim_prefix(TestBase)\
				   .trim_prefix(ProjectSettings.globalize_path(TestBase))


class BB:
	static func Color(string: String, color) -> String:
		return '[color=%s]%s[/color]' % [
				color if typeof(color) == TYPE_STRING else color.to_html(),
				string
		]

	static func Bold(string: String) -> String:
		return '[b]%s[/b]' % [ string ]


	static func BoldColor(string: String, color) -> String:
		return Bold(BB.Color(string, color))
