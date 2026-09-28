class_name InputGlyphs
extends RefCounted
## Key/button labels for prompts, read from the InputMap for the last-used device.
## The exploration HUD updates `using_pad` from raw input; every prompt reads `label()`.

# ponytail: Xbox face-button labels; add PlayStation/Switch glyphs when we detect the pad type.
const PAD_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_START: "Start",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_DPAD_UP: "Up", JOY_BUTTON_DPAD_DOWN: "Down"}

static var using_pad := false


static func track(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		using_pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		using_pad = false


static func label(action: StringName) -> String:
	for ev in InputMap.action_get_events(action):
		if using_pad and ev is InputEventJoypadButton:
			return PAD_NAMES.get(ev.button_index, "Pad %d" % ev.button_index)
		if not using_pad and ev is InputEventKey:
			# Headless display servers cannot translate physical keys into the active
			# keyboard layout. The configured physical label is still useful in tests.
			if DisplayServer.get_name() == "headless":
				return OS.get_keycode_string(ev.physical_keycode)
			return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(ev.physical_keycode))
	return "?"
