## Allows to display custom actions with ActionIcon.
##
## To use it, add a script called [code]CustomActions.gd[/code] to your icon set and have it extend this script.
@tool
class_name ActionIconCustomActions extends RefCounted

var _action_list: Dictionary[StringName, Callable]
var _viewport: SubViewport

func _init() -> void:
	_create_icon_cache.call_deferred()
	_initialize()

## Called when the custom actions script is created. Use it to register actions.
func _initialize():
	pass

## Called after initialization or when [method ActionIcon.reload_custom_actions] is called. Use it to create dynamic icons.
func _create_icon_cache():
	pass

## Registers a custom action. When you use that action in [member ActionIcon.action_name], the provided [param callback] will be called to set the texture.
func register_action(action: StringName, callback: Callable):
	assert(not action in _action_list, "Custom action \"%s\" already exists.")
	_action_list[action] = callback

func _get_texture(action_name: String, action_icon: ActionIcon, device: ActionIcon.Device) -> Texture2D:
	var callable = _action_list.get(action_name)
	if callable:
		var texture: Texture2D = callable.call(action_icon, device)
		return texture
	
	return null

func prepare_icon_bake() -> SubViewport:
	_viewport = SubViewport.new()
	_viewport.size = ActionIcon._base_size
	_viewport.transparent_bg = true
	Engine.get_main_loop().root.add_child(_viewport)
	return _viewport

func bake_icon() -> Texture2D:
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	await RenderingServer.frame_post_draw
	
	var image := _viewport.get_texture().get_image()
	_viewport.queue_free()
	_viewport = null
	
	return ImageTexture.create_from_image(image)

func _has_action(action: StringName) -> bool:
	return action in _action_list
