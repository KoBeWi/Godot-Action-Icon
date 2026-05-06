@tool
extends Node

@onready var viewport: SubViewport = %Viewport
@onready var base_generator: TextureRect = %BaseGenerator
@onready var text_generator: Label = %TextGenerator
@onready var overlay_generator: TextureRect = %OverlayGenerator

@onready var keyboard_sets: GridContainer = %KeyboardSets
@onready var mouse_sets: GridContainer = %MouseSets
@onready var joypad_sets: GridContainer = %JoypadSets

@onready var preview: Control = %Preview
@onready var preview_label: Label = %PreviewLabel

var dialog: ConfirmationDialog
var blueprint_list: Array[Blueprint]
var current_previewed: Blueprint

var main_dir: DirAccess

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
				
				if mouse_sets.get_child_count() == 2:
					checkbox.button_pressed = true
			
			Blueprint.Type.JOYPAD:
				var checkbox := CheckBox.new()
				checkbox.text = blueprint.name
				joypad_sets.add_child(checkbox)
				
				var button := Button.new()
				button.icon = preview_icon
				joypad_sets.add_child(button)
	
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
	
	current_previewed = blueprint
	
	blueprint.generate_start()
	while true:
		var element: Control = preload("uid://dels8j71udktn").instantiate()
		element.custom_minimum_size = Vector2(100, 100)
		
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
		if blueprint is not KeyboardBlueprint:
			continue
		
		set_list.append(blueprint.name)
		
		blueprint.viewport = viewport
		blueprint.base_generator = base_generator
		blueprint.text_generator = text_generator
		blueprint.overlay_generator = overlay_generator
		
		var binds: Dictionary
		binds["$type"] = blueprint.type
		var images: Array[Image]# := await blueprint.generate(binds)
		
		var sheet := Image.create_empty(viewport.size.x * mini(images.size(), ActionIcon._SHEET_COLUMNS), viewport.size.y * (images.size() / ActionIcon._SHEET_COLUMNS + 1), false, Image.FORMAT_RGBA8)
		
		for i in images.size():
			var image := images[i]
			sheet.blit_rect(image, Rect2(Vector2i(), image.get_size()), Vector2i(i % ActionIcon._SHEET_COLUMNS * viewport.size.x, i / ActionIcon._SHEET_COLUMNS * viewport.size.y))
		
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
	
	var viewport: SubViewport
	var base_generator: TextureRect
	var text_generator: Label
	var overlay_generator: TextureRect
	
	var current_index: int
	var modified_time: int
	
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
		
		var maplist: PackedStringArray
		var keycfg := file
		
		if file.has_section_key("keys", "copy"):
			keycfg = ConfigFile.new()
			keycfg.load(base_dir.path_join("..").path_join(file.get_value("keys", "copy")).path_join("Mapping.cfg"))
			maplist = keycfg.get_section_keys("keys")
		else:
			maplist = file.get_section_keys("keys")
		
		mappings.clear()
		
		for texname in maplist:
			var texture: Texture2D = load(base_dir.path_join(texname))
			
			var mapping_data: Dictionary = keycfg.get_value("keys", texname)
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
					mapping.font_size = mapping_value.get("font_size", mapping.font_size)
					mapping.font_color = mapping_value.get("font_color", mapping.font_color)
					
					if mapping_value.has("font"):
						mapping.font = load(base_dir.path_join(mapping["font"]))
					
					var image_name: String = mapping_value.get("image", "")
					if not image_name.is_empty():
						mapping.image = load(base_dir.path_join(image_name))
				
				mappings.append(mapping)
	
	func _generate_next(element: Node, binds: Dictionary) -> bool:
		if current_index == mappings.size():
			return false
		
		var key := mappings[current_index]
		
		element.base.texture = key.base
		
		var element_label: Label = element.label
		element_label.add_theme_font_size_override(&"font_size", key.font_size if key.font_size != 0 else font_size)
		element_label.add_theme_font_override(&"font", key.font if key.font else font)
		element_label.add_theme_color_override(&"font_color", key.font_color if key.font_color.a > 0 else font_color)
		element_label.text = key.text
		element_label.offset_transform_position = key.text_offset
		
		element.overlay.texture = key.image
		
		return true
	
	func generate(binds: Dictionary) -> Array[Image]:
		var images: Array[Image]
		
		for key in mappings:
			binds[key.keycode] = images.size()
			
			text_generator.add_theme_font_size_override(&"font_size", key.font_size if key.font_size != 0 else font_size)
			text_generator.add_theme_font_override(&"font", key.font if key.font else font)
			text_generator.add_theme_color_override(&"font_color", key.font_color if key.font_color.a > 0 else font_color)
			
			images.append(await generate_key(key))
		
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
		
		return images
	
	func generate_key(mapping: KeyMapping) -> Image:
		base_generator.texture = mapping.base
		text_generator.text = mapping.text
		text_generator.position = mapping.text_offset
		text_generator.size = viewport.size
		overlay_generator.texture = mapping.image
		
		return await viewport.print_image()
	
	func automap(binds: Dictionary, from: int, to: int):
		if not from in binds and to in binds:
			binds[from] = binds[to]

class MouseBlueprint extends Blueprint:
	func _init() -> void:
		type = Type.MOUSE

class JoypadBlueprint extends Blueprint:
	func _init() -> void:
		type = Type.JOYPAD
