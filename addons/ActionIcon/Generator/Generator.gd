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
		if is_part_of_edited_scene():
			return
		
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
				
				for texname in config.get_section_keys("keys"):
					var texture: Texture2D = load(full_dir.path_join(texname))
					
					var mapping_data: Dictionary = config.get_value("keys", texname)
					for mapping_name: String in mapping_data:
						var mapping := KeyboardBlueprint.KeyMapping.new()
						mapping.base = texture
						
						var mapping_value: Variant = mapping_data[mapping_name]
						if mapping_value is int:
							mapping.text = mapping_name
						elif mapping_value is String:
							mapping.text = mapping_value
						elif mapping_value is Dictionary:
							mapping.text = mapping_value.get("text", "")
							mapping.text_offset = mapping_value.get("text_offset", Vector2())
							mapping.font_size = mapping_value.get("font_size", 0)
							
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
	for blueprint in blueprint_list:
		if blueprint is not KeyboardBlueprint:
			continue
		
		blueprint.viewport = viewport
		blueprint.base_generator = base_generator
		blueprint.text_generator = text_generator
		blueprint.overlay_generator = overlay_generator
		
		var images := await blueprint.generate()
		
		var sheet := Image.create_empty(viewport.size.x * mini(images.size(), 10), viewport.size.y * (images.size() / 10 + 1), false, Image.FORMAT_RGBA8)
		
		for i in images.size():
			var image := images[i]
			sheet.blit_rect(image, Rect2(Vector2i(), image.get_size()), Vector2i(i % 10 * viewport.size.x, i / 10 * viewport.size.y))
		
		sheet.save_png("res://Test/sheet.png")

class Blueprint:
	enum Type { KEYBOARD, MOUSE, JOYPAD }
	
	var name: String
	var type: Type
	
	var viewport: SubViewport
	var base_generator: TextureRect
	var text_generator: Label
	var overlay_generator: TextureRect
	
	func generate() -> Array[Image]:
		return []

class KeyboardBlueprint extends Blueprint:
	class KeyMapping:
		var base: Texture2D
		var text: String
		var text_offset: Vector2
		var font_size: int
		var image: Texture2D
	
	var font: Font
	var font_color: Color
	var font_size: int
	var mappings: Array[KeyMapping]
	
	func _init() -> void:
		type = Type.KEYBOARD
	
	func generate() -> Array[Image]:
		var images: Array[Image]
		
		text_generator.add_theme_font_override(&"font", font)
		text_generator.add_theme_color_override(&"font_color", font_color)
		
		for key in mappings:
			var fs := key.font_size if key.font_size != 0 else font_size
			text_generator.add_theme_font_size_override(&"font_size", fs)
			
			images.append(await generate_key(key))
		
		return images
	
	func generate_key(mapping: KeyMapping) -> Image:
		base_generator.texture = mapping.base
		text_generator.text = mapping.text
		text_generator.position = mapping.text_offset
		text_generator.size = viewport.size
		overlay_generator.texture = mapping.image
		
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		return viewport.get_texture().get_image()

class MouseBlueprint extends Blueprint:
	func _init() -> void:
		type = Type.MOUSE

class JoypadBlueprint extends Blueprint:
	func _init() -> void:
		type = Type.JOYPAD
