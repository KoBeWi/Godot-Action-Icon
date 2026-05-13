## Displays input prompt for an input action.
@tool
@icon("res://addons/ActionIcon/Icon.png")
class_name ActionIcon extends TextureRect

const _SHEET_COLUMNS = 10
const _ACTION_SET_SETTING = "addons/action_icon/action_set_directory"
const _AUTO_LOAD_SETTING = "addons/action_icon/automatically_load_icons"
const _DEFAULT_TEXTURE = preload("uid://cx5x6dyfjq7h8")
const _GROUP_NAME = &"action_icons"

enum Device { KEYBOARD, MOUSE, JOYPAD }
enum JoypadMode {
	## Automatically detect if user is using a joypad.
	ADAPTIVE,
	## Always show keyboard icons.
	FORCE_KEYBOARD,
	## Always show joypad icons.
	FORCE_JOYPAD
}
enum FitMode {
	## Sizing strategy can be customized with [TextureRect] properties.
	CUSTOM,
	## The icon will set its width based on height.
	MATCH_WIDTH,
	## The icon will set its height based on width.
	MATCH_HEIGHT,
}

## Action name from InputMap or [ActionIconCustomActions].
@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin,loose_mode") var action_name: StringName = &"":
	set(action):
		if action == action_name:
			return
		
		action_name = action
		refresh()

## Whether a joypad button should be used or keyboard/mouse.
@export var joypad_mode: JoypadMode = JoypadMode.ADAPTIVE:
	set(mode):
		if mode == joypad_mode:
			return
		
		joypad_mode = mode
		refresh()

## Controller model for the displayed icon. Use [code]Auto[/code] to automatically detect model based on connected device (best-effort).
@export var joypad_model := -1:
	set(model):
		if model == joypad_model:
			return
		
		joypad_model = model
		if model == -1:
			if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
				Input.joy_connection_changed.connect(_on_joy_connection_changed)
		else:
			if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
				Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
		refresh()

## If action has both keyboard and mouse events, this makes mouse icons preferred if available.
@export var favor_mouse := true:
	set(favor):
		if favor == favor_mouse:
			return
		
		favor_mouse = favor
		refresh()

## If action has both joypad button and axis events, this makes axis icons preferred if available.
@export var favor_axis: bool = false:
	set(favor):
		if favor == favor_axis:
			return
		
		favor_axis = favor
		refresh()

## Use to control the size of icon inside a container. CUSTOM enables setting strech modes manually using [TextureRect] properties.
@export var fit_mode: FitMode = FitMode.MATCH_WIDTH:
	set(mode):
		if mode == fit_mode and _fit_initialized:
			return
		
		_fit_initialized = true
		
		fit_mode = mode
		match fit_mode:
			FitMode.MATCH_WIDTH:
				expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			FitMode.MATCH_HEIGHT:
				expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
				stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		notify_property_list_changed()

## Refreshes the displayed icon in the editor.
@export_tool_button("Refresh Icon", "ReloadSmall") var editor_refresh_icon = func():
	refresh()

## Reloads all icon data and refreshes icons.
@export_tool_button("Reload Data", "Close") var editor_reload_data = func():
	_keyboard_set = null
	_mouse_set = null
	_joypad_sets.clear()
	_custom_actions = null
	
	initialize_data()
	refresh_all()

static var _base_size: Vector2
static var _default_joypad: String
static var _use_joypad: bool

static var _keyboard_set: IconSet
static var _mouse_set: IconSet
static var _joypad_sets: Dictionary[String, IconSet]
static var _custom_actions: ActionIconCustomActions

var _pending_refresh: bool = true
var _fit_initialized: bool
var _cached_joypad: IconSet

static func _static_init() -> void:
	_use_joypad = not Input.get_connected_joypads().is_empty()
	if ProjectSettings.get_setting(_AUTO_LOAD_SETTING, true):
		initialize_data()

