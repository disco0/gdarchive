class_name ZIPWriterTest
extends TestPanelBase


var targets := ArchiveTests.GetTestDirectories()

var test_output := "res://test-output"


func test() -> void:
	output_section("Testing archive packing")
	yield(get_tree(), "idle_frame")

	var dir: Directory = Directory.new()

	for target in targets:
		var writer = GDNativeZipFileWriter.new()
		writer.trace = true
		var out_file: String = ProjectSettings.globalize_path(test_output.plus_file(target.get_file() + ".zip"))

		output('  Source Dir:  %s' % [ target ])
		output('  Output File: %s' % [ out_file ])
		if dir.file_exists(out_file):
			OS.move_to_trash(out_file)

		writer.output_path = out_file
		writer.source_dir = target

		var res = writer.write_zip()
		if res == OK:
			output_color('  Wrote zip', Color.green)
			yield(get_tree(), "idle_frame")
		else:
			output_color('  Error writing zip: %d' % [ res ], Color.red)
			yield(get_tree(), "idle_frame")

		# just do cleanup now
		if dir.file_exists(out_file):
			dir.remove(out_file)
