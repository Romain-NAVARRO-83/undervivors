class_name Nav
extends RefCounted
## Navigation autour des constructions (murs et tourelles infranchissables).
## Grille A* sur les tuiles isométriques ; les cases occupées par une
## construction sont pleines. Le relief (crête et passage) reste géré par
## Terrain.route ; on s'en sert d'abord, puis on contourne les constructions.
##
## Coût : on ne lance l'A* que si la ligne droite traverse une construction.

const SAMPLE_STEP := 6.0
const BODY_MARGIN := 10.0       # rayon d'un personnage (+ marge)
## Losange d'une tuile élargi du rayon d'un personnage : la distance du centre
## à un côté (14,3 px pour une tuile 64 × 32) passe à 14,3 + BODY_MARGIN.
const _EDGE_DIST := (IsoGround.TILE_W / 2.0) * (IsoGround.TILE_H / 2.0) / 35.777
const _INFLATE := (_EDGE_DIST + BODY_MARGIN) / _EDGE_DIST
const LOOKAHEAD := 8            # lissage : point de passage visible le plus loin

## Cases pleines (Vector2i -> true), tenues à jour par le gestionnaire de construction.
static var blocked := {}
static var _astar: AStarGrid2D
## Étendue de la grille (en tuiles). Par défaut la carte du mode test ; le
## mode histoire l'agrandit à sa propre carte (set_region).
const DEFAULT_REGION := Rect2i(-IsoGround.HALF_SIZE - 2, -IsoGround.HALF_SIZE - 2, 2 * IsoGround.HALF_SIZE + 5, 2 * IsoGround.HALF_SIZE + 5)
static var region := DEFAULT_REGION


static func _grid() -> AStarGrid2D:
	if _astar == null:
		_astar = AStarGrid2D.new()
		_astar.region = region
		_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		_astar.update()
		for t in blocked:
			_astar.set_point_solid(t, true)
	return _astar


static func set_blocked(t: Vector2i, on: bool) -> void:
	if on:
		blocked[t] = true
	else:
		blocked.erase(t)
	var g := _grid()
	if g.is_in_boundsv(t):
		g.set_point_solid(t, on)


static func clear() -> void:
	blocked.clear()
	_astar = null
	region = DEFAULT_REGION


## Grille couvrant un rectangle du monde (px), avec une marge.
static func set_region_world(r: Rect2) -> void:
	var minv := Vector2i(1 << 20, 1 << 20)
	var maxv := -minv
	for c in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var t := BuildManager.world_to_tile(c)
		minv = Vector2i(mini(minv.x, t.x), mini(minv.y, t.y))
		maxv = Vector2i(maxi(maxv.x, t.x), maxi(maxv.y, t.y))
	region = Rect2i(minv - Vector2i(3, 3), maxv - minv + Vector2i(7, 7))
	_astar = null


static func is_blocked_at(p: Vector2) -> bool:
	return blocked.has(BuildManager.world_to_tile(p))


## Vrai si un personnage centré en p toucherait une construction.
static func body_hits(p: Vector2) -> bool:
	var t := BuildManager.world_to_tile(p)
	var hw := IsoGround.TILE_W / 2.0 * _INFLATE
	var hh := IsoGround.TILE_H / 2.0 * _INFLATE
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := t + Vector2i(dx, dy)
			if not blocked.has(c):
				continue
			var d := p - BuildManager.tile_center(c)
			if absf(d.x) / hw + absf(d.y) / hh < 1.0:
				return true
	return false


## Vrai si un personnage peut aller en ligne droite de a à b sans toucher de
## construction (on ignore le point de départ : il peut longer un mur).
static func segment_clear(a: Vector2, b: Vector2) -> bool:
	if blocked.is_empty():
		return true
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return true
	var dir := d / l
	var n := int(ceil(l / SAMPLE_STEP))
	var started_inside := body_hits(a)
	for i in range(1, n + 1):
		var p := a + dir * minf(i * SAMPLE_STEP, l)
		if body_hits(p):
			if started_inside and i * SAMPLE_STEP < BODY_MARGIN * 2.0:
				continue  # on s'écarte d'un mur qu'on longe
			return false
	return true


## Prochain point vers lequel se diriger pour rejoindre `to` depuis `from`.
static func route(from: Vector2, to: Vector2) -> Vector2:
	var goal := Terrain.route(from, to)
	if blocked.is_empty() or segment_clear(from, goal):
		return goal
	var a := _free_tile_near(from)
	var b := BuildManager.world_to_tile(goal)
	var g := _grid()
	if not g.is_in_boundsv(a) or not g.is_in_boundsv(b):
		return goal
	if g.is_point_solid(b):
		b = _free_tile_near(goal)
	var path := g.get_id_path(a, b, true)
	if path.size() < 2:
		return goal
	# Lissage : le point du chemin le plus loin encore visible en ligne droite.
	var last := mini(path.size() - 1, LOOKAHEAD)
	for i in range(last, 0, -1):
		var p := goal if i == path.size() - 1 else BuildManager.tile_center(path[i])
		if segment_clear(from, p):
			return p
	return BuildManager.tile_center(path[1])


## Case libre la plus proche d'un point (le point lui-même si sa case est libre).
static func _free_tile_near(p: Vector2) -> Vector2i:
	var t := BuildManager.world_to_tile(p)
	if not blocked.has(t):
		return t
	var best := t
	var best_d := INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := t + Vector2i(dx, dy)
			if blocked.has(c):
				continue
			var d := BuildManager.tile_center(c).distance_squared_to(p)
			if d < best_d:
				best_d = d
				best = c
	return best


## Vrai si poser une construction sur `t` fermerait une enceinte : une case
## libre de la place du camp ne serait plus reliée à l'extérieur.
## (Passage entre deux cases par un côté seulement : deux constructions qui
## se touchent par un coin bloquent le passage.)
static func would_enclose(t: Vector2i) -> bool:
	var r := int(ceil(IsoGround.VILLAGE_RADIUS)) + 2
	var minv := Vector2i(-r, -r)
	var maxv := Vector2i(r, r)
	var solid := blocked.duplicate()
	solid[t] = true
	var seen := {}
	var stack: Array[Vector2i] = []
	# Graines : toutes les cases libres du bord du cadre (hors place du camp).
	for i in range(-r, r + 1):
		for c in [Vector2i(i, -r), Vector2i(i, r), Vector2i(-r, i), Vector2i(r, i)]:
			if not solid.has(c) and not seen.has(c):
				seen[c] = true
				stack.append(c)
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in dirs:
			var nb: Vector2i = c + d
			if nb.x < minv.x or nb.y < minv.y or nb.x > maxv.x or nb.y > maxv.y:
				continue
			if solid.has(nb) or seen.has(nb):
				continue
			seen[nb] = true
			stack.append(nb)
	for x in range(-r, r + 1):
		for y in range(-r, r + 1):
			var c := Vector2i(x, y)
			if IsoGround.in_village(c) and not solid.has(c) and not seen.has(c):
				return true
	return false