## Call it once to load the icon data, but only if [code]addons/action_icon/automatically_load_icons[/code] project setting is disabled. Needs to be called before any [ActionIcon] is created.
static func initialize_data():
	var icon_set_path: String = ProjectSettings.get_setting(_ACTION_SET_SETTING, "res://ActionIconSet")
	if not DirAccess.dir_exists_absolute(icon_set_path):
		icon_set_path = "res://addons/ActionIcon/DefaultIconSet"
	
	var cfg := ConfigFile.new()
	cfg.load(icon_set_path.path_join("Config.cfg"))
	_base_size = cfg.get_value("config", "base_size")
	_default_joypad = cfg.get_value("config", "default_joypad")
	
	var set_list: PackedStringArray = cfg.get_value("config", "set_list")
	
	for icon_set in set_list:
		var sheet_path := icon_set_path.path_join(icon_set + ".png")
		assert(ResourceLoader.exists(sheet_path, "Texture2D"), "Missing action icon sheet for %s." % icon_set)
		var data: Dictionary = str_to_var(FileAccess.get_file_as_string(icon_set_path.path_join(icon_set + ".dat")))
		
		var set_object := IconSet.new()
		set_object.texture = load(sheet_path)
		
		for key in data:
			if key is int:
				set_object.mapping[key] = data[key]
			elif key is String and not key.begins_with("$"):
				set_object.mapping[key] = data[key]
		
		match data["$type"]:
			Device.KEYBOARD:
				_keyboard_set = set_object
			Device.MOUSE:
				_mouse_set = set_object
			Device.JOYPAD:
				for model in data["$models"]:
					if not model in _joypad_sets:
						_joypad_sets[model] = set_object
				
				if icon_set == _default_joypad:
					_default_joypad = data["$models"][0]
	
	var custom_actions_path := icon_set_path.path_join("CustomActions.gd")
	if ResourceLoader.exists(custom_actions_path):
		_custom_actions = load(custom_actions_path).new()

func _init():
	add_to_group(_GROUP_NAME)
	texture = _DEFAULT_TEXTURE

## Forces icon refresh. Useful when you change controls.
func refresh():
	if _pending_refresh or not is_inside_tree():
		return
	
	_pending_refresh = true
	_refresh.call_deferred()

## Returns an icon associated with the specified [param icon_id] and [param device]. The ID depends on the device, e.g. keyboard uses [code]KEY_*[/code] constants. Custom set icons are identified with a [String].
## [br][br][b]Note:[/b] Joypad axis values use hard-coded IDs, due to not having built-in constants. These are 503/502 for positive/negative left X, 501/500 for positive/negative left Y, 1005/1004 for positive/negative right X, 1003/1002 for positive/negative right Y.
func get_icon(icon_id: Variant, device: Device) -> Texture2D:
	var icon_set: IconSet
	match device:
		Device.KEYBOARD:
			icon_set = _keyboard_set
		Device.MOUSE:
			icon_set = _mouse_set
		Device.JOYPAD:
			icon_set = _get_joypad_set(0)
	
	if not icon_set:
		return null
	
	var idx: int = icon_set.mapping.get(icon_id, -1)
	return _get_set_icon(icon_set, idx)

## Static version of [method get_icon]. Due to not being bound to a specific [ActionIcon], always uses the default joypad set.
static func get_icon_static(icon_id: Variant, device: Device) -> Texture2D:
	var icon_set: IconSet
	match device:
		Device.KEYBOARD:
			icon_set = _keyboard_set
		Device.MOUSE:
			icon_set = _mouse_set
		Device.JOYPAD:
			icon_set = _joypad_sets[_default_joypad]
	
	if not icon_set:
		return null
	
	var idx: int = icon_set.mapping.get(icon_id, -1)
	return _get_set_icon(icon_set, idx)

## Returns the list of events associated with input action. Unlike [method InputMap.action_get_events], this also works in the editor.
static func action_get_events(action_name: StringName) -> Array[InputEvent]:
	if Engine.is_editor_hint():
		var setting := "input/" + action_name
		var ret: Array[InputEvent]
		if not ProjectSettings.has_setting(setting):
			return ret
		
		ret.assign(ProjectSettings.get(setting)["events"])
		return ret
	else:
		return InputMap.action_get_events(action_name)

