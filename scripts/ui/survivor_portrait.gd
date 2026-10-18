class_name SurvivorPortrait
extends Control
## Vignette d'un survivant : buste + visage issu de son apparence.

var appearance: SurvivorAppearance:
	set(value):
		appearance = value
		queue_redraw()
var is_hero := false:
	set(value):
		is_hero = value
		queue_redraw()


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	draw_circle(c, s * 0.5, Color(0.24, 0.21, 0.18))
	if appearance == null:
		return
	var r := s * 0.26
	# Buste
	draw_circle(c + Vector2(0, s * 0.52), s * 0.34, appearance.shirt_color)
	draw_rect(Rect2(c.x - r * 0.3, c.y + r * 0.6, r * 0.6, r * 0.6), appearance.skin)
	SurvivorAppearance.draw_face(self, c + Vector2(0, -s * 0.04), r, appearance, true)
	# Contour (doré pour les héros)
	var ring := UIStyle.ACCENT if is_hero else UIStyle.BORDER
	draw_arc(c, s * 0.5 - 1.5, 0.0, TAU, 40, ring, 3.0, true)
