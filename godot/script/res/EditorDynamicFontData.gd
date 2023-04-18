tool
class_name EditorDynamicFontData
extends DynamicFontData


#section members


export (String) var editor_font_property := 'interface/editor/code_font' setget set_editor_font_property

var _editor_settings: EditorSettings
var tool_mode := Engine.editor_hint


#section lifecycle


func _init() -> void:
	if tool_mode:
		_initialize_font_path()


#section methods


func set_editor_font_property(value: String):
	editor_font_property = value
	if not tool_mode: return
	if is_instance_valid(_editor_settings):
		_initialize_font_path()


func _initialize_font_path() -> void:
	var editor_interface := EditorScript.new().get_editor_interface()
	if not is_instance_valid(editor_interface):
		push_error("Failed to get editor instance interface")
		return

	_editor_settings = editor_interface.get_editor_settings()
	if not _editor_settings.is_connected("settings_changed", self, "_on_editor_settings_changed"):
		_editor_settings.connect("settings_changed", self, "_on_editor_settings_changed")

	if not _editor_settings.has_setting(editor_font_property):
		push_error("Editor setting property not found: %s" % [ editor_font_property ])
		return

	font_path = _editor_settings.get_setting(editor_font_property)


#section handlers


func _on_editor_settings_changed() -> void:
	if not _editor_settings.has_setting(editor_font_property):
		return

	var new_font_path = _editor_settings.get_setting(editor_font_property)
	if new_font_path != font_path:
		font_path = new_font_path
