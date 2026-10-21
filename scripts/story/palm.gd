class_name Palm
extends Node2D
## Palmier décoratif (placeholder), qui se balance doucement.

var height := 70.0
var lean := 0.25
var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var sway := sin(_t * 0.9) * 3.0
	var top := Vector2(height * lean + sway, -height)
	var mid := Vector2(height * lean * 0.25, -height * 0.55)
	var trunk := PackedVector2Array()
	for i in 9:
		var f := i / 8.0
		trunk.append(Vector2.ZERO.lerp(mid, f).lerp(mid.lerp(top, f), f))
	draw_polyline(trunk, Color(0.45, 0.33, 0.2), 6.0, true)
	for i in range(1, 8):
		draw_circle(trunk[i], 1.5, Color(0.35, 0.25, 0.15))
	# Palmes
	var leaf := Color(0.25, 0.55, 0.25)
	for k in 6:
		var a := -PI / 2.0 + (k - 2.5) * 0.62 + sin(_t * 1.3 + k) * 0.05
		var tip := top + Vector2(cos(a), sin(a) * 0.55 + 0.55) * 34.0
		var ctrl := top + Vector2(cos(a), sin(a) * 0.55) * 20.0 + Vector2(0, -8)
		var pts := PackedVector2Array()
		for i in 7:
			var f := i / 6.0
			pts.append(top.lerp(ctrl, f).lerp(ctrl.lerp(tip, f), f))
		draw_polyline(pts, leaf.darkened(0.1 * (k % 2)), 5.0, true)
	draw_circle(top + Vector2(-3, 4), 3.5, Color(0.45, 0.32, 0.18))
	draw_circle(top + Vector2(3, 5), 3.5, Color(0.42, 0.3, 0.16))
