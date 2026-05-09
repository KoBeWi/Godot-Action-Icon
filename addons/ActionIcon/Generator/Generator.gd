@tool
extends Node

@onready var keyboard_sets: GridContainer = %KeyboardSets
@onready var mouse_sets: GridContainer = %MouseSets
@onready var joypad_sets: GridContainer = %JoypadSets

@onready var preview: Control = %Preview
@onready var preview_label: Label = %PreviewLabel

@onready var viewport: SubViewport = %Viewport
@onready var viewport_grid: GridContainer = %ViewportGrid

var dialog: ConfirmationDialog
var blueprint_list: Array[Blueprint]
var current_previewed: Blueprint

var main_dir: DirAccess
var base_size: Vector2i
var default_joypad: String

var keyboard_group := ButtonGroup.new()
var mouse_group := ButtonGroup.new()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SCENE_INSTANTIATED:
			main_dir = DirAccess.open("res://addons/ActionIcon/Generator/Blueprints")
			
			dialog = %Dialog
			dialog.hide()
		
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_on_dialog_focus_entered()

func show():
	blueprint_list.clear()
	
	var main_config := ConfigFile.new()
	main_config.load(main_dir.get_current_dir().path_join("Config.cfg"))
	base_size = main_config.get_value("config", "base_size")
	default_joypad = main_config.get_value("config", "default_joypad")
	
	for dir in main_dir.get_directories():
		var full_dir := main_dir.get_current_dir().path_join(dir)
		var full_path := full_dir.path_join("Mapping.cfg")
		var blueprint: Blueprint
		
		var config := ConfigFile.new()
		config.load(full_path)
		
		var type: String = config.get_value("info", "type")
		match type:
			"keyboard":
				blueprint = KeyboardBlueprint.new()
			
			"mouse":
				blueprint = MouseBlueprint.new()
			
			"joypad":
				blueprint = JoypadBlueprint.new()
			
			_:
				continue
		
		blueprint._load_data(config, full_dir)
		
		blueprint.name = dir
		blueprint.modified_time = FileAccess.get_modified_time(full_path)
		blueprint_list.append(blueprint)
	
	for child in keyboard_sets.get_children():
		child.free()
	for child in mouse_sets.get_children():
		child.free()
	for child in joypad_sets.get_children():
		child.free()
	
	var preview_icon := EditorInterface.get_editor_theme().get_icon(&"Search", &"EditorIcons")
	for blueprint in blueprint_list:
		match blueprint.type:
			Blueprint.Type.KEYBOARD:
				var checkbox := CheckBox.new()
				checkbox.text = blueprint.name
				checkbox.button_group = keyboard_group
				keyboard_sets.add_child(checkbox)
				
				var button := Button.new()
				button.icon = preview_icon
				keyboard_sets.add_child(button)
				button.pressed.connect(preview_blueprint.bind(blueprint))
				
				if keyboard_sets.get_child_count() == 2:
					checkbox.button_pressed = true
			
			Blueprint.Type.MOUSE:
				var checkbox := CheckBox.new()
				checkbox.text = blueprint.name
				checkbox.button_group = mouse_group
				mouse_sets.add_child(checkbox)
				
				var button := Button.new()
				button.icon = preview_icon
				mouse_sets.add_child(button)
				button.pressed.connect(preview_blueprint.bind(blueprint))
				
				if mouse_sets.get_child_count() == 2:
					checkbox.button_pressed = true
			
			Blueprint.Type.JOYPAD:
				var checkbox := CheckBox.new()
				checkbox.text = blueprint.name
				joypad_sets.add_child(checkbox)
				
				var button := Button.new()
				button.icon = preview_icon
				joypad_sets.add_child(button)
				button.pressed.connect(preview_blueprint.bind(blueprint))
				
				if blueprint.name == default_joypad:
					checkbox.button_pressed = true
					checkbox.disabled = true
					checkbox.tooltip_text = "Default joypad model must be included."
	
	dialog.popup_centered_ratio(0.8)

func get_blueprint_by_name(bname: String) -> Blueprint:
	for b in blueprint_list:
		if b.name == bname:
			return b
	return null

func preview_blueprint(blueprint: Blueprint):
	preview_label.hide()
	
	for child in preview.get_children():
		child.free()
	
	try_update_blueprint(blueprint)
	
	current_previewed = blueprint
	
	blueprint.generate_start()
	while true:
		var element: Control = preload("uid://dels8j71udktn").instantiate()
		element.custom_minimum_size = base_size
		
		if not blueprint._generate_next(element, {}):
			element.free()
			break
		
		preview.add_child(element)
		blueprint.current_index += 1

