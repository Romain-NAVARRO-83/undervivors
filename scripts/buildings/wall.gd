class_name Wall
extends Building
## Mur de palissade : bloque les monstres, encaisse leurs coups.

const COST := 2


func _init() -> void:
	display_name = "Mur"
	cost = COST
	build_time = 4.0
	max_hp = 120.0


func block_height() -> float:
	return 18.0


## Bloc de palissade sur une tuile : faces en planches verticales, dessus en
## rondins, petits pieux pointus sur l'arête avant.
func _draw_built() -> void:
	var h := block_height()
	var wood := _flash_color(Color(0.55, 0.38, 0.22))
	var dark := Color(0.28, 0.19, 0.11)
	var top := draw_iso_block(h, wood.lightened(0.12), wood.darkened(0.08), wood.darkened(0.28), dark)
	# Planches verticales sur les deux faces visibles
	for k in range(1, 6):
		var f := k / 6.0
		var pl := Vector2(-HW, 0).lerp(Vector2(0, HH), f)
		var pr := Vector2(0, HH).lerp(Vector2(HW, 0), f)
		draw_line(pl, pl + Vector2(0, -h), dark.lightened(0.1), 1.0)
		draw_line(pr, pr + Vector2(0, -h), dark, 1.0)
	# Rondins sur le dessus (parallèles à l'arête O-S)
	for k in range(1, 4):
		var f := k / 4.0
		var a: Vector2 = top[3].lerp(top[0], f)
		var b: Vector2 = top[2].lerp(top[1], f)
		draw_line(a, b, dark.lightened(0.2), 1.0)
	# Pieux pointus le long des arêtes avant
	for edge in [[top[3], top[2]], [top[2], top[1]]]:
		for k in 5:
			var p: Vector2 = edge[0].lerp(edge[1], (k + 0.5) / 5.0)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-3, 0), p + Vector2(3, 0), p + Vector2(0, -6)]), wood.lightened(0.05))
			draw_line(p + Vector2(-3, 0), p + Vector2(0, -6), dark, 1.0)
			draw_line(p + Vector2(3, 0), p + Vector2(0, -6), dark, 1.0)
	# Fissures quand il est bien entamé
	var dmg := 1.0 - hp / max_hp
	if dmg > 0.35:
		draw_line(Vector2(-20, -4), Vector2(-12, -12), dark, 1.5)
	if dmg > 0.65:
		draw_line(Vector2(10, 4), Vector2(20, -8), dark, 1.5)
		draw_line(Vector2(-6, 10), Vector2(-2, 0), dark, 1.5)
