@tool
extends "ExtendedEditorPlugin.gd"

const Generator = preload("uid://bjxkwdwy770bi")
var generator: Generator

func _enter_tree() -> void:
	generator = preload("uid://dymwlqo6l32a5").instantiate()
	add_child(generator)
	
	add_tool_menu_item("ActionIcon: Generate Icon Set", generator.show)
	EditorInterface.get_command_palette().add_command("ActionIcon: Generate Icon Set", "action_icon/generate_icon_set", generator.show)
	
	define_project_setting(ActionIcon._ACTION_SET_DIR, "res://ActionIconSet", PROPERTY_HINT_DIR)

func _exit_tree() -> void:
	generator.queue_free()
	remove_tool_menu_item("ActionIcon: Generate Icon Set")
	EditorInterface.get_command_palette().remove_command("action_icon/generate_icon_set")