func try_update_blueprint(blueprint: Blueprint) -> bool:
	var full_dir := main_dir.get_current_dir().path_join(blueprint.name)
	var full_path := full_dir.path_join("Mapping.cfg")
	
	var modtime := FileAccess.get_modified_time(full_path)
	if modtime <= blueprint.modified_time:
		return false
	
	blueprint.modified_time = modtime
	
	var cfg := ConfigFile.new()
	cfg.load(full_path)
	
	blueprint._load_data(cfg, full_dir)
	return true

func _confirm_generate() -> void:
	var base_path: String = ProjectSettings.get_setting(ActionIcon._ACTION_SET_DIR)
	var set_list: PackedStringArray
	
	var selected_blueprints: PackedStringArray
	selected_blueprints.append(keyboard_group.get_pressed_button().text)
	selected_blueprints.append(mouse_group.get_pressed_button().text)
	for node in joypad_sets.get_children():
		if node is CheckBox and node.button_pressed:
			selected_blueprints.append(node.text)
	
	for blueprint_name in selected_blueprints:
		var blueprint := get_blueprint_by_name(blueprint_name)
		if blueprint is not KeyboardBlueprint:##
			continue
		
		set_list.append(blueprint.name)
		
		var binds: Dictionary
		binds["$type"] = blueprint.type
		
		for node in viewport_grid.get_children():
			node.free()
		
		blueprint.generate_start()
		while true:
			var element: Control = preload("uid://dels8j71udktn").instantiate()
			element.custom_minimum_size = base_size
			
			if not blueprint._generate_next(element, binds):
				element.free()
				break
			
			viewport_grid.add_child(element)
			blueprint.current_index += 1
		
		viewport_grid.reset_size()
		
		viewport.size = viewport_grid.size
		var sheet: Image = await viewport.print_image()
		
		var path := base_path.path_join("%s.png" % blueprint.name)
		sheet.save_png(path)
		
		path = base_path.path_join("%s.dat" % blueprint.name)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(var_to_str(binds))
		f.close()
		
		EditorInterface.get_resource_filesystem().update_file(path)
	
	var config := ConfigFile.new()
	config.load("res://addons/ActionIcon/Generator/Blueprints/Config.cfg")
	config.set_value("config", "set_list", set_list)
	config.save(base_path.path_join("Config.cfg"))

func _on_dialog_visibility_changed() -> void:
	if dialog.visible:
		return
	
	current_previewed = null
	preview_label.show()
	
	for child in preview.get_children():
		child.free()

func _on_dialog_focus_entered() -> void:
	if is_part_of_edited_scene():
		return
	
	if current_previewed:
		if try_update_blueprint(current_previewed):
			preview_blueprint(current_previewed)

class Blueprint:
	enum Type { KEYBOARD, MOUSE, JOYPAD }
	
	var name: String
	var type: Type
	
	var current_index: int
	var modified_time: int
	
	func get_section(config_file: ConfigFile, section: String, base_dir: String) -> Dictionary[String, Variant]:
		var ret: Dictionary[String, Variant]
		
		for key in config_file.get_section_keys(section):
			if key == "copy":
				var copyfile := config_file.get_value(section, key)
				var copied := ConfigFile.new()
				copied.load(base_dir.path_join("..").path_join(copyfile).path_join("Mapping.cfg"))
				ret.merge(get_section(copied, section, base_dir))
				
				continue
			
			ret[key] = config_file.get_value(section, key)
		
		return ret
	
	func generate_start():
		current_index = 0
	
	func _load_data(file: ConfigFile, base_dir: String) -> void:
		pass
	
	func _generate_next(element: Node, binds: Dictionary) -> bool:
		return false

