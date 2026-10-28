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

## Carrefour des sentiers, au nord du refuge.
const CROSSROADS := Vector2(-120, -1460)
## Sentiers de terre battue (polylignes) : ils relient le refuge au carrefour,
## puis le carrefour à chaque coin à explorer. On ne plante rien dessus.
const PATHS := [
	# Refuge → valise du lance-pierre → carrefour
	[Vector2(-150, -930), Vector2(-90, -1080), Vector2(-60, -1210), Vector2(-120, -1460)],
	# Carrefour → la crique (ouest)
	[Vector2(-120, -1460), Vector2(-420, -1500), Vector2(-700, -1440), Vector2(-920, -1470)],
	# Carrefour → le bosquet (nord), jusqu'à sa trouée
	[Vector2(-120, -1460), Vector2(-170, -1640), Vector2(-150, -1880)],
	# Carrefour → l'épave (nord-est)
	[Vector2(-120, -1460), Vector2(200, -1520), Vector2(480, -1590), Vector2(720, -1640)],
	# Refuge → bout de la butte (le chemin du prologue, vers la plage)
	[Vector2(-80, -840), Vector2(250, -640), Vector2(600, -420), Vector2(860, -260)],
]
const PATH_HALF := 18.0


## Distance d'un point au sentier le plus proche.
static func path_distance(p: Vector2) -> float:
	var best := INF
	for path in PATHS:
		for i in path.size() - 1:
			best = minf(best, _seg_dist(p, path[i], path[i + 1]))
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


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
