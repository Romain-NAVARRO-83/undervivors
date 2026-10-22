class_name BeachMap
extends RefCounted
## Géographie du prologue « La plage » (mode histoire).
## Une bande de sable entre la mer (au sud) et une butte rocheuse
## infranchissable (au nord). On la longe vers l'est ; au bout, la butte
## s'arrête et l'on peut passer de l'autre côté.

## Limites de la carte (px).
const LEFT := -1500.0
const RIGHT := 1400.0
const TOP := -1050.0
const BOTTOM := 650.0

## Étendue de la butte (x) : elle commence contre la falaise ouest et
## s'arrête à BUTTE_END ; au-delà, on peut remonter vers le nord.
const BUTTE_START := -1360.0
const BUTTE_END := 750.0

const START := Vector2(-1150, 70)


## Ligne d'eau (y) en fonction de x.
static func shore_y(x: float) -> float:
	return 185.0 + 35.0 * sin(x / 380.0) + 18.0 * sin(x / 170.0 + 2.0)


## Pied de la butte (y) en fonction de x.
static func butte_y(x: float) -> float:
	return -40.0 + 40.0 * sin(x / 520.0 + 1.0) + 12.0 * sin(x / 140.0)


static func in_butte_span(x: float) -> bool:
	return x >= BUTTE_START and x <= BUTTE_END


## Vrai si le point est « de l'autre côté » : au nord de la butte, après son extrémité.
static func past_butte(p: Vector2) -> bool:
	return p.x > BUTTE_END + 40.0 and p.y < butte_y(BUTTE_END) - 80.0


enum Ground { DEEP, SHALLOW, WET_SAND, SAND, GRASS }


static func ground_at(p: Vector2) -> Ground:
	var sy := shore_y(p.x)
	if p.y > sy + 70.0:
		return Ground.DEEP
	if p.y > sy + 10.0:
		return Ground.SHALLOW
	if p.y > sy - 20.0:
		return Ground.WET_SAND
	if in_butte_span(p.x):
		return Ground.SAND if p.y > butte_y(p.x) - 30.0 else Ground.GRASS
	# Au-delà de la butte : la plage se rétrécit puis l'herbe reprend.
	return Ground.SAND if p.y > sy - 170.0 else Ground.GRASS
