class_name ZIPReaderTest
extends TestPanelBase


const ERR_BYTEARRAY := PoolByteArray()

var write_test_mode := true


func _ready() -> void:
	timer = Stopwatch.new()
	add_child(timer)

	sub_timer = Stopwatch.new()
	add_child(sub_timer)


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

	yield(test_archives_expansion(), "completed")


func test_archives_read_tree(archive_paths := ArchiveTests.GetTestArchives()) -> String:
	var instance := ZIPReader.new()
	instance.trace = true
	var target: String
	for path in archive_paths:
		target = ProjectSettings.globalize_path(path.simplify_path())
		assert(not target.empty(), "Empty target path.")
		var zopen_err := instance.open(target)
		if zopen_err != OK:
			output('\t- %s' % [ target ])
			output('\t  X Failed to open (error code: %s)' % [ zopen_err ])
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
	sub_timer.clear()

	var longest := {
		zip   = "",
		path  = "",
		usecs = 0.0,
		size  = 0.0,
	}

	var file_list: Array
	var zip_path:  String
	for archive_path in ArchiveTests.GetTestArchives():
		zip_path = archive_path

		output('Loading %s' % [ zip_path ])
		yield(tree, "idle_frame")

		var zip := ZIPReader.new()
		zip._instance.trace = true

		sub_timer.start()
		var zopen_err := zip.open(zip_path)
		sub_timer.stop()

		if zopen_err != OK:
			output_error('\t X | LOAD FAILED (error code: %s)' % [ zopen_err ])
			yield(tree, "idle_frame")
			continue

		sub_timer.start()
		var files := zip.get_files()
		file_list = Array(files)
		sub_timer.stop()

		for leaf in file_list:
			#yield(tree.create_timer(0.1), "timeout")
			output('\t - %s' % [ leaf ])

			if not leaf in file_list:
				output_error('\t   X | FILE NOT FOUND')
				yield(tree, "idle_frame")
				continue

			sub_timer.start()
			var result: PoolByteArray = zip.read_file(leaf, false)
			sub_timer.stop()

			if result == ERR_BYTEARRAY:
				output('\t X | ERR_BYTEARRAY')
				yield(tree, "idle_frame")
				continue

			# Update longest decompression time
			if sub_timer.last_time > longest.usecs:
				longest = {
					path  = leaf,
					usecs = sub_timer.last_time,
					zip   = zip_path,
					size  = result.size()
				}

			var elapsed_usec: float = float(sub_timer.last_time)
			var elapsed_msec: float = elapsed_usec / 1_000.0

			var sec_elapsed := elapsed_msec > 1_000.0
			var value_str := BB.Color(humanize_msecs(elapsed_msec),
									  get_elapsed_msec_color(elapsed_msec))
			output_color('\t\tSUCCESS (%s)\n' % [ value_str ], "#88CCAA")
			yield(tree, "idle_frame")

	# Sum laps in stopwatch
	var full_elapsed_usec := 0.0
	for time in sub_timer.times:
		full_elapsed_usec += float(time)
	var full_elapsed_msec: float = full_elapsed_usec / 1_000.0
	output_color('--------\nSUCCESS (%s)\n--------'
				% [ humanize_msecs(full_elapsed_msec), ],
				"#44FF77")

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
func test_archive_extraction(archive_paths := ArchiveTests.GetTestArchives(), out_dir = "res://test-output"):
	out_dir = ProjectSettings.globalize_path(out_dir.simplify_path())
	var dir: Directory = Directory.new()

	output('Extracting archives to path: %s' % [ out_dir ])

	# Prepare out_dir
	if not dir.dir_exists(out_dir):
		var file_exists := dir.file_exists(out_dir)
		assert(not file_exists, 'Output directory path exists and is file: %s' % [ out_dir ])
		if file_exists:
			return false

		var mkdirp_err := dir.make_dir_recursive(out_dir)
		assert(mkdirp_err == OK, 'Error creating output directory: %s (%s)' % [ mkdirp_err, out_dir ])
		if mkdirp_err != OK:
			return false

	###
	### Prepare for tests, clean output dir (except .gdignore)
	###
	assert(dir.open(out_dir) == OK)
	dir.list_dir_begin(true, true)
	var leaf := dir.get_next()
	var leaf_path: String
	while not leaf.empty():
		leaf_path = dir.get_current_dir().plus_file(leaf)

		if leaf != '.gdignore':
			output('[clearing %s]' % [ leaf ])
			RecursiveRemove(leaf_path)

		leaf = dir.get_next()

	var archive_path:      String
	var archive_file_name: String
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
		var target_dir:  String = out_dir.plus_file(archive_file_name)
		for idx in file_paths.size():
			zip_leaf = file_paths[idx]

			# Directory paths have been filtered out, or should have been already.
			# @NOTE: I just checked String#get_base_dir and nothing would break if directories
			#        were passed into here
			assert(not zip_leaf.ends_with('/'))

			target_path = target_dir.plus_file(zip_leaf)

			output('\t -  %s' % [ zip_leaf ])

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
