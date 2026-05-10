class_name ActionIconCustomActions extends RefCounted

var action_list: Dictionary
var viewport: SubViewport

func _init() -> void:
	_create_icon_cache.call_deferred()
	_initialize()

func _initialize():
	pass

func _create_icon_cache():
	pass

func register_action(action: String, callback: Callable):
	action_list[action] = callback

func get_texture(action_name: String, action_icon: ActionIcon, is_joypad: bool) -> Texture2D:
	var callable = action_list.get(action_name)
	if callable:
		var texture: Texture2D = await callable.call(action_icon, is_joypad)
		return texture
	
	return null

func has_action(action_name: String) -> bool:
	return action_name in action_list

func prepare_icon_bake():
	if viewport:
		finish_bake()
	
	viewport = SubViewport.new()
	viewport.size = ActionIcon._base_size
	viewport.transparent_bg = true
	Engine.get_main_loop().root.add_child(viewport)

func bake_icon() -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func finish_bake():
	viewport.free()
	viewport = null
