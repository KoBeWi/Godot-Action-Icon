extends EditorExportPlugin

var _icon_set_path: String
var _using_custom_set: bool

const GENERATOR_PATH = "res://addons/ActionIcon/Generator"
const DEFAULT_ICON_SET_PATH = "res://addons/ActionIcon/DefaultIconSet"

func _get_name() -> String:
	return "ActionIcon Export Override"


## Make sure to export "Config.cfg" and "*.dat" files, regardless of export settings.
func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	_icon_set_path = ActionIcon._get_icon_set_path()
	_using_custom_set = (_icon_set_path != DEFAULT_ICON_SET_PATH)
	
	var cfg := ConfigFile.new()
	cfg.load(_icon_set_path.path_join("Config.cfg"))
	var default_joypad = cfg.get_value("config", "default_joypad")
	var set_list: PackedStringArray = cfg.get_value("config", "set_list")
	
	for icon_set in set_list.duplicate():
		var data_path: String = _icon_set_path.path_join(icon_set + ".dat")
		if FileAccess.file_exists(data_path) and ResourceLoader.exists(data_path.get_basename() + ".png", "Texture2D"):
			# Pass through the *.dat file directly, bypassing export settings.
			add_file(data_path, FileAccess.get_file_as_bytes(data_path), false)
		else:
			push_error("Could not export icon set %s, skipping.")
			set_list.erase(icon_set)
			if icon_set == default_joypad:
				default_joypad = set_list[-1]
	
	# Write updated Config.cfg to pck, leaving original untouched
	cfg.set_value("config", "set_list", set_list)
	cfg.set_value("config", "default_joypad", default_joypad)
	add_file(_icon_set_path.path_join("Config.cfg"), cfg.encode_to_text().to_utf8_buffer(), false)


## Exclude "Generator" and (if applicable) "DefaultIconSet" directories
func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if path.begins_with(GENERATOR_PATH):
		skip()
	elif  _using_custom_set and path.begins_with(DEFAULT_ICON_SET_PATH):
		skip()
