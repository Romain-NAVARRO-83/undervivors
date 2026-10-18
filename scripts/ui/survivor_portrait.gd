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
## Badge d'assignation : "eau", "nourriture", "bois" ou "" (aucune tâche).
var task_badge := "":
	set(value):
		if value != task_badge:
			task_badge = value
			queue_redraw()
## Récolte en pause (stock plein) : badge grisé.
var badge_paused := false:
	set(value):
		if value != badge_paused:
			badge_paused = value
			queue_redraw()


## Met à jour vignette et badge depuis un survivant.
func show_survivor(s: Survivor) -> void:
	appearance = s.appearance
	is_hero = s.is_hero
	task_badge = s.task_node.resource_type if s.task_node else ""
	badge_paused = s.work_paused


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
	if task_badge != "":
		_draw_badge(Vector2(size.x - s * 0.18, size.y - s * 0.18), s * 0.17)


## Petite icône d'assignation dans le coin : goutte (eau) ou noix de coco (nourriture).
func _draw_badge(p: Vector2, r: float) -> void:
	var a := 0.45 if badge_paused else 1.0
	draw_circle(p, r + 1.5, Color(0.08, 0.07, 0.06, a))
	draw_circle(p, r, Color(0.95, 0.92, 0.85, a))
	if task_badge == "eau":
		var blue := Color(0.25, 0.55, 0.9, a)
		draw_circle(p + Vector2(0, r * 0.22), r * 0.45, blue)
		draw_colored_polygon(PackedVector2Array([p + Vector2(-r * 0.4, r * 0.1), p + Vector2(r * 0.4, r * 0.1), p + Vector2(0, -r * 0.65)]), blue)
	elif task_badge == "bois":
		# Bûche vue de biais : corps + cerne
		draw_rect(Rect2(p + Vector2(-r * 0.55, -r * 0.22), Vector2(r * 1.0, r * 0.44)), Color(0.5, 0.33, 0.18, a))
		draw_circle(p + Vector2(r * 0.45, 0), r * 0.24, Color(0.82, 0.66, 0.42, a))
		draw_circle(p + Vector2(r * 0.45, 0), r * 0.1, Color(0.55, 0.38, 0.2, a))
	else:
		draw_circle(p + Vector2(0, r * 0.15), r * 0.5, Color(0.45, 0.3, 0.16, a))
		draw_line(p + Vector2(0, -r * 0.3), p + Vector2(r * 0.45, -r * 0.7), Color(0.3, 0.6, 0.25, a), maxf(1.5, r * 0.22))
	if badge_paused:
		draw_line(p + Vector2(-r * 0.7, r * 0.7), p + Vector2(r * 0.7, -r * 0.7), Color(0.75, 0.2, 0.2, 0.9), maxf(1.5, r * 0.2))
