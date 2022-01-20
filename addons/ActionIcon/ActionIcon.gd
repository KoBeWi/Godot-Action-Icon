tool
extends TextureRect

# format: keyboard icon, mouse icon, joypad icon
const CUSTOM_ACTIONS = {
	"move": "WSAD||LeftStick"
}

enum {KEYBOARD, MOUSE, JOYPAD}
enum JoypadMode {ADAPTIVE, FORCE_KEYBOARD, FORCE_JOYPAD}
enum FitMode {NONE, MATCH_WIDTH, MATCH_HEIGHT}
enum JoypadModel {AUTO, XBOX, DUALSHOCK, JOY_CON}

export var action_name: String setget set_action_name
export(JoypadMode) var joypad_mode: int = 0 setget set_joypad_mode
export(JoypadModel) var joypad_model setget set_joypad_model
export var favor_mouse: bool = true setget set_favor_mouse
export(FitMode) var fit_mode: int = 1 setget set_fit_mode

var base_path: String
var use_joypad: bool
var pending_refresh: bool
var cached_model: String

func _init():
	add_to_group("action_icons")
	texture = load("res://addons/ActionIcon/Keyboard/Blank.png")
	expand = true
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func _ready() -> void:
	base_path = filename.get_base_dir()
	if base_path == "":
		base_path = "res://addons/ActionIcon/"
	use_joypad = not Input.get_connected_joypads().empty()
	
	if joypad_model == JoypadModel.AUTO:
		Input.connect("joy_connection_changed", self, "on_joy_connection_changed")
	
	if action_name.empty():
		return
	
	assert(InputMap.has_action(action_name) or action_name in CUSTOM_ACTIONS, str("Action \"", action_name, "\" does not exist in the InputMap nor CUSTOM_ACTIONS."))
	
	refresh()

func set_action_name(action: String):
	action_name = action
	refresh()

func set_joypad_mode(mode: int):
	joypad_mode = mode
	set_process_input(mode == JoypadMode.ADAPTIVE)
	refresh()

func set_joypad_model(model: int):
	joypad_model = model
	if model == JoypadModel.AUTO:
		if not Input.is_connected("joy_connection_changed", self, "on_joy_connection_changed"):
			Input.connect("joy_connection_changed", self, "on_joy_connection_changed")
	else:
		if Input.is_connected("joy_connection_changed", self, "on_joy_connection_changed"):
			Input.disconnect("joy_connection_changed", self, "on_joy_connection_changed")
	
	refresh()

func set_favor_mouse(favor: bool):
	favor_mouse = favor
	refresh()

func set_fit_mode(mode: int):
	fit_mode = mode
	refresh()

func refresh():
	pending_refresh = true
	call_deferred("_refresh")

func _refresh():
	if not pending_refresh:
		return
	pending_refresh = false
	
	if fit_mode != FitMode.NONE:
		rect_min_size = Vector2()
	
	if fit_mode == FitMode.MATCH_WIDTH:
		rect_min_size.x = rect_size.y
	elif fit_mode == FitMode.MATCH_HEIGHT:
		rect_min_size.y = rect_size.x
	
	if Engine.editor_hint or not is_visible_in_tree():
		return
	
	var is_joypad := false
	if joypad_mode == JoypadMode.FORCE_JOYPAD or (joypad_mode == JoypadMode.ADAPTIVE and use_joypad):
		is_joypad = true
	
	if action_name in CUSTOM_ACTIONS:
		var image_list: PoolStringArray = CUSTOM_ACTIONS[action_name].split("|")
		assert(image_list.size() >= 3, "Need more |")
		
		if is_joypad and image_list[JOYPAD]:
			texture = get_image(JOYPAD, image_list[JOYPAD])
		elif not is_joypad:
			if favor_mouse and image_list[MOUSE]:
				texture = get_image(MOUSE, image_list[MOUSE])
			elif image_list[KEYBOARD]:
				texture = get_image(KEYBOARD, image_list[KEYBOARD])
		return
	
	var keyboard := -1
	var mouse := -1
	var joypad := -1
	var joypad_axis := -1
	var joypad_axis_value: float
	var joypad_id: int
	
	for event in InputMap.get_action_list(action_name):
		if event is InputEventKey and keyboard == -1:
			keyboard = event.scancode
		elif event is InputEventMouseButton and mouse == -1:
			mouse = event.button_index
		elif event is InputEventJoypadButton and joypad == -1:
			joypad = event.button_index
			joypad_id = event.device
		elif event is InputEventJoypadMotion and joypad_axis == -1:
			joypad_axis = event.axis
			joypad_axis_value = event.axis_value
			joypad_id = event.device
	
	if is_joypad and joypad >= 0:
		texture = get_joypad(joypad, joypad_id)
	elif is_joypad and joypad_axis >= 0:
		texture = get_joypad_axis(joypad_axis, joypad_axis_value, joypad_id)
	elif not is_joypad:
		if mouse >= 0 and (favor_mouse or keyboard < 0):
			texture = get_mouse(mouse)
		elif keyboard >= 0:
			texture = get_keyboard(keyboard)
	
	if not texture and action_name:
		push_error("No icon for action: " + action_name)

