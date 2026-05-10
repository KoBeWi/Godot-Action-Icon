extends "res://addons/ActionIcon/BaseCustomActions.gd"

var move_icon_cache: Texture2D
var look_icon_cache: Texture2D
var empty: ImageTexture

func _initialize():
	register_action(&"move", move_icon)

func _create_icon_cache():
	empty = ImageTexture.new()
	
	prepare_icon_bake()
	
	add_key_to_viewport(&"up", Vector2(1, 0))
	add_key_to_viewport(&"down", Vector2(1, 1))
	add_key_to_viewport(&"left", Vector2(0, 1))
	add_key_to_viewport(&"right", Vector2(2, 1))
	
	var image := await bake_icon()
	move_icon_cache = ImageTexture.create_from_image(image)
	
	prepare_icon_bake()
	
	add_key_to_viewport(&"look_up", Vector2(1, 0))
	add_key_to_viewport(&"look_down", Vector2(1, 1))
	add_key_to_viewport(&"look_left", Vector2(0, 1))
	add_key_to_viewport(&"look_right", Vector2(2, 1))
	
	image = await bake_icon()
	look_icon_cache = ImageTexture.create_from_image(image)
	
	finish_bake()

func move_icon(action_icon: ActionIcon, device: ActionIcon.Device) -> Texture2D:
	if device == ActionIcon.Device.JOYPAD:
		return action_icon._get_joypad_axis(JOY_AXIS_LEFT_X, 0, 0)
	return move_icon_cache

func get_action_key(action: StringName) -> Texture2D:
	for event in ActionIcon._action_get_events(action):
		if event is InputEventKey:
			return ActionIcon._get_keyboard(event.keycode)
	return null

func add_key_to_viewport(action: StringName, offset: Vector2i):
	var texture := get_action_key(action)
	
	const unit = 100.0 / 3.0
	const unit_size = (100.0 / 75.0) * unit
	
	var displayer := TextureRect.new()
	displayer.texture = texture
	displayer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	displayer.position = offset * unit - Vector2.ONE * (unit_size - unit) * 0.5 + Vector2.DOWN * unit * 0.5
	displayer.size = Vector2.ONE * unit_size
	viewport.add_child(displayer)
