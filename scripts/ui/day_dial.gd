class_name DayDial
extends Control
## Cadran du temps qui passe, en haut de l'écran (mode histoire).
## Le disque est partagé entre le jour (clair) et la nuit (sombre) ; midi est
## en haut, minuit en bas. Une aiguille, terminée par le soleil ou la lune,
## tourne avec l'heure. Dessous : « Jour 2 · 14 h 30 », et ⏩ quand le temps
## est accéléré.

const R := 30.0

var day_night: DayNight


func _ready() -> void:
	custom_minimum_size = Vector2(R * 2 + 16, R * 2 + 34)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_d: float) -> void:
	queue_redraw()


## Angle (radians, 0 = à droite) d'une heure : midi en haut, minuit en bas.
static func hour_angle(h: float) -> float:
	return -PI / 2.0 + (h - 12.0) / 24.0 * TAU


func _draw() -> void:
	if day_night == null:
		return
	var c := Vector2(size.x / 2.0, R + 6)
	var day_col := Color(0.55, 0.78, 0.95)
	var night_col := Color(0.12, 0.14, 0.3)
	draw_circle(c, R + 4, Color(0, 0, 0, 0.55))
	# Secteur de nuit puis secteur de jour
	_draw_sector(c, R, hour_angle(DayNight.DUSK), hour_angle(DayNight.DAWN + 24.0), night_col)
	_draw_sector(c, R, hour_angle(DayNight.DAWN), hour_angle(DayNight.DUSK), day_col)
	# Étoiles dans la nuit
	for k in 5:
		var a := hour_angle(DayNight.DUSK + 1.2 + k * 1.5)
		draw_circle(c + Vector2(cos(a), sin(a)) * R * (0.45 + 0.1 * (k % 3)), 1.2, Color(1, 1, 0.9, 0.8))
	draw_arc(c, R, 0.0, TAU, 48, Color(0.95, 0.68, 0.25), 2.0, true)
	# Aiguille et astre
	var a := hour_angle(day_night.hour)
	var tip := c + Vector2(cos(a), sin(a)) * (R - 6.0)
	draw_line(c, tip, Color(1, 1, 1, 0.9), 2.0, true)
	draw_circle(c, 2.5, Color.WHITE)
	if day_night.is_night():
		draw_circle(tip, 6.0, Color(0.92, 0.92, 0.85))
		draw_circle(tip + Vector2(2.5, -1.5), 5.0, night_col)   # croissant
	else:
		draw_circle(tip, 6.5, Color(1.0, 0.85, 0.3))
		for k in 8:
			var r := TAU * k / 8.0
			draw_line(tip + Vector2(cos(r), sin(r)) * 8.0, tip + Vector2(cos(r), sin(r)) * 10.5, Color(1.0, 0.85, 0.3), 1.5)
	# Texte
	var font := get_theme_default_font()
	var h := int(day_night.hour)
	var m := int((day_night.hour - h) * 60.0) / 10 * 10
	var txt := "Jour %d · %d h %02d" % [day_night.day, h, m]
	if day_night.speed > 1.0:
		txt += "  ⏩"
	draw_string_outline(font, Vector2(0, R * 2 + 26), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, 4, Color(0, 0, 0, 0.9))
	draw_string(font, Vector2(0, R * 2 + 26), txt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(0.95, 0.9, 0.8))


func _draw_sector(c: Vector2, r: float, a0: float, a1: float, col: Color) -> void:
	var pts := PackedVector2Array([c])
	var n := 32
	for i in n + 1:
		var a := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)