func get_keyboard(key: int) -> Texture:
	match key:
		KEY_0:
			return get_image(KEYBOARD, "0")
		KEY_1:
			return get_image(KEYBOARD, "1")
		KEY_2:
			return get_image(KEYBOARD, "2")
		KEY_3:
			return get_image(KEYBOARD, "3")
		KEY_4:
			return get_image(KEYBOARD, "4")
		KEY_5:
			return get_image(KEYBOARD, "5")
		KEY_6:
			return get_image(KEYBOARD, "6")
		KEY_7:
			return get_image(KEYBOARD, "7")
		KEY_8:
			return get_image(KEYBOARD, "8")
		KEY_9:
			return get_image(KEYBOARD, "9")
		KEY_A:
			return get_image(KEYBOARD, "A")
		KEY_B:
			return get_image(KEYBOARD, "B")
		KEY_C:
			return get_image(KEYBOARD, "C")
		KEY_D:
			return get_image(KEYBOARD, "D")
		KEY_E:
			return get_image(KEYBOARD, "E")
		KEY_F:
			return get_image(KEYBOARD, "F")
		KEY_G:
			return get_image(KEYBOARD, "G")
		KEY_H:
			return get_image(KEYBOARD, "H")
		KEY_I:
			return get_image(KEYBOARD, "I")
		KEY_J:
			return get_image(KEYBOARD, "J")
		KEY_K:
			return get_image(KEYBOARD, "K")
		KEY_L:
			return get_image(KEYBOARD, "L")
		KEY_M:
			return get_image(KEYBOARD, "M")
		KEY_N:
			return get_image(KEYBOARD, "N")
		KEY_O:
			return get_image(KEYBOARD, "O")
		KEY_P:
			return get_image(KEYBOARD, "P")
		KEY_Q:
			return get_image(KEYBOARD, "Q")
		KEY_R:
			return get_image(KEYBOARD, "R")
		KEY_S:
			return get_image(KEYBOARD, "S")
		KEY_T:
			return get_image(KEYBOARD, "T")
		KEY_U:
			return get_image(KEYBOARD, "U")
		KEY_V:
			return get_image(KEYBOARD, "V")
		KEY_W:
			return get_image(KEYBOARD, "W")
		KEY_X:
			return get_image(KEYBOARD, "X")
		KEY_Y:
			return get_image(KEYBOARD, "Y")
		KEY_Z:
			return get_image(KEYBOARD, "Z")
		KEY_F1:
			return get_image(KEYBOARD, "F1")
		KEY_F2:
			return get_image(KEYBOARD, "F2")
		KEY_F3:
			return get_image(KEYBOARD, "F3")
		KEY_F4:
			return get_image(KEYBOARD, "F4")
		KEY_F5:
			return get_image(KEYBOARD, "F5")
		KEY_F6:
			return get_image(KEYBOARD, "F6")
		KEY_F7:
			return get_image(KEYBOARD, "F7")
		KEY_F8:
			return get_image(KEYBOARD, "F8")
		KEY_F9:
			return get_image(KEYBOARD, "F9")
		KEY_F10:
			return get_image(KEYBOARD, "F10")
		KEY_F11:
			return get_image(KEYBOARD, "F11")
		KEY_F12:
			return get_image(KEYBOARD, "F12")
		KEY_LEFT:
			return get_image(KEYBOARD, "Left")
		KEY_RIGHT:
			return get_image(KEYBOARD, "Right")
		KEY_UP:
			return get_image(KEYBOARD, "Up")
		KEY_DOWN:
			return get_image(KEYBOARD, "Down")
		KEY_QUOTELEFT:
			return get_image(KEYBOARD, "Tilde")
		KEY_MINUS:
			return get_image(KEYBOARD, "Minus")
		KEY_PLUS:
			return get_image(KEYBOARD, "Plus")
		KEY_BACKSPACE:
			return get_image(KEYBOARD, "Backspace")
		KEY_BRACELEFT:
			return get_image(KEYBOARD, "BracketLeft")
		KEY_BRACERIGHT:
			return get_image(KEYBOARD, "BracketRight")
		KEY_SEMICOLON:
			return get_image(KEYBOARD, "Semicolon")
		KEY_QUOTEDBL:
			return get_image(KEYBOARD, "Quote")
		KEY_BACKSLASH:
			return get_image(KEYBOARD, "BackSlash")
		KEY_ENTER:
			return get_image(KEYBOARD, "Enter")
		KEY_ESCAPE:
			return get_image(KEYBOARD, "Esc")
		KEY_LESS:
			return get_image(KEYBOARD, "LT")
		KEY_GREATER:
			return get_image(KEYBOARD, "GT")
		KEY_QUESTION:
			return get_image(KEYBOARD, "Question")
		KEY_CONTROL:
			return get_image(KEYBOARD, "Ctrl")
		KEY_SHIFT:
			return get_image(KEYBOARD, "Shift")
		KEY_ALT:
			return get_image(KEYBOARD, "Alt")
		KEY_SPACE:
			return get_image(KEYBOARD, "Space")
		KEY_META:
			return get_image(KEYBOARD, "Win")
		KEY_CAPSLOCK:
			return get_image(KEYBOARD, "CapsLock")
		KEY_TAB:
			return get_image(KEYBOARD, "Tab")
		KEY_PRINT:
			return get_image(KEYBOARD, "PrintScrn")
		KEY_INSERT:
			return get_image(KEYBOARD, "Insert")
		KEY_HOME:
			return get_image(KEYBOARD, "Home")
		KEY_PAGEUP:
			return get_image(KEYBOARD, "PageUp")
		KEY_DELETE:
			return get_image(KEYBOARD, "Delete")
		KEY_END:
			return get_image(KEYBOARD, "End")
		KEY_PAGEDOWN:
			return get_image(KEYBOARD, "PageDown")
	return null

