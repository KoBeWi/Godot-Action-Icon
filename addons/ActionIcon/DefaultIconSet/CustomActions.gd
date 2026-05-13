@tool
extends ActionIconCustomActions

var move_icon_cache: Texture2D

func _initialize():
	register_action(&"move", get_move_icon)

func _create_icon_cache():
	# Create a viewport.
	var viewport := prepare_icon_bake()
	# Prepare the texture. add_key_to_viewport() is a helper that puts images into a nice grid.
	# Replace ui_ actions with your actual direction actions.
	add_key_to_viewport(viewport, &"ui_up", Vector2(1, 0))
	add_key_to_viewport(viewport, &"ui_down", Vector2(1, 1))
	add_key_to_viewport(viewport, &"ui_left", Vector2(0, 1))
	add_key_to_viewport(viewport, &"ui_right", Vector2(2, 1))
	# Finalize the texture.
	move_icon_cache = bake_icon()

func get_move_icon(action_icon: ActionIcon, device: ActionIcon.Device) -> Texture2D:
	if device == ActionIcon.Device.JOYPAD:
		return action_icon.get_icon("LeftStick", device)
	return move_icon_cache

func add_key_to_viewport(viewport: SubViewport, action: StringName, offset: Vector2i):
	var keycode: int
	for event in ActionIcon.action_get_events(action):
		if event is InputEventKey:
			keycode = event.keycode
			break
	
	var texture := ActionIcon.get_icon_static(keycode, ActionIcon.Device.KEYBOARD)
	
	const unit = 100.0 / 3.0
	const unit_size = (100.0 / 75.0) * unit
	
	var displayer := TextureRect.new()
	displayer.texture = texture
	displayer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	displayer.position = offset * unit - Vector2.ONE * (unit_size - unit) * 0.5 + Vector2.DOWN * unit * 0.5
	displayer.size = Vector2.ONE * unit_size
	viewport.add_child(displayer)
