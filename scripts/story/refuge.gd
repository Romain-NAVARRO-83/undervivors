class_name Refuge
extends Node2D
## Refuge du prologue : une clairière de terre battue, un abri de branches
## et un feu de camp. Ce sera le premier camp (centre du village).

const RADIUS := 120.0
var _t := 0.0
var lit := false   # le feu s'allume quand on arrive


func _ready() -> void:
	z_index = -5   # au sol, sous les personnages


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Clairière (place du camp)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, RADIUS * 2.2, Color(0.55, 0.45, 0.3, 0.55))
	draw_circle(Vector2.ZERO, RADIUS * 1.6, Color(0.55, 0.45, 0.3, 0.85))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Abri : appentis de branches et de palmes, au nord du feu
	var a := Vector2(-70, -60)
	var wood := Color(0.42, 0.3, 0.18)
	draw_colored_polygon(PackedVector2Array([a + Vector2(-40, 10), a + Vector2(10, -38), a + Vector2(60, 10)]), Color(0.3, 0.45, 0.22))
	for k in 6:
		var x := -36.0 + k * 16.0
		draw_line(a + Vector2(x, 10), a + Vector2(10 + x * 0.15, -36), Color(0.22, 0.35, 0.16), 2.0)
	draw_line(a + Vector2(-40, 10), a + Vector2(10, -38), wood, 3.0)
	draw_line(a + Vector2(10, -38), a + Vector2(60, 10), wood, 3.0)
	# Pierres du foyer
	for k in 8:
		var ang := TAU * k / 8.0
		draw_circle(Vector2(cos(ang) * 13.0, sin(ang) * 6.5), 3.5, Color(0.45, 0.43, 0.4))
	# Bûches
	draw_line(Vector2(-9, 3), Vector2(9, -3), Color(0.35, 0.22, 0.12), 4.0)
	draw_line(Vector2(-9, -3), Vector2(9, 3), Color(0.3, 0.2, 0.1), 4.0)
	if lit:
		var f := 1.0 + sin(_t * 12.0) * 0.12
		draw_circle(Vector2(0, -6), 9.0 * f, Color(1.0, 0.45, 0.1, 0.35))
		draw_colored_polygon(PackedVector2Array([Vector2(-7, 0), Vector2(0, -20 * f), Vector2(7, 0)]), Color(1.0, 0.55, 0.15))
		draw_colored_polygon(PackedVector2Array([Vector2(-4, 0), Vector2(0, -12 * f), Vector2(4, 0)]), Color(1.0, 0.9, 0.4))
	else:
		# Braises et filet de fumée
		draw_circle(Vector2(0, -2), 3.0, Color(0.8, 0.3, 0.1, 0.6 + 0.3 * sin(_t * 3.0)))
		for i in 3:
			var g := fmod(_t * 0.4 + i / 3.0, 1.0)
			draw_circle(Vector2(sin(_t + i) * 3.0, -8 - g * 40.0), 3.0 + g * 6.0, Color(0.5, 0.5, 0.5, 0.35 * (1.0 - g)))