func get_joypad_model(device: int) -> String:
	if not cached_model.empty():
		return cached_model
	
	var model := "Xbox"
	if joypad_model == JoypadModel.AUTO and device >= 0:
		var device_name := Input.get_joy_name(device)
		if device_name.find("DualShock") > -1 or device_name.find("PlayStation") > -1:
			model = "DualShock"
		elif device_name.find("Joy-Con") > -1:
			model = "Joy-Con"
	elif joypad_model == JoypadModel.DUALSHOCK:
		model = "DualShock"
	elif joypad_model == JoypadModel.JOY_CON:
		model = "Joy-Con"
	
	cached_model = model
	return model

func get_joypad(button: int, device: int) -> Texture:
	var model := get_joypad_model(device) + "/"
	
	match button:
		JOY_BUTTON_0:
			return get_image(JOYPAD, model + "A")
		JOY_BUTTON_1:
			return get_image(JOYPAD, model + "B")
		JOY_BUTTON_2:
			return get_image(JOYPAD, model + "X")
		JOY_BUTTON_3:
			return get_image(JOYPAD, model + "Y")
		JOY_BUTTON_4:
			return get_image(JOYPAD, model + "LB")
		JOY_BUTTON_5:
			return get_image(JOYPAD, model + "RB")
		JOY_BUTTON_6:
			return get_image(JOYPAD, model + "LT")
		JOY_BUTTON_7:
			return get_image(JOYPAD, model + "RT")
		JOY_BUTTON_8:
			return get_image(JOYPAD, model + "L")
		JOY_BUTTON_9:
			return get_image(JOYPAD, model + "R")
		JOY_BUTTON_10:
			return get_image(JOYPAD, model + "Select")
		JOY_BUTTON_11:
			return get_image(JOYPAD, model + "Start")
		JOY_BUTTON_12:
			return get_image(JOYPAD, model + "DPadUp")
		JOY_BUTTON_13:
			return get_image(JOYPAD, model + "DPadDown")
		JOY_BUTTON_14:
			return get_image(JOYPAD, model + "DPadLeft")
		JOY_BUTTON_15:
			return get_image(JOYPAD, model + "DPadRight")
		JOY_BUTTON_17:
			return get_image(JOYPAD, model + "Share")
	return null

