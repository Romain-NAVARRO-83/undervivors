class_name Building
extends StaticBody2D
## Construction posée par le joueur (GDD 10) : un chantier qui se monte tout
## seul en `build_time` secondes, puis une construction finie. Elle bloque les
## monstres (couche « constructions ») mais pas les survivants (portes).
## Elle peut être abîmée puis détruite.

signal built(building: Building)
signal destroyed(building: Building)

const LAYER := 8  # couche physique « constructions »

var display_name := "Construction"
var cost := 0
var build_time := 4.0
var max_hp := 100.0
var hp := 100.0
var progress := 0.0          # 0 → 1 pendant le chantier
var is_built := false
var is_destroyed := false
var tile := Vector2i.ZERO    # case de la grille iso occupée
var _flash := 0.0


func _ready() -> void:
	add_to_group("buildings")
	collision_layer = LAYER
	collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.shape = _make_shape()
	add_child(shape)
	hp = max_hp * 0.25  # un chantier est fragile ; les PV montent avec l'avancement


## Demi-dimensions du losange d'une tuile (64 × 32).
const HW := IsoGround.TILE_W / 2.0
const HH := IsoGround.TILE_H / 2.0


## Forme de collision : exactement le losange de la tuile.
func _make_shape() -> Shape2D:
	var poly := ConvexPolygonShape2D.new()
	poly.points = PackedVector2Array([Vector2(0, -HH), Vector2(HW, 0), Vector2(0, HH), Vector2(-HW, 0)])
	return poly


## Vrai si le point touche (ou presque) le losange de la tuile : sert à savoir
## si un monstre est au contact, quel que soit le côté.
func is_touching(p: Vector2, margin := 12.0) -> bool:
	var d := p - global_position
	return absf(d.x) / (HW + margin) + absf(d.y) / (HH + margin * 0.6) <= 1.0


## Vrai si le point (souris) est sur le bloc, hauteur comprise.
func contains(world_pos: Vector2) -> bool:
	var d := world_pos - global_position
	return absf(d.x) / HW + absf(d.y + block_height() * 0.5) / (HH + block_height() * 0.5) <= 1.0


## Hauteur du bloc (petite : la construction reste lisible en vue iso).
func block_height() -> float:
	return 16.0


## Dessine un bloc isométrique sur l'empreinte d'une tuile, de hauteur `h`.
## Retourne les sommets du dessus [N, E, S, O] pour y ajouter des détails.
func draw_iso_block(h: float, top: Color, left: Color, right: Color, outline: Color) -> PackedVector2Array:
	var n := Vector2(0, -HH)
	var e := Vector2(HW, 0)
	var s := Vector2(0, HH)
	var w := Vector2(-HW, 0)
	var up := Vector2(0, -h)
	var left_face := PackedVector2Array([w, s, s + up, w + up])
	var right_face := PackedVector2Array([s, e, e + up, s + up])
	var top_face := PackedVector2Array([n + up, e + up, s + up, w + up])
	draw_colored_polygon(left_face, left)
	draw_colored_polygon(right_face, right)
	draw_colored_polygon(top_face, top)
	draw_polyline(PackedVector2Array([w, s, e]), outline, 1.5)
	draw_polyline(PackedVector2Array([w, w + up, n + up, e + up, e]), outline, 1.5)
	draw_line(s, s + up, outline, 1.5)
	draw_polyline(PackedVector2Array([w + up, s + up, e + up]), outline, 1.5)
	return top_face


## Termine le chantier immédiatement (debug, tests).
func finish() -> void:
	if is_built:
		return
	progress = 1.0
	is_built = true
	hp = max_hp
	built.emit(self)
	queue_redraw()


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	if not is_built and not is_destroyed:
		var before := progress
		progress = minf(progress + delta / build_time, 1.0)
		hp = minf(hp + (progress - before) * max_hp * 0.75, max_hp)
		if progress >= 1.0:
			finish()
	queue_redraw()


## Appelé par les monstres. Retourne true si la construction est détruite.
func take_damage(amount: float, _element := 0) -> bool:
	if is_destroyed:
		return false
	hp -= amount
	_flash = 0.1
	if hp <= 0.0:
		_destroy()
		return true
	return false


func _destroy() -> void:
	is_destroyed = true
	remove_from_group("buildings")
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	destroyed.emit(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(queue_free)


func _draw() -> void:
	# Ombre portée : losange légèrement décalé
	draw_colored_polygon(PackedVector2Array([Vector2(4, -HH + 3), Vector2(HW + 5, 3), Vector2(4, HH + 3), Vector2(-HW + 5, 3)]), Color(0, 0, 0, 0.18))
	if is_built:
		_draw_built()
	else:
		_draw_scaffold()
	# PV (seulement s'ils ne sont pas pleins) et barre de chantier
	if is_built and hp < max_hp:
		draw_rect(Rect2(-18, -_top() - 10, 36, 4), Color(0.2, 0, 0))
		draw_rect(Rect2(-18, -_top() - 10, 36 * hp / max_hp, 4), Color(0.9, 0.35, 0.3))
	if not is_built:
		draw_rect(Rect2(-20, -_top() - 12, 40, 5), Color(0.1, 0.1, 0.1, 0.8))
		draw_rect(Rect2(-20, -_top() - 12, 40 * progress, 5), Color(0.95, 0.75, 0.3))


## Hauteur visuelle du sommet (pour placer les barres au-dessus).
func _top() -> float:
	return block_height() + HH + 6.0


## Chantier : empreinte au sol, puis une armature de bloc qui monte avec l'avancement.
func _draw_scaffold() -> void:
	var gold := Color(0.95, 0.8, 0.4, 0.85)
	var base := PackedVector2Array([Vector2(0, -HH), Vector2(HW, 0), Vector2(0, HH), Vector2(-HW, 0), Vector2(0, -HH)])
	draw_colored_polygon(PackedVector2Array([Vector2(0, -HH), Vector2(HW, 0), Vector2(0, HH), Vector2(-HW, 0)]), Color(0.95, 0.8, 0.4, 0.15))
	draw_polyline(base, gold, 1.5)
	var h := block_height() * progress
	var wood := Color(0.6, 0.45, 0.28)
	var up := Vector2(0, -h)
	for v in [Vector2(-HW, 0), Vector2(0, HH), Vector2(HW, 0), Vector2(0, -HH)]:
		draw_line(v, v + up, wood, 2.0)
	if h > 2.0:
		draw_polyline(PackedVector2Array([Vector2(-HW, 0) + up, Vector2(0, HH) + up, Vector2(HW, 0) + up, Vector2(0, -HH) + up, Vector2(-HW, 0) + up]), wood, 1.5)
		draw_line(Vector2(-HW, 0), Vector2(0, HH) + up, wood.darkened(0.2), 1.0)
		draw_line(Vector2(0, HH), Vector2(HW, 0) + up, wood.darkened(0.2), 1.0)


## Construction finie : à surcharger.
func _draw_built() -> void:
	pass


func _flash_color(c: Color) -> Color:
	return Color.WHITE if _flash > 0.0 else c
