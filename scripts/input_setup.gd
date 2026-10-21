class_name InputSetup
extends RefCounted
## Touches du jeu, partagées par le mode histoire et le mode test.
## Touches physiques : WASD en QWERTY = ZQSD en AZERTY.

const MAP := {
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"next_survivor": [KEY_TAB],
	"deselect": [KEY_ESCAPE],
	"toggle_panel": [KEY_G],
	"toggle_loot": [KEY_I],
	"toggle_squad": [KEY_F],
	"cycle_formation": [KEY_V],
	"debug_needs": [KEY_F10],
	"toggle_debug": [KEY_F1],
	"toggle_build": [KEY_B],
	"toggle_alert": [KEY_H],
}


static func register() -> void:
	for action in MAP:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in MAP[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", mb)
