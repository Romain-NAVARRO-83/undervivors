class_name TrainingDummy
extends StaticBody2D
## Mannequin du champ de tir : un poteau et un sac de paille, PV infinis.
## Il affiche les dégâts reçus et, au-dessus, ses dégâts par seconde sur les
## 3 dernières secondes. Avec `rail` > 0, il glisse de gauche à droite.

signal damaged(amount: float)

const WINDOW := 3.0

var label := ""
var rail := 0.0          # demi-course du rail (px), 0 = immobile
var rail_speed := 70.0
var _origin := Vector2.ZERO
var _t := 0.0
var _flash := 0.0
var _wobble := 0.0
var _recent: Array = []  # [instant, dégâts]
var _info: Label


func _ready() -> void:
	add_to_group("training_dummies")
	add_to_group("hit_wood")      # impact : échardes
	collision_layer = 2           # touché par les tirs, comme les coffres
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 11.0
	shape.shape = circle
	add_child(shape)
	_origin = position
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 11)
	_info.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_info.add_theme_constant_override("outline_size", 3)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.position = Vector2(-60, -78)
	_info.size = Vector2(120, 30)
	add_child(_info)


## Appelé par les projectiles. Retourne false : un mannequin ne meurt pas.
func take_damage(amount: float, _element := 0) -> bool:
	_flash = 0.1
	_wobble = 1.0
	_recent.append([_t, amount])
	damaged.emit(amount)
	_spawn_number(amount)
	return false


func reset() -> void:
	_recent.clear()


func dps() -> float:
	var sum := 0.0
	for r in _recent:
		sum += r[1]
	return sum / WINDOW


func _physics_process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_wobble = maxf(_wobble - delta * 4.0, 0.0)
	while not _recent.is_empty() and _t - _recent[0][0] > WINDOW:
		_recent.pop_front()
	if rail > 0.0:
		position.x = _origin.x + sin(_t * rail_speed / rail) * rail
	_info.text = "%s\n%.1f dégâts/s" % [label, dps()] if dps() > 0.0 else label
	queue_redraw()


func _spawn_number(amount: float) -> void:
	var n := Label.new()
	n.text = "%.0f" % amount
	n.add_theme_font_size_override("font_size", 13)
	n.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	n.add_theme_constant_override("outline_size", 3)
	n.position = Vector2(randf_range(-14, 4), -56)
	add_child(n)
	var tw := n.create_tween()
	tw.tween_property(n, "position:y", n.position.y - 22.0, 0.6)
	tw.parallel().tween_property(n, "modulate:a", 0.0, 0.6)
	tw.tween_callback(n.queue_free)


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tilt := sin(_t * 30.0) * 0.12 * _wobble
	draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
	var wood := Color(0.45, 0.3, 0.17)
	var straw := Color.WHITE if _flash > 0.0 else Color(0.85, 0.72, 0.4)
	var dark := Color(0.3, 0.2, 0.1)
	draw_rect(Rect2(-2.5, -46, 5, 46), wood)
	draw_rect(Rect2(-14, -36, 28, 5), wood)
	# Sac de paille et cible peinte
	draw_rect(Rect2(-10, -44, 20, 30), straw)
	draw_rect(Rect2(-10, -44, 20, 30), dark, false, 1.5)
	draw_circle(Vector2(0, -29), 7.0, Color(0.85, 0.2, 0.15))
	draw_circle(Vector2(0, -29), 4.5, Color(0.95, 0.92, 0.85))
	draw_circle(Vector2(0, -29), 2.0, Color(0.85, 0.2, 0.15))
	# Tête
	draw_circle(Vector2(0, -50), 6.0, straw)
	draw_arc(Vector2(0, -50), 6.0, 0.0, TAU, 16, dark, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if rail > 0.0:
		# Rail au sol
		draw_line(Vector2(_origin.x - position.x - rail, 4), Vector2(_origin.x - position.x + rail, 4), Color(0.25, 0.2, 0.15, 0.7), 3.0)
