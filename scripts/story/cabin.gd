class_name Cabin
extends Building
## Chapitre 1 : la cabane du refuge, premier vrai abri des survivants.
## Une construction unique en planches, plus grande qu'un mur (2 × 2 tuiles),
## posée sur l'emplacement marqué près du feu. Comme les autres constructions,
## le chantier se monte tout seul.

const COST := 8

## Demi-dimensions de l'empreinte (2 × 2 tuiles iso).
const CHW := IsoGround.TILE_W
const CHH := IsoGround.TILE_H
const WALL_H := 34.0
const ROOF_H := 30.0


func _init() -> void:
	display_name = "Cabane"
	cost = COST
	build_time = 14.0
	max_hp = 400.0


## Collision un peu plus petite que l'empreinte : on peut la frôler.
func _make_shape() -> Shape2D:
	var poly := ConvexPolygonShape2D.new()
	var k := 0.8
	poly.points = PackedVector2Array([Vector2(0, -CHH * k), Vector2(CHW * k, 0), Vector2(0, CHH * k), Vector2(-CHW * k, 0)])
	return poly


func is_touching(p: Vector2, margin := 12.0) -> bool:
	var d := p - global_position
	return absf(d.x) / (CHW + margin) + absf(d.y) / (CHH + margin * 0.6) <= 1.0


func contains(world_pos: Vector2) -> bool:
	var d := world_pos - global_position
	return absf(d.x) / CHW + absf(d.y + 30.0) / (CHH + 30.0) <= 1.0


func block_height() -> float:
	return WALL_H + ROOF_H


func _top() -> float:
	return WALL_H + ROOF_H + CHH


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(6, -CHH + 4), Vector2(CHW + 8, 4), Vector2(6, CHH + 4), Vector2(-CHW + 8, 4)]), Color(0, 0, 0, 0.2))
	if is_built:
		_draw_cabin(1.0)
	else:
		_draw_cabin_site()
	if is_built and hp < max_hp:
		draw_rect(Rect2(-24, -_top() - 10, 48, 4), Color(0.2, 0, 0))
		draw_rect(Rect2(-24, -_top() - 10, 48 * hp / max_hp, 4), Color(0.9, 0.35, 0.3))
	if not is_built:
		draw_rect(Rect2(-26, -_top() - 12, 52, 6), Color(0.1, 0.1, 0.1, 0.8))
		draw_rect(Rect2(-26, -_top() - 12, 52 * progress, 6), Color(0.95, 0.75, 0.3))


## Chantier : poteaux d'angle, puis les murs montent, puis le toit.
func _draw_cabin_site() -> void:
	var wood := Color(0.6, 0.45, 0.28)
	var n := Vector2(0, -CHH)
	var e := Vector2(CHW, 0)
	var s := Vector2(0, CHH)
	var w := Vector2(-CHW, 0)
	draw_polyline(PackedVector2Array([n, e, s, w, n]), Color(0.95, 0.8, 0.4, 0.85), 1.5)
	var walls := clampf(progress / 0.7, 0.0, 1.0)
	var up := Vector2(0, -WALL_H)
	for v in [w, s, e, n]:
		draw_line(v, v + up, wood, 3.0)
	if walls > 0.0:
		_draw_walls(walls)
	if progress > 0.7:
		_draw_roof((progress - 0.7) / 0.3)


func _draw_cabin(_k: float) -> void:
	_draw_walls(1.0)
	_draw_roof(1.0)


