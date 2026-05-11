## Allows to display custom actions with ActionIcon.
##
## To use it, add a script called [code]CustomActions.gd[/code] to your icon set and have it extend this script.
@tool
class_name ActionIconCustomActions extends RefCounted

var _action_list: Dictionary[StringName, Callable]
var _viewport: SubViewport

func _init() -> void:
	_initialize()
	_create_icon_cache()

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

## Prepares a [SubViewport] for creating dynamic icons. Put some images into the returned viewport and call [method bake_icon] to get the resulting [Texture2D].
func prepare_icon_bake() -> SubViewport:
	assert(not _viewport, "The previous bake hasn't finished. Call bake_icon() first.")
	
	_viewport = SubViewport.new()
	_viewport.size = ActionIcon._base_size
	_viewport.transparent_bg = true
	Engine.get_main_loop().root.add_child(_viewport)
	return _viewport

## Creates a custom icon using the texture from the viewport created in [method prepare_icon_bake]. Note that the icon is empty at first, initialized in the next frame.
func bake_icon() -> Texture2D:
	assert(_viewport, "Viewport not prepared. Call prepare_icon_bake() first.")
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	var texture := ImageTexture.new()
	var viewport := _viewport
	
	var finish_bake := func():
		texture.set_image(viewport.get_texture().get_image())
		viewport.queue_free()
	
	RenderingServer.frame_post_draw.connect(finish_bake, CONNECT_ONE_SHOT)
	
	_viewport = null
	return texture

func _get_texture(action_name: String, action_icon: ActionIcon, device: ActionIcon.Device) -> Texture2D:
	var callable = _action_list.get(action_name)
	if callable:
		var texture: Texture2D = callable.call(action_icon, device)
		return texture
	
	return null

func _has_action(action: StringName) -> bool:
	return action in _action_list
