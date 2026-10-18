class_name Ridge
extends Node2D
## Crête rocheuse infranchissable (couche « obstacles ») avec un seul passage,
## plus la bordure invisible du losange de la carte. Les rochers sont des
## nœuds séparés pour être triés en profondeur avec les personnages.

var world: Node2D


func build() -> void:
	var body := StaticBody2D.new()
	body.name = "Collisions"
	body.collision_layer = 4   # obstacles
	body.collision_mask = 0
	add_child(body)
	var top := -Terrain.MAP_HALF.y - 40.0
	var bottom := Terrain.MAP_HALF.y + 40.0
	var g0 := Terrain.GAP_Y - Terrain.GAP_HALF
	var g1 := Terrain.GAP_Y + Terrain.GAP_HALF
	# Deux pans de crête, au-dessus et au-dessous du passage
	for seg in [[top, g0], [g1, bottom]]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(Terrain.RIDGE_THICKNESS, seg[1] - seg[0])
		shape.shape = rect
		shape.position = Vector2(Terrain.RIDGE_X, (seg[0] + seg[1]) / 2.0)
		body.add_child(shape)
	# Bordure de la carte : 4 segments sur les bords du losange
	var h := Terrain.MAP_HALF
	var pts := [Vector2(0, -h.y), Vector2(h.x, 0), Vector2(0, h.y), Vector2(-h.x, 0)]
	for i in 4:
		var shape := CollisionShape2D.new()
		var segment := SegmentShape2D.new()
		segment.a = pts[i]
		segment.b = pts[(i + 1) % 4]
		shape.shape = segment
		body.add_child(shape)
	# Rochers visibles le long de la crête, dans les limites du sol
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var y := top
	while y < bottom:
		if (y < g0 - 4.0 or y > g1 + 4.0) and Terrain.inside_map(Vector2(Terrain.RIDGE_X, y)):
			var rock := Rock.new()
			rock.position = Vector2(Terrain.RIDGE_X + rng.randf_range(-6, 6), y)
			rock.size = rng.randf_range(0.8, 1.3)
			rock.seed_value = rng.randi()
			world.add_child(rock)
		y += 16.0


class Rock:
	extends Node2D
	var size := 1.0
	var seed_value := 0

	func _draw() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		var s := size
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 17.0 * s, Color(0, 0, 0, 0.25))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Bloc rocheux irrégulier : face sombre + face éclairée
		var pts := PackedVector2Array()
		var n := 7
		for i in n:
			var a := PI + PI * i / (n - 1)
			var r := (14.0 + rng.randf_range(-3, 4)) * s
			pts.append(Vector2(cos(a) * r, sin(a) * r * 1.5 - 2.0))
		pts.append(Vector2(13 * s, 2))
		pts.append(Vector2(-13 * s, 2))
		draw_colored_polygon(pts, Color(0.38, 0.36, 0.34))
		var light := PackedVector2Array()
		for i in 4:
			light.append(pts[i])
		light.append(Vector2(0, -2))
		draw_colored_polygon(light, Color(0.52, 0.5, 0.46))
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, Color(0.18, 0.17, 0.16), 1.5, true)
		# Touffe de mousse
		if rng.randf() < 0.4:
			draw_circle(Vector2(rng.randf_range(-6, 6) * s, -16 * s), 3.0 * s, Color(0.3, 0.45, 0.25))
