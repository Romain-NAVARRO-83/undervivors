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
## Chapitre 1 : la carte s'agrandit vers le nord (le prologue s'arrête à TOP).
const NORTH_TOP := -2500.0
const BOTTOM := 650.0

## Étendue de la butte (x) : elle commence contre la falaise ouest et
## s'arrête à BUTTE_END ; au-delà, on peut remonter vers le nord.
const BUTTE_START := -1360.0
const BUTTE_END := 750.0

const START := Vector2(-1150, 70)

## Chapitre 1 : les trois coins à explorer au nord du refuge.
const COVE_CENTER := Vector2(-1080, -1480)    # la crique, à l'ouest (bois flotté)
const COVE_RADIUS := 300.0
const GROVE_CENTER := Vector2(-150, -2060)     # le bosquet, au nord
const GROVE_RADIUS := 330.0
const WRECK2_CENTER := Vector2(860, -1680)     # l'épave, au nord-est


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


enum Ground { DEEP, SHALLOW, WET_SAND, SAND, GRASS, FOREST }


static func ground_at(p: Vector2) -> Ground:
	# Nord de l'île (chapitre 1) : la mer au bout, une crique de sable à
	# l'ouest, le sol sombre du bosquet au nord.
	if p.y < NORTH_TOP + 30.0:
		return Ground.SHALLOW
	if p.y < NORTH_TOP + 70.0:
		return Ground.WET_SAND
	if p.y < TOP + 80.0:
		var cove := _iso_dist(p, COVE_CENTER)
		if cove < COVE_RADIUS * 0.55 and p.x < COVE_CENTER.x - 60.0:
			return Ground.WET_SAND
		if cove < COVE_RADIUS:
			return Ground.SAND
		if _iso_dist(p, GROVE_CENTER) < GROVE_RADIUS + 30.0 * sin(p.x / 47.0):
			return Ground.FOREST
		return Ground.GRASS
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


## Distance « au sol » (une ellipse iso 2:1 compte comme un cercle).
static func _iso_dist(p: Vector2, c: Vector2) -> float:
	var d := p - c
	return Vector2(d.x, d.y * 2.0).length()