## Calls [method refresh] on all ActionIcon nodes in the scene tree.
static func refresh_all():
	Engine.get_main_loop().call_group(_GROUP_NAME, &"refresh")

## Forces re-cache of icons for custom actions. Calls _create_icon_cache() in the custom actions script.
static func reload_custom_actions():
	_custom_actions._create_icon_cache()

func _refresh():
	if not is_visible_in_tree():
		return
	
	_pending_refresh = false
	_cached_joypad = null
	
	var is_joypad := joypad_mode == JoypadMode.FORCE_JOYPAD or (joypad_mode == JoypadMode.ADAPTIVE and _use_joypad)
	if _custom_actions and _custom_actions._has_action(action_name):
		var device: Device
		if is_joypad:
			device = Device.JOYPAD
		elif favor_mouse:
			device = Device.MOUSE
		else:
			device = Device.KEYBOARD
		
		var action_texture := _custom_actions._get_texture(action_name, self, device)
		if not action_texture:
			push_warning("Custom action \"%s\" has empty texture." % action_name)
			texture = _DEFAULT_TEXTURE
		else:
			texture = action_texture
		return
	
	if action_name.is_empty():
		texture = _DEFAULT_TEXTURE
		return
	
	var events := action_get_events(action_name)
	if events.is_empty():
		texture = _DEFAULT_TEXTURE
		if ProjectSettings.has_setting("input/" + action_name):
			push_warning("Action \"%s\" has no events." % action_name)
		else:
			push_warning("Action \"%s\" not found in InputMap nor custom actions." % action_name)
		return
	
	var keyboard := -1
	var mouse := -1
	var joypad := -1
	var joypad_axis := -1
	var joypad_axis_value: float
	var joypad_id: int
	
	for event in events:
		if keyboard == -1 and event is InputEventKey:
			if event.keycode == 0:
				keyboard = event.physical_keycode
			else:
				keyboard = event.keycode
		elif mouse == -1 and event is InputEventMouseButton:
			mouse = event.button_index
		elif joypad == -1 and event is InputEventJoypadButton:
			joypad = event.button_index
			joypad_id = event.device
		elif joypad_axis == -1 and event is InputEventJoypadMotion:
			joypad_axis = event.axis
			joypad_axis_value = event.axis_value
			joypad_id = event.device
	
	if is_joypad and joypad >= 0 and (not favor_axis or joypad_axis < 0):
		texture = _get_joypad(joypad, joypad_id)
	elif is_joypad and joypad_axis >= 0:
		texture = _get_joypad_axis(joypad_axis, joypad_axis_value, joypad_id)
	elif not is_joypad:
		if mouse >= 0 and (favor_mouse or keyboard < 0):
			texture = _get_mouse(mouse)
		elif keyboard >= 0:
			texture = _get_keyboard(keyboard)
	
	if not texture:
		push_warning("No icon found for action \"%s\"." % action_name)
		texture = _DEFAULT_TEXTURE

func _get_keyboard(key: int) -> Texture2D:
	return _get_set_icon(_keyboard_set, _keyboard_set.mapping.get(key, -1))

func _get_mouse(button: int) -> Texture2D:
	return _get_set_icon(_mouse_set, _mouse_set.mapping.get(button, -1))

func _get_joypad(button: int, device: int) -> Texture2D:
	var icon_set := _get_joypad_set(device)
	return _get_set_icon(icon_set, icon_set.mapping.get(button, -1))

func _get_joypad_axis(axis: int, value: float, device: int) -> Texture2D:
	var icon_set := _get_joypad_set(device)
	
	var offset := maxi(-value, 0)
	if axis == JOY_AXIS_LEFT_Y or axis == JOY_AXIS_RIGHT_Y:
		axis -= 1
		offset += 2
	
	axis = (axis + 1) * 100 + offset
	return _get_set_icon(icon_set, icon_set.mapping.get(axis, -1))

