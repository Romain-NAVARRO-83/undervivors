class_name Wreck
extends Node2D
## Débris de l'accident, échoués sur la plage (placeholder). Personne ne sait
## de quoi il s'agit : des tôles tordues, un siège, une valise, une fumée.
## `kind` choisit la pièce ; seul le gros morceau fume.

enum Kind { HULL, SEAT, SUITCASE, PANEL }

@export var kind: Kind = Kind.HULL
var _t := 0.0


func _ready() -> void:
	add_to_group("wreck")
	_t = randf() * 5.0


func _process(delta: float) -> void:
	_t += delta
	if kind == Kind.HULL:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 28.0 if kind == Kind.HULL else 14.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var metal := Color(0.62, 0.64, 0.66)
	var dark := Color(0.25, 0.26, 0.28)
	match kind:
		Kind.HULL:
			# Grande tôle courbe, à moitié enfouie, avec des hublots ronds
			var body := PackedVector2Array([Vector2(-42, 4), Vector2(-38, -22), Vector2(-14, -34), Vector2(22, -30), Vector2(44, -10), Vector2(40, 6)])
			draw_colored_polygon(body, metal)
			draw_colored_polygon(PackedVector2Array([Vector2(-42, 4), Vector2(-38, -22), Vector2(-30, -12), Vector2(-28, 6)]), metal.darkened(0.25))
			draw_polyline(body + PackedVector2Array([body[0]]), dark, 2.0, true)
			for k in 3:
				var c := Vector2(-16 + k * 16, -16)
				draw_circle(c, 4.5, dark)
				draw_circle(c, 3.0, Color(0.15, 0.2, 0.25))
			# Déchirure dentelée
			draw_polyline(PackedVector2Array([Vector2(36, -12), Vector2(30, -6), Vector2(38, -2), Vector2(31, 4)]), dark, 2.0)
			# Inscription effacée, illisible
			draw_line(Vector2(-6, -28), Vector2(14, -27), Color(0.75, 0.2, 0.15, 0.6), 2.0)
			# Fumée
			for i in 5:
				var f := fmod(_t * 0.35 + i / 5.0, 1.0)
				var p := Vector2(20 + sin(_t * 0.8 + i) * 6.0 + f * 18.0, -34 - f * 80.0)
				draw_circle(p, 6.0 + f * 12.0, Color(0.35, 0.35, 0.37, 0.45 * (1.0 - f)))
		Kind.SEAT:
			# Siège renversé, accoudoir tordu
			draw_rect(Rect2(-12, -14, 22, 12), Color(0.3, 0.32, 0.45))
			draw_rect(Rect2(-14, -26, 10, 22), Color(0.26, 0.28, 0.4))
			draw_line(Vector2(10, -12), Vector2(16, -20), dark, 2.0)
			draw_line(Vector2(-10, -2), Vector2(-10, 4), dark, 2.0)
			draw_line(Vector2(6, -2), Vector2(8, 4), dark, 2.0)
		Kind.SUITCASE:
			# Valise ouverte, quelques affaires éparpillées
			draw_rect(Rect2(-14, -10, 26, 12), Color(0.45, 0.25, 0.18))
			draw_colored_polygon(PackedVector2Array([Vector2(-14, -10), Vector2(-10, -24), Vector2(16, -24), Vector2(12, -10)]), Color(0.52, 0.3, 0.2))
			draw_rect(Rect2(-8, -8, 8, 4), Color(0.85, 0.82, 0.7))
			draw_rect(Rect2(18, -2, 9, 4), Color(0.7, 0.3, 0.35))
			draw_circle(Vector2(-22, 0), 3.0, Color(0.9, 0.85, 0.3))
		Kind.PANEL:
			# Plaque de métal plantée dans le sable
			draw_colored_polygon(PackedVector2Array([Vector2(-10, 2), Vector2(-6, -24), Vector2(12, -20), Vector2(10, 4)]), metal.darkened(0.1))
			draw_polyline(PackedVector2Array([Vector2(-10, 2), Vector2(-6, -24), Vector2(12, -20), Vector2(10, 4)]), dark, 1.5)
			for k in 3:
				draw_circle(Vector2(-4 + k * 6, -18 + k * 1.0), 1.2, dark)
