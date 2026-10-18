class_name Wall
extends Building
## Mur de palissade : bloque les monstres, encaisse leurs coups.

const COST := 2


func _init() -> void:
	display_name = "Mur"
	cost = COST
	build_time = 4.0
	max_hp = 120.0


func _top() -> float:
	return 30.0


func _draw_built() -> void:
	var wood := _flash_color(Color(0.55, 0.38, 0.22))
	var dark := Color(0.32, 0.22, 0.13)
	# Rangée de pieux pointus sur le losange de la case
	var damage := 1.0 - hp / max_hp
	for k in 7:
		var t := (k - 3) / 3.0
		var base := Vector2(t * 24.0, absf(t) * -4.0 + 4.0)
		var h := 28.0 - absf(t) * 6.0
		if damage > 0.5 and k % 3 == 1:
			h *= 0.6  # pieux cassés
		var pts := PackedVector2Array([
			base + Vector2(-3.5, 0), base + Vector2(3.5, 0),
			base + Vector2(3.5, -h), base + Vector2(0, -h - 5), base + Vector2(-3.5, -h),
		])
		draw_colored_polygon(pts, wood if k % 2 == 0 else wood.darkened(0.12))
		draw_polyline(pts + PackedVector2Array([pts[0]]), dark, 1.0)
	# Traverse
	draw_line(Vector2(-24, -8), Vector2(24, -8), dark, 3.0)
