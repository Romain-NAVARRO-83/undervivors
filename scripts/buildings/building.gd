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


## Forme de collision : un losange de la taille d'une case (surchargeable).
func _make_shape() -> Shape2D:
	var poly := ConvexPolygonShape2D.new()
	poly.points = PackedVector2Array([Vector2(0, -15), Vector2(30, 0), Vector2(0, 15), Vector2(-30, 0)])
	return poly


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
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 26.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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


## Hauteur visuelle du sommet (pour placer les barres).
func _top() -> float:
	return 30.0


## Chantier : contour au sol et échafaudage qui monte avec l'avancement.
func _draw_scaffold() -> void:
	var base := PackedVector2Array([Vector2(0, -15), Vector2(30, 0), Vector2(0, 15), Vector2(-30, 0), Vector2(0, -15)])
	draw_polyline(base, Color(0.95, 0.8, 0.4, 0.8), 1.5)
	var h := _top() * progress
	var wood := Color(0.6, 0.45, 0.28)
	for x in [-18, 0, 18]:
		draw_line(Vector2(x, 4), Vector2(x, 4 - h), wood, 2.0)
	if h > 10:
		draw_line(Vector2(-18, 4 - h * 0.5), Vector2(18, 4 - h * 0.5), wood, 2.0)
		draw_line(Vector2(-18, 4), Vector2(18, 4 - h), wood.darkened(0.2), 1.5)


## Construction finie : à surcharger.
func _draw_built() -> void:
	pass


func _flash_color(c: Color) -> Color:
	return Color.WHITE if _flash > 0.0 else c
