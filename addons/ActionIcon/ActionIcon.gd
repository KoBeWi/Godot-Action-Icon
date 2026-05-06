@tool
@icon("res://addons/ActionIcon/Icon.png")
class_name ActionIcon extends TextureRect

const _SHEET_COLUMNS = 10
const _ACTION_SET_DIR = "addons/action_icon/action_set_directory"
const _DEFAULT_TEXTURE = preload("uid://cx5x6dyfjq7h8")

const GROUP_NAME = &"action_icons"

enum { KEYBOARD, MOUSE, JOYPAD }
enum JoypadMode { ADAPTIVE, FORCE_KEYBOARD, FORCE_JOYPAD }
enum FitMode { CUSTOM, MATCH_WIDTH, MATCH_HEIGHT }

## Action name from InputMap or CUSTOM_ACTIONS.
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

## Controller model for the displayed icon.
@export var joypad_model: int:
	set(model):
		if model == joypad_model:
			return
		
		joypad_model = model
		if model == 0:
			if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
				Input.joy_connection_changed.connect(_on_joy_connection_changed)
		else:
			if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
				Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
		
			_cached_model = ""
		refresh()

## If action has both keyboard and mouse events, this makes mouse icons preferred if available.
@export var favor_mouse: bool = true:
	set(favor):
		if favor == favor_mouse:
			return
		
		favor_mouse = favor
		refresh()

## If action has both joypad button and axis events, this makes axis icons preferred if available.
@export var favor_axis: bool = false

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

@export_tool_button("Reload Data", "ReloadSmall") var editor_reload_data = func():
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
static var _custom_actions: RefCounted

var _pending_refresh: bool = true
var _fit_initialized: bool
var _cached_model: String

static func _static_init() -> void:
	var set_cache_path: String = ProjectSettings.get_setting(_ACTION_SET_DIR)
	
	var cfg := ConfigFile.new()
	cfg.load(set_cache_path.path_join("Config.cfg"))
	_default_joypad = cfg.get_value("config", "default_joypad")
	if cfg.get_value("config", "load_automatically"):
		initialize_data()
	
	_use_joypad = not Input.get_connected_joypads().is_empty()

## Call it once to load the icon data, but only if [code]load_automatically[/code] is disabled in the config.
static func initialize_data():
	var set_cache_path: String = ProjectSettings.get_setting(_ACTION_SET_DIR)
	
	var cfg := ConfigFile.new()
	cfg.load(set_cache_path.path_join("Config.cfg"))
	_base_size = cfg.get_value("config", "base_size")
	
	var set_list: PackedStringArray = cfg.get_value("config", "set_list")
	
	for icon_set in set_list:
		var sheet_path := set_cache_path.path_join(icon_set + ".png")
		assert(ResourceLoader.exists(sheet_path, "Texture2D"), "Missing action icon sheet for %s." % icon_set)
		var data: Dictionary = str_to_var(FileAccess.get_file_as_string(set_cache_path.path_join(icon_set + ".dat")))
		
		var set_object := IconSet.new()
		set_object.texture = load(sheet_path)
		
		for key in data:
			if key is int:
				set_object.mapping[key] = data[key]
		
		match data["$type"]:
			KEYBOARD:
				_keyboard_set = set_object
			MOUSE:
				_mouse_set = set_object
			JOYPAD:
				for model in data["$models"]:
					_joypad_sets[model] = set_object
	
	var custom_actions_path := set_cache_path.path_join("CustomActions.gd")
	if ResourceLoader.exists(custom_actions_path):
		_custom_actions = load(custom_actions_path).new()

func _init():
	add_to_group(GROUP_NAME)
	texture = _DEFAULT_TEXTURE
	
	if Engine.is_editor_hint() and not _keyboard_set:
		initialize_data()

## Forces icon refresh. Useful when you change controls.
func refresh():
	if _pending_refresh or not is_inside_tree():
		return
	
	_pending_refresh = true
	_refresh.call_deferred()

## Calls [method refresh] on all ActionIcon nodes in the scene tree.
static func refresh_all():
	Engine.get_main_loop().call_group(GROUP_NAME, &"refresh")

## Forces re-cache of icons for custom actions. Calls _create_icon_cache() in the custom actions script.
static func reload_custom_actions():
	_custom_actions._create_icon_cache()

func _refresh():
	if not is_visible_in_tree():
		return
	
	_pending_refresh = false
	var is_joypad := joypad_mode == JoypadMode.FORCE_JOYPAD or (joypad_mode == JoypadMode.ADAPTIVE and _use_joypad)
	
	if _custom_actions:
		var action_texture: Texture2D = await _custom_actions.get_texture(action_name, self, is_joypad)
		if action_texture:
			texture = action_texture
			return
	
	if action_name.is_empty():
		texture = _DEFAULT_TEXTURE
		return
	
	var events := _action_get_events(action_name)
	if events.is_empty():
		texture = _DEFAULT_TEXTURE
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
		push_warning("No icon found for action: %s" % action_name)
		texture = _DEFAULT_TEXTURE

