class_name ActionIconCustomActions extends RefCounted

var action_list: Dictionary[StringName, Callable]
var viewport: SubViewport

func _init() -> void:
	_create_icon_cache.call_deferred()
	_initialize()

func _initialize():
	pass

func _create_icon_cache():
	pass

func register_action(action: StringName, callback: Callable):
	action_list[action] = callback

func has_action(action: StringName) -> bool:
	return action in action_list

func get_texture(action_name: String, action_icon: ActionIcon, device: ActionIcon.Device) -> Texture2D:
	var callable = action_list.get(action_name)
	if callable:
		var texture: Texture2D = callable.call(action_icon, device)
		return texture
	
	return null

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