func get_joypad_axis(axis: int, value: float, device: int) -> Texture:
	var model := get_joypad_model(device) + "/"
	
	match axis:
		JOY_AXIS_0:
			if value < 0:
				return get_image(JOYPAD, model + "LeftStickLeft")
			elif value > 0:
				return get_image(JOYPAD, model + "LeftStickRight")
			else:
				return get_image(JOYPAD, model + "LeftStick")
		JOY_AXIS_1:
			if value < 0:
				return get_image(JOYPAD, model + "LeftStickUp")
			elif value > 0:
				return get_image(JOYPAD, model + "LeftStickDown")
			else:
				return get_image(JOYPAD, model + "LeftStick")
		JOY_AXIS_2:
			if value < 0:
				return get_image(JOYPAD, model + "RightStickLeft")
			elif value > 0:
				return get_image(JOYPAD, model + "RightStickRight")
			else:
				return get_image(JOYPAD, model + "RightStick")
		JOY_AXIS_3:
			if value < 0:
				return get_image(JOYPAD, model + "RightStickUp")
			elif value > 0:
				return get_image(JOYPAD, model + "RightStickDown")
			else:
				return get_image(JOYPAD, model + "RightStick")
	return null

func get_mouse(button: int) -> Texture:
	match button:
		BUTTON_LEFT:
			return get_image(MOUSE, "Left")
		BUTTON_RIGHT:
			return get_image(MOUSE, "Right")
		BUTTON_MIDDLE:
			return get_image(MOUSE, "Middle")
		BUTTON_WHEEL_DOWN:
			return get_image(MOUSE, "WheelDown")
		BUTTON_WHEEL_LEFT:
			return get_image(MOUSE, "WheelLeft")
		BUTTON_WHEEL_RIGHT:
			return get_image(MOUSE, "WheelRight")
		BUTTON_WHEEL_UP:
			return get_image(MOUSE, "WheelUp")
	return null

func get_image(type: int, image: String) -> Texture:
	match type:
		KEYBOARD:
			return load(base_path + "/Keyboard/" + image + ".png") as Texture
		MOUSE:
			return load(base_path + "/Mouse/" + image + ".png") as Texture
		JOYPAD:
			return load(base_path + "/Joypad/" + image + ".png") as Texture
	return null

func on_joy_connection_changed(device: int, connected: bool):
	if connected:
		cached_model = ""
		refresh()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	
	if use_joypad and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion):
		use_joypad = false
		refresh()
	elif not use_joypad and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		use_joypad = true
		refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		refresh()
