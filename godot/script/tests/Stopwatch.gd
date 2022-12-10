class_name Stopwatch
extends Node


const TIME_UNSET: int = -1
const SECTION_UNSET := ""

var total        := TIME_UNSET
var start        := TIME_UNSET
var last_time    := TIME_UNSET
var longest_time := 0
var times        := PoolIntArray()


var sections: Dictionary = { }
var curr_section_name: String = SECTION_UNSET
var curr_section := PoolIntArray()


func _init() -> void:
	clear()


func clear() -> void:
	total     = TIME_UNSET
	start     = TIME_UNSET
	last_time = TIME_UNSET
	times     = PoolIntArray()
	
	sections          = { }
	curr_section      = PoolIntArray()
	curr_section_name = SECTION_UNSET


func start() -> void:
	assert(start == TIME_UNSET, "repeat start call")
	start = Time.get_ticks_usec()


func stop() -> void:
	assert(start != TIME_UNSET, "stop with no starting time")

	# Record "lap"
	last_time = Time.get_ticks_usec() - start
	times.push_back(last_time)
	if curr_section_name != SECTION_UNSET:
		curr_section.push_back(last_time)
	if last_time > longest_time:
		longest_time = last_time

	# Add to total time
	total += last_time

	start = TIME_UNSET


func begin_section(name: String) -> void:
	# assert(not (sections.has(curr_section_name)), "existing section")
	assert(curr_section_name == SECTION_UNSET, "existing active section")

	curr_section_name = name
	curr_section = PoolIntArray()


func end_section() -> void:
	# assert(not (sections.has(curr_section_name)), "existing section")
	assert(curr_section_name != SECTION_UNSET, "no section name declared")

	sections[curr_section_name] = curr_section
	curr_section_name = SECTION_UNSET


static func UsecToSec(usec: int) -> float:
	return usec / 1_000_000.0


static func UsecToMsec(usec: int) -> float:
	return usec / 1_000.0
