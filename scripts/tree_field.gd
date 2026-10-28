class_name TreeField
extends Node
## Arbres décoratifs non abattables qui servent d'obstacles (couche
## « obstacles ») : une lisière sur les bords de la carte (sauf côté mer) et
## des bosquets dispersés. On laisse dégagés le camp, les points d'intérêt et
## des couloirs de passage entre le camp et chacun d'eux.

## Couloirs gardés libres (segments) et demi-largeur.
const CORRIDOR_HALF := 75.0

var world: Node2D
var seed_value := 20261018
## Points à garder dégagés : [position, rayon].
var keep_clear: Array = []
## Couloirs : [a, b] (segments).
var corridors: Array = []

var _rng := RandomNumberGenerator.new()
var _placed: Array[Vector2] = []


func build() -> int:
	_rng.seed = seed_value
	var h := IsoGround.HALF_SIZE
	# Lisière : deux rangées le long des bords nord-ouest (j min) et nord-est (i min).
	for a in range(-h, h + 1):
		for b in [0, 1]:
			for t in [Vector2i(-h + b, a), Vector2i(a, -h + b)]:
				if IsoGround.is_sea(t) or IsoGround.is_beach(t):
					continue
				if _rng.randf() < (0.95 if b == 0 else 0.7):
					_try_plant(IsoGround.tile_to_world(t.x, t.y) + _jitter(8.0), true)
	# Bosquets dispersés sur l'herbe
	var clumps := 0
	var attempts := 0
	while clumps < 46 and attempts < 2000:
		attempts += 1
		var t := Vector2i(_rng.randi_range(-h + 3, h - 3), _rng.randi_range(-h + 3, h - 3))
		var c := IsoGround.tile_to_world(t.x, t.y)
		if not _free_spot(c, 40.0):
			continue
		var n := _rng.randi_range(2, 6)
		for k in n:
			var off := Vector2i(_rng.randi_range(-2, 2), _rng.randi_range(-2, 2))
			var tt := t + off
			var p := IsoGround.tile_to_world(tt.x, tt.y) + _jitter(10.0)
			_try_plant(p, false)
		clumps += 1
	return _placed.size()


func _jitter(r: float) -> Vector2:
	return Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r) * 0.5)


func _try_plant(p: Vector2, border: bool) -> void:
	if not border and not _free_spot(p, 30.0):
		return
	for q in _placed:
		if q.distance_to(p) < 26.0:
			return
	var tree := plant(world, p, _rng)
	if tree:
		_placed.append(tree.position)


## Vrai si l'emplacement respecte le camp, les points d'intérêt et les couloirs.
func _free_spot(p: Vector2, margin: float) -> bool:
	var t := BuildManager.world_to_tile(p)
	if Vector2(t.x, t.y).length() < IsoGround.VILLAGE_RADIUS + 3.0:
		return false
	if IsoGround.is_sea(t) or IsoGround.is_beach(t) or not Terrain.inside_map(p * 1.03):
		return false
	if absf(p.x - Terrain.RIDGE_X) < 70.0:
		return false
	for k in keep_clear:
		if p.distance_to(k[0]) < k[1] + margin:
			return false
	for seg in corridors:
		if _dist_to_segment(p, seg[0], seg[1]) < CORRIDOR_HALF + margin * 0.5:
			return false
	return true


static func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Plante un arbre sur la case qui contient `p` (calé au centre de la case).
## Retourne null si la case est déjà prise (arbre ou construction).
static func plant(parent: Node, p: Vector2, rng: RandomNumberGenerator) -> IsoTree:
	var tile := BuildManager.world_to_tile(p)
	if Nav.blocked.has(tile):
		return null
	var tree := IsoTree.new()
	tree.tile = tile
	tree.position = BuildManager.tile_center(tile)
	tree.variant = rng.randi_range(0, 2)
	tree.scale_k = rng.randf_range(0.85, 1.25)
	tree.seed_value = rng.randi()
	Nav.set_blocked(tile, true)
	parent.add_child(tree)
	return tree


## Arbre feuillu ou conifère. Il occupe une case entière de la grille iso :
## sa collision est le losange de la case, et la case est bloquée pour la
## navigation (Nav), si bien que survivants et monstres le contournent.
class IsoTree:
	extends StaticBody2D
	var variant := 0
	var scale_k := 1.0
	var seed_value := 0
	var tile := Vector2i.ZERO
	var _t := 0.0

	func _ready() -> void:
		add_to_group("trees")
		collision_layer = 4   # obstacles : bloque survivants, monstres et tirs
		collision_mask = 0
		var shape := CollisionShape2D.new()
		var poly := ConvexPolygonShape2D.new()
		var hw := IsoGround.TILE_W / 2.0
		var hh := IsoGround.TILE_H / 2.0
		poly.points = PackedVector2Array([Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)])
		shape.shape = poly
		add_child(shape)
		_t = float(seed_value % 1000) / 100.0

	func _exit_tree() -> void:
		Nav.set_blocked(tile, false)

	func _process(delta: float) -> void:
		# Balancement très léger : on ne redessine pas à chaque image pour rester léger.
		_t += delta
		if Engine.get_process_frames() % 6 == seed_value % 6:
			queue_redraw()

	func _draw() -> void:
		var k := scale_k
		var sway := sin(_t * 0.8) * 1.2
		draw_set_transform(Vector2(6, 2), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 18.0 * k, Color(0, 0, 0, 0.22))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_rect(Rect2(Vector2(-3, -16) * k, Vector2(6, 17) * k), Color(0.36, 0.24, 0.14))
		draw_line(Vector2(3, -14) * k, Vector2(3, 0) * k, Color(0.25, 0.16, 0.1), 1.5)
		match variant:
			0, 1:
				# Feuillu : trois boules de feuillage étagées
				var base := Color(0.2, 0.42, 0.2) if variant == 0 else Color(0.27, 0.46, 0.22)
				var c := Vector2(sway, -30 * k)
				draw_circle(c + Vector2(-9, 4) * k, 12 * k, base.darkened(0.15))
				draw_circle(c + Vector2(9, 4) * k, 12 * k, base.darkened(0.2))
				draw_circle(c + Vector2(0, -6) * k, 14 * k, base)
				draw_circle(c + Vector2(-4, -10) * k, 6 * k, base.lightened(0.15))
			_:
				# Conifère
				for layer in 3:
					var w := (15.0 - layer * 4.0) * k
					var y0 := (-12.0 - layer * 12.0) * k
					var top := Vector2(sway * (layer + 1) * 0.5, y0 - 20.0 * k)
					var col := Color(0.13 + layer * 0.03, 0.3 + layer * 0.04, 0.17)
					draw_colored_polygon(PackedVector2Array([Vector2(-w, y0), Vector2(w, y0), top]), col)
