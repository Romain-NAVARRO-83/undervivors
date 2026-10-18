class_name IsoGround
extends Node2D
## Sol isométrique placeholder (losanges 64×32), dessiné en code.
## À remplacer par une TileMapLayer isométrique quand les tuiles graphiques existeront.

const TILE_W := 64
const TILE_H := 32
@export var half_size: int = 22


static func tile_to_world(i: int, j: int) -> Vector2:
	return Vector2((i - j) * TILE_W / 2.0, (i + j) * TILE_H / 2.0)


func _draw() -> void:
	for i in range(-half_size, half_size + 1):
		for j in range(-half_size, half_size + 1):
			var c := tile_to_world(i, j)
			var d := Vector2(i, j).length()
			var base: Color
			if d < 3.5:
				base = Color(0.55, 0.45, 0.3)        # place du village
			elif i + j > half_size * 0.9:
				base = Color(0.2, 0.45, 0.65)        # mer
			elif i + j > half_size * 0.6:
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
