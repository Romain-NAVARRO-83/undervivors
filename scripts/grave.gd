class_name Grave
extends Node2D
## Tombe laissée là où un survivant est mort (mort définitive, GDD 5.5).
## Une petite croix en bois et une pierre ; le nom s'affiche quelques secondes
## puis s'efface, la tombe reste.

const NAME_TIME := 8.0

var dead_name := ""
var _t := 0.0


func _ready() -> void:
	add_to_group("graves")
	var label := Label.new()
	label.text = "R.I.P.\n" + dead_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 3)
	label.size = Vector2(140, 30)
	label.position = Vector2(-70, -58)
	label.z_index = 20
	add_child(label)
	var tw := label.create_tween()
	tw.tween_interval(NAME_TIME)
	tw.tween_property(label, "modulate:a", 0.0, 1.5)
	tw.tween_callback(label.queue_free)
	# Petite apparition
	scale = Vector2(1.0, 0.1)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)


func _draw() -> void:
	# Tertre de terre
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 13.0, Color(0.36, 0.25, 0.16))
	draw_circle(Vector2(-2, -1), 9.0, Color(0.44, 0.31, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Croix de bois de travers (humour noir oblige)
	draw_set_transform(Vector2(1, -2), -0.12, Vector2.ONE)
	var wood := Color(0.55, 0.38, 0.22)
	var dark := Color(0.3, 0.2, 0.12)
	draw_rect(Rect2(-2, -24, 4, 24), dark)
	draw_rect(Rect2(-1.5, -24, 3, 23), wood)
	draw_rect(Rect2(-8, -18, 16, 4), dark)
	draw_rect(Rect2(-7.5, -17.5, 15, 3), wood)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
