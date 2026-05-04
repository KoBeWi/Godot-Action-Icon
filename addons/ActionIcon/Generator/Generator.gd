@tool
extends Node

@onready var viewport: SubViewport = %Viewport
@onready var base_generator: TextureRect = %BaseGenerator
@onready var text_generator: Label = %TextGenerator
@onready var overlay_generator: TextureRect = %OverlayGenerator

var dialog: ConfirmationDialog
var blueprint_list: Array[Blueprint]

var main_dir: DirAccess

func _notification(what: int) -> void:
	if what == NOTIFICATION_SCENE_INSTANTIATED:
		main_dir = DirAccess.open("res://addons/ActionIcon/Generator/Blueprints")
		
		dialog = %Dialog
		dialog.hide()

func show():
	blueprint_list.clear()
	for dir in main_dir.get_directories():
		var full_dir := main_dir.get_current_dir().path_join(dir)
		var blueprint: Blueprint
		
		var config := ConfigFile.new()
		config.load(full_dir.path_join("Mapping.cfg"))
		
		var type: String = config.get_value("info", "type")
		match type:
			"keyboard":
				var kblueprint := KeyboardBlueprint.new()
				kblueprint.font = load(full_dir.path_join(config.get_value("info", "font")))
				kblueprint.font_color = Color(config.get_value("info", "font_color"))
				kblueprint.font_size = config.get_value("info", "font_size")
				
				var maplist: PackedStringArray
				var keycfg := config
				
				if config.has_section_key("keys", "copy"):
					keycfg = ConfigFile.new()
					keycfg.load(full_dir.path_join("..").path_join(config.get_value("keys", "copy")).path_join("Mapping.cfg"))
					maplist = keycfg.get_section_keys("keys")
				else:
					maplist = config.get_section_keys("keys")
				
				for texname in maplist:
					var texture: Texture2D = load(full_dir.path_join(texname))
					
					var mapping_data: Dictionary = keycfg.get_value("keys", texname)
					for mapping_name: String in mapping_data:
						var mapping := KeyboardBlueprint.KeyMapping.new()
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
								mapping.font = load(full_dir.path_join(mapping["font"]))
							
							var image_name: String = mapping_value.get("image", "")
							if not image_name.is_empty():
								mapping.image = load(full_dir.path_join(image_name))
						
						kblueprint.mappings.append(mapping)
				
				blueprint = kblueprint
			
			_:
				continue
		
		blueprint.name = dir
		blueprint_list.append(blueprint)
	
	dialog.popup_centered_ratio(0.8)

func _confirm_generate() -> void:
	var base_path: String = ProjectSettings.get_setting(ActionIcon._ACTION_SET_DIR)
	var set_list: PackedStringArray
	
	for blueprint in blueprint_list:
		if blueprint is not KeyboardBlueprint:
			continue
		
		set_list.append(blueprint.name)
		
		blueprint.viewport = viewport
		blueprint.base_generator = base_generator
		blueprint.text_generator = text_generator
		blueprint.overlay_generator = overlay_generator
		
		var binds: Dictionary
		binds["$type"] = blueprint.type
		var images := await blueprint.generate(binds)
		
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

class Blueprint:
	enum Type { KEYBOARD, MOUSE, JOYPAD }
	
	var name: String
	var type: Type
	
	var viewport: SubViewport
	var base_generator: TextureRect
	var text_generator: Label
	var overlay_generator: TextureRect
	
	func generate(binds: Dictionary) -> Array[Image]:
		return []

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
	
	func generate(binds: Dictionary) -> Array[Image]:
		var images: Array[Image]
		
		for key in mappings:
			binds[key.keycode] = images.size()
			
			text_generator.add_theme_font_size_override(&"font_size", key.font_size if key.font_size != 0 else font_size)
			text_generator.add_theme_font_override(&"font", key.font if key.font else font)
			text_generator.add_theme_color_override(&"font_color", key.font_color if key.font_color.a > 0 else font_color)
			
			images.append(await generate_key(key))
		
		return images
	
	func generate_key(mapping: KeyMapping) -> Image:
		base_generator.texture = mapping.base
		text_generator.text = mapping.text
		text_generator.position = mapping.text_offset
		text_generator.size = viewport.size
		overlay_generator.texture = mapping.image
		
		return await viewport.print_image()

class MouseBlueprint extends Blueprint:
	func _init() -> void:
		type = Type.MOUSE

class JoypadBlueprint extends Blueprint:
	func _init() -> void:
		type = Type.JOYPAD