## Murs en planches horizontales, hauteur `k` (0 → 1), porte sur la face gauche.
func _draw_walls(k: float) -> void:
	var wood := _flash_color(Color(0.56, 0.4, 0.24))
	var dark := Color(0.27, 0.18, 0.1)
	var s := Vector2(0, CHH)
	var e := Vector2(CHW, 0)
	var w := Vector2(-CHW, 0)
	var h := WALL_H * k
	var up := Vector2(0, -h)
	var left_face := PackedVector2Array([w, s, s + up, w + up])
	var right_face := PackedVector2Array([s, e, e + up, s + up])
	draw_colored_polygon(left_face, wood.darkened(0.05))
	draw_colored_polygon(right_face, wood.darkened(0.3))
	# Planches : lignes horizontales (parallèles au sol iso)
	var y := 6.0
	while y < h:
		draw_line(w + Vector2(0, -y), s + Vector2(0, -y), dark.lightened(0.15), 1.0)
		draw_line(s + Vector2(0, -y), e + Vector2(0, -y), dark, 1.0)
		y += 6.0
	draw_polyline(PackedVector2Array([w, s, e]), dark, 1.5)
	draw_line(w, w + up, dark, 1.5)
	draw_line(s, s + up, dark, 1.5)
	draw_line(e, e + up, dark, 1.5)
	if k >= 1.0:
		# Porte sur la face sud-ouest, petite fenêtre sur la face sud-est
		var d0 := w.lerp(s, 0.45)
		var d1 := w.lerp(s, 0.68)
		draw_colored_polygon(PackedVector2Array([d0, d1, d1 + Vector2(0, -24), d0 + Vector2(0, -24)]), Color(0.2, 0.13, 0.07))
		draw_polyline(PackedVector2Array([d0, d0 + Vector2(0, -24), d1 + Vector2(0, -24), d1]), dark, 1.5)
		var f0 := s.lerp(e, 0.4) + Vector2(0, -14)
		var f1 := s.lerp(e, 0.62) + Vector2(0, -14)
		draw_colored_polygon(PackedVector2Array([f0, f1, f1 + Vector2(0, -10), f0 + Vector2(0, -10)]), Color(0.95, 0.75, 0.35, 0.8))
		draw_polyline(PackedVector2Array([f0, f1, f1 + Vector2(0, -10), f0 + Vector2(0, -10), f0]), dark, 1.5)
		var damage := 1.0 - hp / max_hp
		if damage > 0.4:
			draw_line(w.lerp(s, 0.2) + Vector2(0, -20), w.lerp(s, 0.3) + Vector2(0, -8), dark, 2.0)


## Toit à deux pans en palmes et planches, hauteur `k` (0 → 1).
func _draw_roof(k: float) -> void:
	var dark := Color(0.2, 0.25, 0.12)
	var thatch := _flash_color(Color(0.48, 0.55, 0.26))
	var up := Vector2(0, -WALL_H)
	var n := Vector2(0, -CHH) + up
	var e := Vector2(CHW, 0) + up
	var s := Vector2(0, CHH) + up
	var w := Vector2(-CHW, 0) + up
	# Faîtage selon l'axe nord-ouest → sud-est (milieux des arêtes O-N et S-E)
	var ridge_a := w.lerp(n, 0.5) + Vector2(0, -ROOF_H * k)
	var ridge_b := s.lerp(e, 0.5) + Vector2(0, -ROOF_H * k)
	var over := 1.12   # débord du toit
	var c := (n + s) * 0.5
	var ww := c + (w - c) * over
	var ss := c + (s - c) * over
	var ee := c + (e - c) * over
	var nn := c + (n - c) * over
	# Pan arrière (nord-est) puis pan avant (sud-ouest)
	draw_colored_polygon(PackedVector2Array([nn, ridge_a, ridge_b, ee]), thatch.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([ww, ridge_a, ridge_b, ss]), thatch)
	# Pignon visible côté sud-est
	draw_colored_polygon(PackedVector2Array([ss, ridge_b, ee]), Color(0.5, 0.35, 0.2).darkened(0.25))
	for i in range(1, 6):
		var f := i / 6.0
		draw_line(ww.lerp(ss, f), ridge_a.lerp(ridge_b, f), dark.lightened(0.2), 1.0)
	draw_polyline(PackedVector2Array([ww, ridge_a, ridge_b, ss, ww]), dark, 1.5)
	draw_polyline(PackedVector2Array([ss, ee, ridge_b]), dark, 1.5)
