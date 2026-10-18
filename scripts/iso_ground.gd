class_name IsoGround
extends Node2D
## Sol isométrique placeholder (losanges 64×32), dessiné en code.
## À remplacer par une TileMapLayer isométrique quand les tuiles graphiques existeront.

const TILE_W := 64
const TILE_H := 32
## Demi-taille de la carte, en tuiles (la carte fait 2 × HALF_SIZE + 1 tuiles de côté).
const HALF_SIZE := 40
## Rayon (en tuiles) de la place du village, la zone marron où l'on peut construire.
const VILLAGE_RADIUS := 9.5
## Côtes sud-est et sud-ouest (bords i et j max) : mer puis plage, en tuiles depuis le bord.
const SEA_ROWS := 4
const BEACH_ROWS := 6
var half_size: int = HALF_SIZE


## Vrai si la tuile appartient à la place du village (constructible).
static func in_village(t: Vector2i) -> bool:
	return Vector2(t.x, t.y).length() < VILLAGE_RADIUS


static func is_sea(t: Vector2i) -> bool:
	return maxi(t.x, t.y) > HALF_SIZE - SEA_ROWS


static func is_beach(t: Vector2i) -> bool:
	return not is_sea(t) and maxi(t.x, t.y) > HALF_SIZE - SEA_ROWS - BEACH_ROWS


static func tile_to_world(i: int, j: int) -> Vector2:
	return Vector2((i - j) * TILE_W / 2.0, (i + j) * TILE_H / 2.0)


func _draw() -> void:
	for i in range(-half_size, half_size + 1):
		for j in range(-half_size, half_size + 1):
			var c := tile_to_world(i, j)
			var base: Color
			if in_village(Vector2i(i, j)):
				base = Color(0.55, 0.45, 0.3)        # place du village (constructible)
			elif is_sea(Vector2i(i, j)):
				base = Color(0.2, 0.45, 0.65)        # mer
			elif is_beach(Vector2i(i, j)):
				base = Color(0.86, 0.78, 0.55)       # plage
			else:
				base = Color(0.35, 0.55, 0.3)        # herbe
			if (i + j) % 2 == 0:
				base = base.darkened(0.06)
			var pts := PackedVector2Array([
				c + Vector2(0, -TILE_H / 2.0),
				c + Vector2(TILE_W / 2.0, 0),
				c + Vector2(0, TILE_H / 2.0),
				c + Vector2(-TILE_W / 2.0, 0),
			])
			draw_colored_polygon(pts, base)
	# Feu de camp au centre du village
	draw_circle(Vector2.ZERO, 10.0, Color(0.3, 0.2, 0.15))
	draw_circle(Vector2(0, -4), 6.0, Color(1.0, 0.55, 0.15))
	draw_circle(Vector2(0, -7), 3.0, Color(1.0, 0.9, 0.4))