class KeyboardBlueprint extends Blueprint:
	class KeyMapping:
		var keycode: int
		var base: Texture2D
		var text: String
		var text_offset: Vector2
		var font: Font
		var font_size: int
		var font_color := Color.TRANSPARENT
		var image: Texture2D
	
	var font: Font
	var font_color: Color
	var font_size: int
	var mappings: Array[KeyMapping]
	
	func _init() -> void:
		type = Type.KEYBOARD
	
	func _load_data(file: ConfigFile, base_dir: String) -> void:
		font = load(base_dir.path_join(file.get_value("info", "font")))
		font_color = Color(file.get_value("info", "font_color"))
		font_size = file.get_value("info", "font_size")
		
		var maplist := get_section(file, "keys", base_dir)
		mappings.clear()
		
		for texname in maplist:
			var texture: Texture2D = load(base_dir.path_join(texname))
			
			var mapping_data: Dictionary = maplist[texname]
			for mapping_name: String in mapping_data:
				var mapping := KeyMapping.new()
				mapping.base = texture
				mapping.keycode = OS.find_keycode_from_string(mapping_name)
				if mapping.keycode == KEY_NONE:
					push_warning("Unrecognized keycode name: %s" % mapping_name)
				
				var mapping_value: Variant = mapping_data[mapping_name]
				if mapping_value is int:
					mapping.text = mapping_name
				elif mapping_value is String:
					mapping.text = mapping_value
				elif mapping_value is Dictionary:
					mapping.text = mapping_value.get("text", mapping.text)
					mapping.text_offset = mapping_value.get("text_offset", mapping.text_offset)
					mapping.font_color = mapping_value.get("font_color", mapping.font_color)
					
					if mapping_value.has("font_size"):
						mapping.font_size = mapping_value["font_size"]
					elif mapping_value.has("font_percent"):
						mapping.font_size = roundi(font_size * mapping_value["font_percent"] * 0.01)
					elif mapping_value.has("font_ratio"):
						mapping.font_size = roundi(font_size * mapping_value["font_ratio"])
					
					if mapping_value.has("font"):
						mapping.font = load(base_dir.path_join(mapping["font"]))
					
					var image_name: String = mapping_value.get("image", "")
					if not image_name.is_empty():
						mapping.image = load(base_dir.path_join(image_name))
				
				mappings.append(mapping)
	
	func _generate_next(element: Node, binds: Dictionary) -> bool:
		if current_index == mappings.size():
			automap(binds, KEY_KP_0, KEY_0)
			automap(binds, KEY_KP_1, KEY_1)
			automap(binds, KEY_KP_2, KEY_2)
			automap(binds, KEY_KP_3, KEY_3)
			automap(binds, KEY_KP_4, KEY_4)
			automap(binds, KEY_KP_5, KEY_5)
			automap(binds, KEY_KP_6, KEY_6)
			automap(binds, KEY_KP_7, KEY_7)
			automap(binds, KEY_KP_8, KEY_8)
			automap(binds, KEY_KP_9, KEY_9)
			automap(binds, KEY_KP_SUBTRACT, KEY_MINUS)
			automap(binds, KEY_KP_DIVIDE, KEY_SLASH)
			return false
		
		var key := mappings[current_index]
		binds[key.keycode] = current_index
		
		element.base.texture = key.base
		
		var element_label: Label = element.label
		element_label.add_theme_font_size_override(&"font_size", key.font_size if key.font_size != 0 else font_size)
		element_label.add_theme_font_override(&"font", key.font if key.font else font)
		element_label.add_theme_color_override(&"font_color", key.font_color if key.font_color.a > 0 else font_color)
		element_label.text = key.text
		element_label.offset_transform_position = key.text_offset
		
		element.overlay.texture = key.image
		
		return true
	
	func automap(binds: Dictionary, from: int, to: int):
		if not from in binds and to in binds:
			binds[from] = binds[to]

class MouseBlueprint extends Blueprint:
	class MouseMapping:
		var button: int
		var image: Texture2D
	
	var base_texture: Texture2D
	var middle_texture: Texture2D
	var mappings: Array[MouseMapping]
	
	func _init() -> void:
		type = Type.MOUSE

	func _load_data(file: ConfigFile, base_dir: String) -> void:
		base_texture = load(base_dir.path_join(file.get_value("info", "base_image")))
		middle_texture = null
		
		var maplist := get_section(file, "buttons", base_dir)
		var add_button_mapping = func(key: String, button: int):
			if not key in maplist:
				return
			
			var mapping := MouseMapping.new()
			mapping.button = button
			mapping.image = load(base_dir.path_join(maplist[key]))
			mappings.append(mapping)
		
		add_button_mapping.call("left", MOUSE_BUTTON_LEFT)
		add_button_mapping.call("right", MOUSE_BUTTON_RIGHT)
		add_button_mapping.call("middle", MOUSE_BUTTON_MIDDLE)
		add_button_mapping.call("extra1", MOUSE_BUTTON_XBUTTON1)
		add_button_mapping.call("extra2", MOUSE_BUTTON_XBUTTON2)
		
		maplist = get_section(file, "wheel", base_dir)
		var add_wheel_mapping = func(key: String, button: int):
			if not key in maplist:
				return
			
			var mapping := MouseMapping.new()
			mapping.button = button
			mapping.image = load(base_dir.path_join(maplist[key]))
			mappings.append(mapping)
		
		add_wheel_mapping.call("up", MOUSE_BUTTON_WHEEL_UP)
		add_wheel_mapping.call("down", MOUSE_BUTTON_WHEEL_DOWN)
		add_wheel_mapping.call("right", MOUSE_BUTTON_WHEEL_RIGHT)
		add_wheel_mapping.call("left", MOUSE_BUTTON_WHEEL_LEFT)
	
	func _generate_next(element: Node, binds: Dictionary) -> bool:
		if current_index == mappings.size():
			return false
		
		var mapping := mappings[current_index]
		element.base.texture = base_texture
		
		if mapping.button >= MOUSE_BUTTON_WHEEL_UP and mapping.button <= MOUSE_BUTTON_WHEEL_RIGHT:
			if not middle_texture:
				push_warning("No middle button defined, wheel image will be incomplete.")
			
			element.overlay.texture = middle_texture
			element.overlay2.texture = mapping.image
		else:
			element.overlay.texture = mapping.image
		
		if mapping.button == MOUSE_BUTTON_MIDDLE:
			middle_texture = mapping.image
		
		binds[mapping.button] = current_index
		return true

