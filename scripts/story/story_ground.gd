class_name StoryGround
extends Node2D
## Sol isométrique du prologue (tuiles 64 × 32) : mer, sable mouillé, sable,
## herbe. Dessiné une seule fois ; l'écume, elle, bouge (nœud Foam).

const TW := IsoGround.TILE_W
const TH := IsoGround.TILE_H

const COLORS := {
	BeachMap.Ground.DEEP: [Color(0.13, 0.36, 0.52), Color(0.12, 0.34, 0.50)],
	BeachMap.Ground.SHALLOW: [Color(0.22, 0.55, 0.66), Color(0.21, 0.52, 0.63)],
	BeachMap.Ground.WET_SAND: [Color(0.72, 0.64, 0.47), Color(0.70, 0.62, 0.45)],
	BeachMap.Ground.SAND: [Color(0.87, 0.79, 0.58), Color(0.84, 0.76, 0.55)],
	BeachMap.Ground.GRASS: [Color(0.36, 0.55, 0.30), Color(0.33, 0.52, 0.28)],
	BeachMap.Ground.FOREST: [Color(0.25, 0.40, 0.22), Color(0.23, 0.38, 0.21)],
}


func _ready() -> void:
	z_index = -10
	var foam := Foam.new()
	add_child(foam)


func _draw() -> void:
	# Fond (mer profonde) sous toutes les tuiles
	# La carte est dessinée en entier, nord du chapitre 1 compris (la caméra
	# du prologue ne monte pas jusque-là).
	var top := BeachMap.NORTH_TOP
	draw_rect(Rect2(BeachMap.LEFT - 400, top - 300, BeachMap.RIGHT - BeachMap.LEFT + 800, BeachMap.BOTTOM - top + 600), COLORS[BeachMap.Ground.DEEP][0])
	# Parcours des tuiles couvrant le rectangle de la carte
	var a0 := int(floor((BeachMap.LEFT / (TW / 2.0) + top / (TH / 2.0)) / 2.0)) - 2
	var a1 := int(ceil((BeachMap.RIGHT / (TW / 2.0) + BeachMap.BOTTOM / (TH / 2.0)) / 2.0)) + 2
	var b0 := int(floor((top / (TH / 2.0) - BeachMap.RIGHT / (TW / 2.0)) / 2.0)) - 2
	var b1 := int(ceil((BeachMap.BOTTOM / (TH / 2.0) - BeachMap.LEFT / (TW / 2.0)) / 2.0)) + 2
	for i in range(a0, a1 + 1):
		for j in range(b0, b1 + 1):
			var c := IsoGround.tile_to_world(i, j)
			if c.x < BeachMap.LEFT - 80 or c.x > BeachMap.RIGHT + 80 or c.y < top - 60 or c.y > BeachMap.BOTTOM + 60:
				continue
			var g := BeachMap.ground_at(c)
			if g == BeachMap.Ground.DEEP:
				continue  # déjà le fond
			var col: Color = COLORS[g][(i + j) & 1]
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -TH / 2.0), c + Vector2(TW / 2.0, 0),
				c + Vector2(0, TH / 2.0), c + Vector2(-TW / 2.0, 0)]), col)
	# Quelques coquillages et galets sur le sable
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for k in 140:
		var p := Vector2(rng.randf_range(BeachMap.LEFT, BeachMap.RIGHT), rng.randf_range(-200, 300))
		if BeachMap.ground_at(p) == BeachMap.Ground.SAND:
			draw_circle(p, rng.randf_range(1.5, 3.0), Color(0.95, 0.9, 0.82) if k % 3 else Color(0.6, 0.55, 0.5))
	# Nord : touffes d'herbe, feuilles mortes dans le bosquet, galets dans la crique
	for k in 420:
		var p := Vector2(rng.randf_range(BeachMap.LEFT, BeachMap.RIGHT), rng.randf_range(top + 80, BeachMap.TOP))
		match BeachMap.ground_at(p):
			BeachMap.Ground.GRASS:
				draw_line(p, p + Vector2(-2, -5), Color(0.26, 0.44, 0.22), 1.5)
				draw_line(p, p + Vector2(2, -6), Color(0.3, 0.48, 0.24), 1.5)
			BeachMap.Ground.FOREST:
				draw_circle(p, rng.randf_range(2.0, 3.5), Color(0.45, 0.33, 0.16, 0.7) if k % 2 else Color(0.18, 0.3, 0.16))
			BeachMap.Ground.SAND:
				draw_circle(p, rng.randf_range(1.5, 3.0), Color(0.6, 0.55, 0.5))


## Écume qui va et vient le long de la ligne d'eau.
class Foam:
	extends Node2D
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var pts := PackedVector2Array()
		var pts2 := PackedVector2Array()
		var x := BeachMap.LEFT - 200.0
		var wave := sin(_t * 1.3) * 5.0
		while x <= BeachMap.RIGHT + 200.0:
			var y := BeachMap.shore_y(x) + 8.0 + wave + sin(x / 60.0 + _t * 2.0) * 2.0
			pts.append(Vector2(x, y))
			pts2.append(Vector2(x, y + 26.0 - wave * 0.6 + sin(x / 45.0 - _t * 1.7) * 2.5))
			x += 20.0
		draw_polyline(pts, Color(0.95, 0.97, 1.0, 0.75), 3.0, true)
		draw_polyline(pts2, Color(0.85, 0.93, 1.0, 0.35), 2.0, true)
