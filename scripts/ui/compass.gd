class_name Compass
extends Control
## Cardinal-only compass strip following the camera heading. No quest markers by design.

const CARDINALS := {0: "N", 90: "E", 180: "S", 270: "W"}
const INK := Color(0.95, 0.89, 0.78)

var rig: Node3D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if not rig:
		return
	var heading := -rad_to_deg(rig.rotation.y) # 0 = north (-Z), 90 = east (+X)
	var font := get_theme_default_font()
	var half := size.x * 0.5
	for bearing in range(0, 360, 45):
		var rel := wrapf(bearing - heading, -180.0, 180.0)
		if absf(rel) > 90.0:
			continue
		var x := roundf(half + rel / 90.0 * half)
		var ink := Color(INK, 1.0 - absf(rel) / 90.0)
		if CARDINALS.has(bearing):
			draw_string(font, Vector2(x - 8, size.y - 1), CARDINALS[bearing], HORIZONTAL_ALIGNMENT_CENTER, 16, 8, ink)
		else:
			draw_rect(Rect2(x, size.y - 5, 1, 2), Color(ink, ink.a * 0.6))
