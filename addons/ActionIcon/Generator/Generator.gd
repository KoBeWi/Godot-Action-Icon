@tool
extends Node

@onready var keyboard_sets: GridContainer = %KeyboardSets
@onready var mouse_sets: GridContainer = %MouseSets
@onready var joypad_sets: GridContainer = %JoypadSets

@onready var preview: Control = %Preview
@onready var preview_label: Label = %PreviewLabel

@onready var viewport: SubViewport = %Viewport
@onready var viewport_grid: GridContainer = %ViewportGrid
@onready var model_list: Label = %ModelList

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
	var selected_joypads: PackedStringArray
	for node in joypad_sets.get_children():
		if node is CheckBox and node.button_pressed:
			selected_joypads.append(node.text)
	
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
		if blueprint is KeyboardBlueprint:
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
			
		elif blueprint is MouseBlueprint:
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
		
		elif blueprint is JoypadBlueprint:
			var checkbox := CheckBox.new()
			checkbox.text = blueprint.name
			checkbox.pressed.connect(update_models)
			joypad_sets.add_child(checkbox)
			
			if blueprint.name in selected_joypads:
				checkbox.button_pressed = true
			
			var button := Button.new()
			button.icon = preview_icon
			joypad_sets.add_child(button)
			button.pressed.connect(preview_blueprint.bind(blueprint))
			
			if blueprint.name == default_joypad:
				checkbox.button_pressed = true
				checkbox.disabled = true
				checkbox.tooltip_text = get_parent().tr_extract.tr("Default joypad model must be included.")
	
	update_models()
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
	
	generate_blueprint(blueprint, preview, {})

func try_update_blueprint(blueprint: Blueprint) -> bool:
	var full_dir := main_dir.get_current_dir().path_join(blueprint.name)
	var full_path := full_dir.path_join("Mapping.cfg")
	
	var modtime := FileAccess.get_modified_time(full_path)
	if modtime <= blueprint.modified_time:
		return false
	
	blueprint.modified_time = modtime
	
	var cfg := ConfigFile.new()
	cfg.load(full_path)
	
	blueprint.mapping_list.clear()
	blueprint._load_data(cfg, full_dir)
	return true

func update_models():
	var models: PackedStringArray
	
	for node in joypad_sets.get_children():
		if node is CheckBox and node.button_pressed:
			var blueprint: JoypadBlueprint = get_blueprint_by_name(node.text)
			models.append_array(blueprint.models)
	
	model_list.text = tr("Included models: %s") % ", ".join(models)

func create_element() -> Control:
	var element: Control = preload("uid://dels8j71udktn").instantiate()
	element.custom_minimum_size = base_size
	return element

func generate_blueprint(blueprint: Blueprint, parent: Node, binds: Dictionary):
	var idx: int
	for mapping in blueprint.mapping_list:
		binds[mapping.key] = idx
		idx += 1
		
		var element := create_element()
		element.base.texture = mapping.base_texture
		
		if not mapping.text.is_empty():
			var element_label: Label = element.label
			element_label.add_theme_font_size_override(&"font_size", mapping.font_size)
			element_label.add_theme_font_override(&"font", mapping.font)
			element_label.add_theme_color_override(&"font_color", mapping.font_color)
			element_label.text = mapping.text
			element_label.offset_transform_position = mapping.text_offset
		
		for custom_texture in mapping.overlays:
			var trect: TextureRect = element.add_texture(custom_texture.image)
			trect.offset_transform_rotation = custom_texture.rotation
		
		parent.add_child(element)

func _confirm_generate() -> void:
	var base_path: String = ProjectSettings.get_setting(ActionIcon._ACTION_SET_SETTING)
	DirAccess.make_dir_absolute(base_path)
	
	var set_list: PackedStringArray
	
	var selected_blueprints: PackedStringArray
	selected_blueprints.append(keyboard_group.get_pressed_button().text)
	selected_blueprints.append(mouse_group.get_pressed_button().text)
	for node in joypad_sets.get_children():
		if node is CheckBox and node.button_pressed:
			selected_blueprints.append(node.text)
	
	for blueprint_name in selected_blueprints:
		var blueprint := get_blueprint_by_name(blueprint_name)
		
		set_list.append(blueprint.name)
		
		var binds: Dictionary
		if blueprint is KeyboardBlueprint:
			binds["$type"] = ActionIcon.Device.KEYBOARD
		elif blueprint is MouseBlueprint:
			binds["$type"] = ActionIcon.Device.MOUSE
		elif blueprint is JoypadBlueprint:
			binds["$type"] = ActionIcon.Device.JOYPAD
		
		for node in viewport_grid.get_children():
			node.free()
		
		generate_blueprint(blueprint, viewport_grid, binds)
		blueprint._add_extra_binds(binds)
		
		viewport_grid.reset_size()
		viewport.size = viewport_grid.size
		
		var sheet: Image = await viewport.print_image()
		
		var path := base_path.path_join("%s.png" % blueprint.name)
		sheet.save_png(path)
		
		path = base_path.path_join("%s.dat" % blueprint.name)
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(var_to_str(binds))
		f.close()
	
	var config := ConfigFile.new()
	config.load("res://addons/ActionIcon/Generator/Blueprints/Config.cfg")
	config.set_value("config", "set_list", set_list)
	config.save(base_path.path_join("Config.cfg"))
	
	EditorInterface.get_resource_filesystem().scan()

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