func _get_joypad_set(device: int) -> IconSet:
	if _cached_joypad:
		return _cached_joypad
	elif joypad_model > -1:
		_cached_joypad = _joypad_sets.values()[joypad_model]
		return _cached_joypad
	
	var data: IconSet
	var device_name := Input.get_joy_name(maxi(device, 0))
	if device_name in _joypad_sets:
		data = _joypad_sets[device_name]
	else:
		push_warning("Joypad model \"%s\" not found in registered icon sets. Using default set." % device_name)
		data = _joypad_sets[_default_joypad]
	
	_cached_joypad = data
	return data

func _on_joy_connection_changed(device: int, connected: bool):
	if connected:
		refresh()

func _input(event: InputEvent) -> void:
	var _prev_use := _use_joypad
	if _use_joypad:
		if event is InputEventKey or event is InputEventMouseButton:
			_use_joypad = false
		else:
			var mm := event as InputEventMouseMotion
			if mm and mm.relative.length_squared() >= 100:
				_use_joypad = false
	else:
		if event is InputEventJoypadButton:
			_use_joypad = true
		else:
			var jm := event as InputEventJoypadMotion
			if jm and absf(jm.axis_value) > 0.5:
				_use_joypad = true
	
	if _use_joypad != _prev_use:
		refresh_all()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			if get_tree().get_first_node_in_group(_GROUP_NAME) == self:
				_queue_update_process_input()
			else:
				set_process_input(false)
		
		NOTIFICATION_EXIT_TREE:
			if is_processing_input():
				_queue_update_process_input()
		
		NOTIFICATION_READY:
			if not _fit_initialized:
				fit_mode = fit_mode
			
			if joypad_model == 0:
				Input.joy_connection_changed.connect(_on_joy_connection_changed)
			
			set_process_input(false)
			
			if action_name == &"":
				return
		
			if not Engine.is_editor_hint():
				assert(InputMap.has_action(action_name) or (_custom_actions and _custom_actions._has_action(action_name)), str("Action \"", action_name, "\" does not exist in the InputMap nor in custom action list."))
			
		NOTIFICATION_VISIBILITY_CHANGED:
			if _pending_refresh and is_visible_in_tree():
				_refresh()

func _validate_property(property: Dictionary) -> void:
	var pname: String = property["name"]
	if pname == "texture":
		property["usage"] = PROPERTY_USAGE_NONE
	elif fit_mode != FitMode.CUSTOM and (pname == "expand_mode" or pname == "stretch_mode"):
		property["usage"] = PROPERTY_USAGE_NONE
	elif not Engine.is_editor_hint():
		return
	
	if pname == "joypad_model":
		var models: PackedStringArray
		models.append("Auto:-1")
		
		var sets: Array[IconSet]
		
		var i: int
		for st: IconSet in _joypad_sets.values():
			if not st in sets:
				sets.append(st)
				var joyname := st.texture.resource_path.get_file().get_basename().trim_prefix("Joypad")
				models.append("%s:%d" % [joyname, i])
			
			i += 1
		
		property["hint"] = PROPERTY_HINT_ENUM
		property["hint_string"] = ",".join(models)
	elif pname == "editor_refresh_icon" or pname == "editor_reload_data":
		var domain := TranslationServer.get_or_add_domain(&"godot.editor")
		
		var parts: PackedStringArray = property["hint_string"].split(",")
		parts[0] = String(domain.translate(parts[0]))
		property["hint_string"] = ",".join(parts)

func _queue_update_process_input():
	Engine.get_main_loop().call_group_flags(SceneTree.GROUP_CALL_DEFERRED | SceneTree.GROUP_CALL_UNIQUE, _GROUP_NAME, _update_process_input.get_method())

func _update_process_input():
	if is_inside_tree():
		set_process_input(get_tree().get_first_node_in_group(_GROUP_NAME) == self)

static func _get_set_icon(icon_set: IconSet, idx: int) -> Texture2D:
	if idx < 0:
		return null
	
	var tex := AtlasTexture.new()
	tex.atlas = icon_set.texture
	tex.region.size = _base_size
	tex.region.position = Vector2(idx % _SHEET_COLUMNS, idx / _SHEET_COLUMNS) * _base_size
	return tex

class IconSet:
	var texture: Texture2D
	var mapping: Dictionary[Variant, int]
