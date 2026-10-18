class_name ResourceNode
extends Node2D
## Point de récolte (GDD 9). Les survivants assignés font des allers-retours
## entre ce point et le centre du village. Instances : la mare (eau) et le
## bosquet de cocotiers (nourriture). Le visuel est un placeholder dessiné en code.

enum Visual { MARE, COCOTIERS }

@export var display_name: String = "Mare"
@export var resource_type: String = "eau"
## Secondes passées à récolter avant de repartir.
@export var gather_time: float = 2.0
## Demi-largeur de la mare (l'ellipse fait 2 × radius sur 1 × radius).
@export var radius: float = 46.0
@export var visual: Visual = Visual.MARE

var hovered := false
var _t := 0.0
var _label: Label


func _ready() -> void:
	add_to_group("resource_nodes")
	z_index = -5  # au sol, sous les personnages
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("outline_size", 3)
	var label_y := -radius * 0.5 - (95.0 if visual == Visual.COCOTIERS else 30.0)
	_label.position = Vector2(-90, label_y)
	_label.size = Vector2(180, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


## Point du bord de la mare où un survivant vient puiser (angle propre à chacun).
func gather_point(angle: float) -> Vector2:
	return global_position + Vector2(cos(angle), sin(angle) * 0.5) * (radius + 6.0)


## Vrai si le point (monde) est sur la mare.
func contains(world_pos: Vector2) -> bool:
	var d := world_pos - global_position
	return (d.x * d.x) / (radius * radius) + (d.y * d.y) / (radius * radius * 0.25) <= 1.3


func assigned_count() -> int:
	var n := 0
	for s in get_tree().get_nodes_in_group("survivors"):
		if s.task_node == self:
			n += 1
	return n


func _process(delta: float) -> void:
	_t += delta
	hovered = contains(get_global_mouse_position())
	var n := assigned_count()
	_label.text = "%s%s" % [display_name, "  ·  %d assigné%s" % [n, "s" if n > 1 else ""] if n > 0 else ""]
	if hovered:
		_label.text += "\nClic droit : assigner le survivant contrôlé"
	queue_redraw()


func _draw() -> void:
	match visual:
		Visual.COCOTIERS:
			_draw_coconut_grove()
		_:
			_draw_pond()
	if hovered:
		_ellipse_outline(Vector2.ZERO, radius + 10, radius * 0.5 + 7, Color(1, 1, 1, 0.8), 2.0)


## Bosquet de cocotiers (nourriture) : trois palmiers sur un îlot de sable.
func _draw_coconut_grove() -> void:
	var rx := radius
	var ry := radius * 0.5
	_ellipse(Vector2(0, 2), rx + 6, ry + 4, Color(0.80, 0.70, 0.46))
	_ellipse(Vector2.ZERO, rx, ry, Color(0.88, 0.79, 0.55))
	var palms := [Vector2(-rx * 0.45, ry * 0.15), Vector2(rx * 0.35, -ry * 0.35), Vector2(rx * 0.5, ry * 0.45)]
	var heights := [62.0, 72.0, 54.0]
	var bends := [-14.0, 10.0, 18.0]
	for i in palms.size():
		var base: Vector2 = palms[i]
		var h: float = heights[i]
		var sway := sin(_t * 0.8 + i * 1.7) * 2.5
		var top := base + Vector2(bends[i] + sway, -h)
		# Ombre et tronc courbe en segments
		_ellipse(base + Vector2(6, 2), 12, 5, Color(0, 0, 0, 0.18))
		var prev := base
		for k in range(1, 7):
			var f := k / 6.0
			var p := base.lerp(top, f) + Vector2(sin(f * PI) * bends[i] * 0.35, 0)
			draw_line(prev, p, Color(0.45, 0.32, 0.2), 5.0 - f * 2.0)
			draw_line(prev + Vector2(-2, 0), prev + Vector2(2, 0), Color(0.35, 0.24, 0.15), 1.0)
			prev = p
		# Palmes
		for j in 6:
			var a := -PI / 2.0 + (j - 2.5) * 0.55 + sway * 0.02
			var tip := top + Vector2(cos(a) * 26.0, sin(a) * 14.0 + 10.0)
			var mid := top + Vector2(cos(a) * 14.0, sin(a) * 9.0 - 3.0)
			draw_polyline(PackedVector2Array([top, mid, tip]), Color(0.22, 0.5, 0.22), 4.0, true)
			draw_polyline(PackedVector2Array([top, mid, tip]), Color(0.32, 0.62, 0.28), 1.5, true)
		# Noix de coco
		for c in [Vector2(-3, 3), Vector2(3, 4), Vector2(0, 7)]:
			draw_circle(top + c, 3.2, Color(0.4, 0.27, 0.14))
	# Quelques noix tombées au sol
	for c in [Vector2(-6, ry * 0.6), Vector2(rx * 0.1, ry * 0.7), Vector2(-rx * 0.7, ry * 0.4)]:
		draw_circle(c, 3.0, Color(0.4, 0.27, 0.14))


## Mare (eau) : berge, eau animée, roseaux.
func _draw_pond() -> void:
	var rx := radius
	var ry := radius * 0.5
	# Berge
	_ellipse(Vector2(0, 2), rx + 8, ry + 5, Color(0.42, 0.36, 0.24))
	# Eau
	_ellipse(Vector2.ZERO, rx, ry, Color(0.18, 0.38, 0.5))
	_ellipse(Vector2(0, -2), rx * 0.82, ry * 0.75, Color(0.24, 0.48, 0.6))
	# Rides animées
	for i in 3:
		var k := fmod(_t * 0.4 + i / 3.0, 1.0)
		var col := Color(0.75, 0.88, 0.95, 0.5 * (1.0 - k))
		_ellipse_outline(Vector2(rx * 0.15, 0), rx * 0.2 + k * rx * 0.5, (ry * 0.2 + k * ry * 0.5), col)
	# Roseaux
	for p: Vector2 in [Vector2(-rx * 0.9, -ry * 0.2), Vector2(-rx * 0.8, ry * 0.3), Vector2(rx * 0.85, -ry * 0.4)]:
		for j in 3:
			var top: Vector2 = p + Vector2((j - 1) * 3 + sin(_t * 1.5 + j) * 1.5, -16 - j * 3)
			draw_line(p + Vector2((j - 1) * 2, 0), top, Color(0.3, 0.45, 0.2), 2.0)
		draw_rect(Rect2(p + Vector2(-1.5, -24), Vector2(3, 7)), Color(0.45, 0.3, 0.18))


func _ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	draw_circle(Vector2.ZERO, rx, col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _ellipse_outline(c: Vector2, rx: float, ry: float, col: Color, w := 1.5) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(pts, col, w, true)
