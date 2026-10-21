class_name LevelZones
extends RefCounted
## Niveau des monstres selon la zone de la carte (GDD 1, Ennemis).
## Les générateurs et les donjons ont leur propre niveau ; ceci sert aux
## ennemis postés, aux monstres spéciaux et à l'indication à l'écran.
##
## - Niveau 1 : le village et ses alentours.
## - Niveau 2 : le reste du côté ouest de la crête.
## - Niveau 3 : le côté est, au-delà du passage.

## Rayon (ellipse isométrique, en px à l'horizontale) de la zone de niveau 1.
const NEAR_RADIUS := 760.0


static func level_at(p: Vector2, village_center := Vector2.ZERO) -> int:
	if Terrain.side(p) > 0:
		return 3
	var d := p - village_center
	if Vector2(d.x, d.y * 2.0).length() <= NEAR_RADIUS:
		return 1
	return 2


static func zone_name(level: int) -> String:
	return ["", "Alentours du camp", "Côte ouest", "Au-delà de la crête"][clampi(level, 0, 3)]