static func _get_keyboard(key: int) -> Texture2D:
	return get_set_icon(_keyboard_set, _keyboard_set.mapping.get(key, -1))

func _get_joypad_model(device: int) -> String:
	if not _cached_model.is_empty():
		return _cached_model
	
	var device_name := Input.get_joy_name(maxi(device, 0))
	var model := _default_joypad
	
	#for icon_set in _icon_sets:
		#var found: bool
		#var set_data: Dictionary = _icon_sets[icon_set]
		#
		#if set_data["type"] == "joypad":
			#for pattern in set_data["joypad_model"]:
				#if device_name.contains(pattern):
					#model = icon_set
					#found = true
					#break
		#
		#if found:
			#break
	
	_cached_model = model
	return model

func _get_joypad(button: int, device: int) -> Texture2D:
	var model := _get_joypad_model(device)
	#var icon_set: Dictionary = _icon_sets[model]
	return null
	#return get_set_icon(icon_set, icon_set.get(button, -1))

func _get_joypad_axis(axis: int, value: float, device: int) -> Texture2D:
	var model := _get_joypad_model(device)
	
	var id: int = axis + 2000 + 1000 * value
	
	#var icon_set: Dictionary = _icon_sets[model]
	return null
	#return get_set_icon(icon_set, icon_set.get(id, -1))

func _get_mouse(button: int) -> Texture2D:
	#match button:
		#MOUSE_BUTTON_LEFT:
			#return _get_image(MOUSE, "Left")
		#MOUSE_BUTTON_RIGHT:
			#return _get_image(MOUSE, "Right")
		#MOUSE_BUTTON_MIDDLE:
			#return _get_image(MOUSE, "Middle")
		#MOUSE_BUTTON_WHEEL_DOWN:
			#return _get_image(MOUSE, "WheelDown")
		#MOUSE_BUTTON_WHEEL_LEFT:
			#return _get_image(MOUSE, "WheelLeft")
		#MOUSE_BUTTON_WHEEL_RIGHT:
			#return _get_image(MOUSE, "WheelRight")
		#MOUSE_BUTTON_WHEEL_UP:
			#return _get_image(MOUSE, "WheelUp")
	return null

func _on_joy_connection_changed(device: int, connected: bool):
	if connected:
		_cached_model = ""
		refresh()

func _input(event: InputEvent) -> void:
	var _prev_use := _use_joypad
	if _use_joypad and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion):
		_use_joypad = false
	elif not _use_joypad and (event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)):
		_use_joypad = true
	
	if _use_joypad != _prev_use:
		refresh_all()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE:
			if get_tree().get_first_node_in_group(GROUP_NAME) == self:
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
				assert(InputMap.has_action(action_name) or (_custom_actions and _custom_actions.has_action(action_name)), str("Action \"", action_name, "\" does not exist in the InputMap nor in custom action list."))
			
		NOTIFICATION_VISIBILITY_CHANGED:
			if is_visible_in_tree() and _pending_refresh:
				_refresh()

func _validate_property(property: Dictionary) -> void:
	if property.name == "texture":
		property.usage = 0
	elif fit_mode != FitMode.CUSTOM and (property.name == "expand_mode" or property.name == "stretch_mode"):
		property.usage = 0
	elif property.name == "joypad_model":
		var models := ["Auto"]
		#models.append_array(_model_list)
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(models)

func _queue_update_process_input():
	Engine.get_main_loop().call_group_flags(SceneTree.GROUP_CALL_DEFERRED | SceneTree.GROUP_CALL_UNIQUE, GROUP_NAME, _update_process_input.get_method())

func _update_process_input():
	if not is_inside_tree():
		return
	set_process_input(get_tree().get_first_node_in_group(GROUP_NAME) == self)

static func _action_get_events(action_name: StringName) -> Array[InputEvent]:
	if Engine.is_editor_hint():
		var setting := "input/" + action_name
		var ret: Array[InputEvent]
		if not ProjectSettings.has_setting(setting):
			return ret
		
		ret.assign(ProjectSettings.get(setting)["events"])
		return ret
	else:
		return InputMap.action_get_events(action_name)

static func get_set_icon(icon_set: IconSet, idx: int) -> Texture2D:
	if idx < 0:
		return null
	
	var tex := AtlasTexture.new()
	tex.atlas = icon_set.texture
	tex.region.size = _base_size
	tex.region.position = Vector2(idx % _SHEET_COLUMNS, idx / _SHEET_COLUMNS) * _base_size
	return tex

class IconSet:
	var texture: Texture2D
	var mapping: Dictionary[int, int]