func _on_top_toggled(toggled_on: bool) -> void:
	dialog.hide()
	dialog.always_on_top = toggled_on
	dialog.show()

class Blueprint:
	class Mapping:
		class CustomTexture:
			var image: Texture2D
			var rotation: float
		
		var key: Variant
		
		var base_texture: Texture2D
		var text: String
		var text_offset: Vector2
		var font: Font
		var font_color: Color
		var font_size: int
		var overlays: Array[CustomTexture]
		
		func add_overlay(texture: Texture2D, rotation := 0):
			var ct := CustomTexture.new()
			ct.image = texture
			ct.rotation = rotation * (PI / 2)
			overlays.append(ct)
	
	var name: String
	var modified_time: int
	var mapping_list: Array[Mapping]
	
	func get_section(config_file: ConfigFile, section: String, base_dir: String) -> Dictionary[String, Variant]:
		var ret: Dictionary[String, Variant]
		
		var copied: ConfigFile
		for key in config_file.get_section_keys(section):
			if key == "copy":
				var copyfile := config_file.get_value(section, key)
				copied = ConfigFile.new()
				copied.load(base_dir.path_join("..").path_join(copyfile).path_join("Mapping.cfg"))
				continue
			
			ret[key] = config_file.get_value(section, key)
		
		if copied:
			var copied_stuff := get_section(copied, section, base_dir)
			ret.merge(copied_stuff)
		
		return ret
	
	func _load_data(file: ConfigFile, base_dir: String) -> void:
		if not file.has_section("custom"):
			return
		
		var customs := get_section(file, "custom", base_dir)
		for custom_name in customs:
			var data: Dictionary = customs[custom_name]
			
			var mapping := Mapping.new()
			mapping.key = custom_name
			
			if "base" in data:
				mapping.base_texture = load(base_dir.path_join(data["base"]))
			
			if "text" in data:
				mapping.text = data["text"]
				
				if "text_offset" in data:
					mapping.text_offset = data["text_offset"]
				
				if "font" in data:
					mapping.font = load(base_dir.path_join(data["font"]))
				
				if "font_color" in data:
					mapping.font_color = Color(data["font_color"])
				
				if "font_size" in data:
					mapping.font_color = data["font_size"]
			
			for key: String in data:
				if key.begins_with("overlay"):
					var overlay = data[key]
					if overlay is String:
						mapping.add_overlay(load(base_dir.path_join(overlay)))
					elif overlay is Dictionary:
						mapping.add_overlay(load(base_dir.path_join(overlay["image"])), overlay["rotation"])
			
			mapping_list.append(mapping)
	
	func _add_extra_binds(binds: Dictionary):
		pass

class KeyboardBlueprint extends Blueprint:
	var font: Font
	var font_color: Color
	var font_size: int
	
	func _load_data(file: ConfigFile, base_dir: String) -> void:
		font = load(base_dir.path_join(file.get_value("info", "font")))
		font_color = Color(file.get_value("info", "font_color"))
		font_size = file.get_value("info", "font_size")
		
		var maplist := get_section(file, "keys", base_dir)
		for texname in maplist:
			var texture: Texture2D = load(base_dir.path_join(texname))
			
			var mapping_data: Dictionary = maplist[texname]
			for mapping_name: String in mapping_data:
				var mapping := Mapping.new()
				mapping.key = OS.find_keycode_from_string(mapping_name)
				
				if mapping.key == KEY_NONE:
					push_warning("Unrecognized keycode name: %s" % mapping_name)
				
				mapping.base_texture = texture
				mapping.font = font
				mapping.font_color = font_color
				mapping.font_size = font_size
				
				var mapping_value: Variant = mapping_data[mapping_name]
				if mapping_value is int:
					mapping.text = mapping_name
				elif mapping_value is String:
					mapping.text = mapping_value
				elif mapping_value is Dictionary:
					mapping.text = mapping_value.get("text", mapping.text)
					mapping.text_offset = mapping_value.get("text_offset", mapping.text_offset)
					mapping.font_color = mapping_value.get("font_color", font_color)
					
					if mapping_value.has("font_size"):
						mapping.font_size = mapping_value["font_size"]
					elif mapping_value.has("font_percent"):
						mapping.font_size = roundi(font_size * mapping_value["font_percent"] * 0.01)
					elif mapping_value.has("font_ratio"):
						mapping.font_size = roundi(font_size * mapping_value["font_ratio"])
					else:
						mapping.font_size = font_size
					
					if mapping_value.has("font"):
						mapping.font = load(base_dir.path_join(mapping["font"]))
					else:
						mapping.font = font
					
					var image_name: String = mapping_value.get("image", "")
					if not image_name.is_empty():
						mapping.add_overlay(load(base_dir.path_join(image_name)))
				
				mapping_list.append(mapping)
		
		super(file, base_dir)
	
	func _add_extra_binds(binds: Dictionary) -> void:
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
	
	func automap(binds: Dictionary, from: int, to: int):
		if not from in binds and to in binds:
			binds[from] = binds[to]