class JoypadBlueprint extends Blueprint:
	class JoypadMapping:
		var button: int
		var image: Texture2D
		var image2: Texture2D
		var rotation: float
	
	var models: PackedStringArray
	var mappings: Array[JoypadMapping]
	
	func _init() -> void:
		type = Type.JOYPAD
	
	func _load_data(file: ConfigFile, base_dir: String) -> void:
		models = file.get_value("info", "models")
		
		var maplist := get_section(file, "buttons", base_dir)
		var add_button_mapping = func(key: String, button: int):
			if not key in maplist:
				return
			
			var mapping := JoypadMapping.new()
			mapping.button = button
			mapping.image = load(base_dir.path_join(maplist[key]))
			mappings.append(mapping)
		
		add_button_mapping.call("A", JOY_BUTTON_A)
		add_button_mapping.call("B", JOY_BUTTON_B)
		add_button_mapping.call("X", JOY_BUTTON_X)
		add_button_mapping.call("Y", JOY_BUTTON_Y)
		
		add_button_mapping.call("L1", JOY_BUTTON_LEFT_SHOULDER)
		add_button_mapping.call("L2", JOY_AXIS_TRIGGER_LEFT)
		add_button_mapping.call("L3", JOY_BUTTON_LEFT_STICK)
		add_button_mapping.call("R1", JOY_BUTTON_RIGHT_SHOULDER)
		add_button_mapping.call("L2", JOY_AXIS_TRIGGER_RIGHT)
		add_button_mapping.call("R3", JOY_BUTTON_RIGHT_STICK)
		
		add_button_mapping.call("Back", JOY_BUTTON_BACK)
		add_button_mapping.call("Start", JOY_BUTTON_START)
		add_button_mapping.call("Guide", JOY_BUTTON_GUIDE)
		add_button_mapping.call("Misc1", JOY_BUTTON_MISC1)
		add_button_mapping.call("Misc2", JOY_BUTTON_MISC2)
		add_button_mapping.call("Misc3", JOY_BUTTON_MISC3)
		add_button_mapping.call("Misc4", JOY_BUTTON_MISC4)
		add_button_mapping.call("Misc5", JOY_BUTTON_MISC5)
		add_button_mapping.call("Misc6", JOY_BUTTON_MISC6)
		
		add_button_mapping.call("Paddle1", JOY_BUTTON_PADDLE1)
		add_button_mapping.call("Paddle2", JOY_BUTTON_PADDLE2)
		add_button_mapping.call("Paddle3", JOY_BUTTON_PADDLE3)
		add_button_mapping.call("Paddle4", JOY_BUTTON_PADDLE4)
		add_button_mapping.call("Touchpad", JOY_BUTTON_TOUCHPAD)
		
		maplist = get_section(file, "directions", base_dir)
		var add_direction_mapping = func(key: String, button: int):
			if not key in maplist:
				return
			
			var info: Dictionary = maplist[key]
			var base: Texture2D = load(base_dir.path_join(info["base"]))
			var dir: Texture2D = load(base_dir.path_join(info["direction"]))
			
			for i in 4:
				var mapping := JoypadMapping.new()
				mapping.button = button
				mapping.image = base
				mapping.image2 = dir
				const DIRECTIONS = [-PI/2, PI/2, PI, 0]
				mapping.rotation = DIRECTIONS[i]
				mapping.button = button + i
				mappings.append(mapping)
		
		add_direction_mapping.call("DPad", JOY_BUTTON_DPAD_UP)
		add_direction_mapping.call("LeftStick", JOY_AXIS_LEFT_X)
		add_direction_mapping.call("RightStick", JOY_AXIS_RIGHT_X)
	
	func _generate_next(element: Node, binds: Dictionary) -> bool:
		if current_index == mappings.size():
			return false
		
		var mapping := mappings[current_index]
		element.base.texture = mapping.image
		
		if mapping.image2:
			element.overlay.texture = mapping.image2
			element.overlay.offset_transform_rotation = mapping.rotation
		
		binds[mapping.button] = current_index
		return true
