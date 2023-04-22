class_name ZIPWriterTest
extends TestPanelBase


var targets := ArchiveTests.GetTestDirectories()
var test_output := "res://test-output"

var dir: Directory = Directory.new()


func test() -> void:
	yield(test_packer(), "completed")

	output_section("Testing archive packing")
	yield(get_tree(), "idle_frame")

	for target in targets:
		var writer := ZIPWriter.new()
		writer.trace = true
		var out_file := test_output.plus_file(target.get_file() + ".zip")
		var out_file_global: String = ProjectSettings.globalize_path(out_file)

		output('  Source Dir:  %s' % [ target ])
		output('  Output File: %s' % [ out_file_global ])
		yield(get_tree(), 'idle_frame')

		if dir.file_exists(out_file_global):
			OS.move_to_trash(out_file_global)

		writer.output_path = out_file_global
		writer.source_dir = target

		var res = writer.write_zip()
		if res == OK:
			output_color('  Wrote zip', Color.green)
			yield(get_tree(), "idle_frame")
		else:
			output_color('  Error writing zip: %s' % [ res ], Color.red)
			yield(get_tree(), "idle_frame")

		# just do cleanup now
		if dir.file_exists(out_file):
			dir.remove(out_file)


func test_packer() -> void:
	output_section("\nTesting ZipPacker")
	yield(get_tree(), "idle_frame")

	var packer := ZipPacker.new()
	var zip_path = test_output.plus_file(ZipPackerTest.ArchivePathLeaf)

	output('  Output Zip Path:  %s' % [ zip_path ])

	if dir.file_exists(zip_path):
		output_color('  Removing existing zip test output file', Color(0.8, 0.8, 0.8, 0.6))
		OS.move_to_trash(ProjectSettings.globalize_path(zip_path))

	yield(get_tree(), "idle_frame")

	output('    Opening')
	packer.open(zip_path)

	var file_path := ZipPackerTest.TestPath
	output('    Starting file: %s' % [ file_path ])
	packer.start_file(file_path)

	output('    Writing')
	packer.write_file(ZipPackerTest.TestContent.to_utf8())

	output('    Closing ')
	packer.close()


class ZipPackerTest:
	const TestContent := "1 2 3 4 5 6"
	const TestPath = 'test-dir/test-file.txt'
	const ArchivePathLeaf = 'ZipPackerTest.zip'