class MouseBlueprint extends Blueprint:
	func _load_data(file: ConfigFile, base_dir: String) -> void:
		var base_texture: Texture2D = load(base_dir.path_join(file.get_value("info", "base_image")))
		var middle_texture: Texture2D
		
		var maplist := get_section(file, "buttons", base_dir)
		var add_button_mapping = func(key: String, button: int) -> bool:
			if not key in maplist:
				return false
			
			var mapping := Mapping.new()
			mapping.key = button
			mapping.base_texture = base_texture
			mapping.add_overlay(load(base_dir.path_join(maplist[key])))
			mapping_list.append(mapping)
			
			return true
		
		add_button_mapping.call("left", MOUSE_BUTTON_LEFT)
		add_button_mapping.call("right", MOUSE_BUTTON_RIGHT)
		if add_button_mapping.call("middle", MOUSE_BUTTON_MIDDLE):
			var mapping := mapping_list[-1]
			middle_texture = mapping.overlays[0].image
		
		add_button_mapping.call("extra1", MOUSE_BUTTON_XBUTTON1)
		add_button_mapping.call("extra2", MOUSE_BUTTON_XBUTTON2)
		
		maplist = get_section(file, "wheel", base_dir)
		if not middle_texture and not maplist.is_empty():
			push_warning("No middle button defined, wheel images will be incomplete.")
		
		var add_wheel_mapping = func(key: String, button: int):
			if not key in maplist:
				return
			
			var mapping := Mapping.new()
			mapping.key = button
			mapping.base_texture = base_texture
			mapping.add_overlay(middle_texture)
			mapping.add_overlay(load(base_dir.path_join(maplist[key])))
			mapping_list.append(mapping)
		
		add_wheel_mapping.call("up", MOUSE_BUTTON_WHEEL_UP)
		add_wheel_mapping.call("down", MOUSE_BUTTON_WHEEL_DOWN)
		add_wheel_mapping.call("right", MOUSE_BUTTON_WHEEL_RIGHT)
		add_wheel_mapping.call("left", MOUSE_BUTTON_WHEEL_LEFT)
		
		super(file, base_dir)

class JoypadBlueprint extends Blueprint:
	var models: PackedStringArray
	
	func _load_data(file: ConfigFile, base_dir: String) -> void:
		models = file.get_value("info", "models")
		
		var maplist := get_section(file, "buttons", base_dir)
		var add_button_mapping = func(key: String, button: int):
			if not key in maplist:
				return
			
			var mapping := Mapping.new()
			mapping.key = button
			mapping.base_texture = load(base_dir.path_join(maplist[key]))
			mapping_list.append(mapping)
		
		add_button_mapping.call("A", JOY_BUTTON_A)
		add_button_mapping.call("B", JOY_BUTTON_B)
		add_button_mapping.call("X", JOY_BUTTON_X)
		add_button_mapping.call("Y", JOY_BUTTON_Y)
		
		add_button_mapping.call("L1", JOY_BUTTON_LEFT_SHOULDER)
		add_button_mapping.call("L2", (JOY_AXIS_TRIGGER_LEFT + 1) * 100)
		add_button_mapping.call("L3", JOY_BUTTON_LEFT_STICK)
		add_button_mapping.call("R1", JOY_BUTTON_RIGHT_SHOULDER)
		add_button_mapping.call("R2", (JOY_AXIS_TRIGGER_RIGHT + 1) * 100)
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
				var mapping := Mapping.new()
				mapping.key = button + i
				mapping.base_texture = base
				
				if button >= 100:
					const DIRECTIONS = [0, 2, 1, 3]
					mapping.add_overlay(dir, DIRECTIONS[i])
				else:
					const DIRECTIONS = [3, 1, 2, 0]
					mapping.add_overlay(dir, DIRECTIONS[i])
				
				mapping_list.append(mapping)
		
		add_direction_mapping.call("DPad", JOY_BUTTON_DPAD_UP)
		add_direction_mapping.call("LeftStick", (JOY_AXIS_LEFT_X + 1) * 100)
		add_direction_mapping.call("RightStick", (JOY_AXIS_RIGHT_X + 1) * 100)
		
		super(file, base_dir)
	
	func _add_extra_binds(binds: Dictionary):
		binds["$models"] = models
