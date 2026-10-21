class_name ObjectiveArrow
extends Node2D
## Flèche au sol autour du personnage contrôlé, qui pointe vers l'objectif.
## `target = Vector2.INF` la masque ; elle s'efface aussi près du but.

var target := Vector2.INF
var follow: Node2D
var _t := 0.0


func _ready() -> void:
	z_index = 20
	z_as_relative = false


func _process(delta: float) -> void:
	_t += delta
	if is_instance_valid(follow):
		global_position = follow.global_position
	queue_redraw()


func _draw() -> void:
	if target == Vector2.INF:
		return
	var to := target - global_position
	var d := to.length()
	if d < 170.0:
		return
	var dir := to / d
	var r := 52.0 + sin(_t * 4.0) * 4.0
	var tip := dir * r + Vector2(0, -8)
	var base := tip - dir * 20.0
	var side := Vector2(-dir.y, dir.x) * 7.0
	var tail := base - dir * 14.0
	var col := Color(1.0, 0.8, 0.3, 0.95)
	var dark := Color(0.2, 0.12, 0.05, 0.9)
	draw_line(tail, base, dark, 6.0, true)
	draw_line(tail, base, col, 3.5, true)
	draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), col)
	draw_polyline(PackedVector2Array([tip, base + side, base - side, tip]), dark, 1.5, true)
