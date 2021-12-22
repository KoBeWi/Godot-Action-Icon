# <img src="https://github.com/KoBeWi/Godot-Action-Icon/blob/master/Media/Icon.png" width="64" height="64"> Godot Action Icon

Action Icon is a TextureRect based GUI node that you can put on a scene and it will display the associated action.

![](https://github.com/KoBeWi/Godot-Action-Icon/blob/master/Media/Screenshot1.png)

It has a couple of display modes to configure:

- Action Name: the name of the action from project's Input Map
- Joypad Mode: whether the action should display keyboard key or joypad button. If set to "Adaptive", the icon will automatically change when it detects keyboard or joypad input. Only relevant to actions that have both assigned.

![](https://github.com/KoBeWi/Godot-Action-Icon/blob/master/Media/ReadmeActions.gif)

You can define a custom action, by going to `AutoAction.gd` script and editing the `CUSTOM_ACTIONS` constant. By default there is a "move" action that displays WSAD/Left Stick.

- Favor Mouse: if an action has a keyboard and mouse button configured, `favor_mouse` set to true will display the mouse button
- Fit Mode: Node = the icon will use whatever size you set. Match Width = the icon minimum width will match its height. Useful e.g. inside HBoxContainer. Match Height = same, but matches height to width.

![](https://github.com/KoBeWi/Godot-Action-Icon/blob/master/Media/ReadmeSize.gif)

If you change your input mappings in-game, you can use `get_tree().call_group("input_actions", "refresh")` to refresh all visible icons to match the newly assigned input.

You can customize the appearance of buttons by going to 'addons/ActionIcon` and relevant button folders. By default the Action Icon comes with keyboad, mouse and XBox buttons from [xelu's CC0 input icons pack](https://opengameart.org/content/free-keyboard-and-controllers-prompts-pack).
