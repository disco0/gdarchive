class_name TestPanelBase
extends PanelContainer


const ResultColors := {
	Fast   = Color(0.53333, 0.80000, 0.66667),
	Medium = Color(0.86667, 0.59608, 0.06667),
	Slow   = Color(0.86667, 0.33333, 0.33333),
}

onready var run_button := $"Content/Header/Run"
onready var output := $"Content/OutputScroll/Output"
onready var tree := get_tree()
onready var timer: Stopwatch
onready var sub_timer: Stopwatch

var TestName := 'ZIPReaderTest'
var test_activated := false

var start_scancode := KEY_R


func _unhandled_key_input(event: InputEventKey):
	if not event.pressed or event.echo:
		return

	if event.get_scancode_with_modifiers() == start_scancode:
		_on_Run_pressed()


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


#section abstract


func test() -> void:
	output_error("test() not implemented.")
	yield(get_tree(), "idle_frame")
	pass


#section signals


func _on_Run_pressed() -> void:
	test_activated = true
	yield(test(), "completed")
	return

	# # (Using per-test section timers for now)
	# var elapsed_msec := timer.total / 1_000.0
	# var msg := "Total Time: %.2f %s" % [
	# 		elapsed_msec / (1000.0 if elapsed_msec > 1000.0 else 1.0),
	# 		('sec' if elapsed_msec > 1000.0 else 'ms')
	# ]
	# output("\n" + BB.BoldColor(msg, '#CC0088'))
	# print(msg)



#section util


func get_elapsed_msec_color(elapsed: float) -> Color:
	if elapsed > 100.0:
		return ResultColors.Slow
	elif elapsed > 50.0:
		return ResultColors.Medium
	else:
		return ResultColors.Fast


func humanize_msecs(msec: float) -> String:
	var sec_elapsed := msec > 1_000.0
	return ("%." + ("4" if sec_elapsed else "2") + "f%s") \
	% [
			msec / (1_000.0 if sec_elapsed else 1.0),
			's' if sec_elapsed else 'ms'
	]


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
			fs_err = dir.remove(curr_path)

		if fs_err != OK:
			return fs_err

		file_name = dir.get_next()

	dir.list_dir_end()

	return dir.remove(dir_path)


#section classes


class BB:
	static func Color(string: String, color) -> String:
		return '[color=%s]%s[/color]' % [
				color if typeof(color) == TYPE_STRING else ("#" + color.to_html()),
				string
		]

	static func Bold(string: String) -> String:
		return '[b]%s[/b]' % [ string ]


	static func BoldColor(string: String, color) -> String:
		return Bold(BB.Color(string, color))
