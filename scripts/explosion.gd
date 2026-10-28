class_name Explosion
extends Node2D
## Explosion (catapulte, mortier, munitions explosives) : dégâts de zone sur
## les monstres, les coffres et les mannequins, dégressifs vers le bord (100 %
## au centre, 40 % au bord). Ne blesse pas les survivants. Effet visuel : boule
## de feu, onde au sol, fumée, débris. Placeholder dessiné en code.

const DURATION := 0.55
const EDGE_FACTOR := 0.4

var radius := 60.0
var color := Color(1.0, 0.6, 0.2)
var _t := 0.0
var _debris: Array = []   # [direction, vitesse, taille]


## Fait exploser en `pos` (au sol). `ignore` est déjà touché par le tir direct.
static func blast(parent: Node, pos: Vector2, r: float, damage: float, element: int, element_damage: float,
		shooter: Node, col: Color, projectile: Projectile = null, ignore: Node = null) -> Explosion:
	if parent == null:
		return null
	var fx := Explosion.new()
	fx.radius = maxf(r, 20.0)
	fx.color = col
	fx.position = pos
	parent.add_child(fx)
	if r <= 0.0:
		return fx
	if not is_instance_valid(shooter):
		shooter = null
	var tree := parent.get_tree()
	var targets: Array = tree.get_nodes_in_group("mobs") + tree.get_nodes_in_group("chests") + tree.get_nodes_in_group("training_dummies")
	for body in targets:
		if body == ignore or not is_instance_valid(body):
			continue
		var d: float = Vector2(body.global_position.x - pos.x, (body.global_position.y - pos.y) * 2.0).length()
		if d > r:
			continue
		var k := lerpf(1.0, EDGE_FACTOR, d / r)
		if projectile:
			projectile.hit_body.emit(body, projectile)
		if body is Mob:
			if not body.is_alive():
				continue
			var killed: bool = body.take_hit(damage * k, element, element_damage * k, shooter)
			if killed and shooter and shooter.has_method("add_xp"):
				shooter.add_xp(body.xp_reward)
		elif body is LootChest:
			if not body.is_broken:
				body.take_damage((damage + element_damage) * k, element)
		elif body.has_method("take_damage"):
			body.take_damage((damage + element_damage) * k, element)
	return fx


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	var n := 12
	for i in n:
		var a := TAU * i / n + randf_range(-0.2, 0.2)
		_debris.append([Vector2(cos(a), sin(a) * 0.55), randf_range(0.6, 1.1), randf_range(1.5, 3.0)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var fade := 1.0 - k
	# Onde au sol, à la taille de la zone touchée
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, radius * ease(k, 0.3), Color(color, 0.18 * fade))
	draw_arc(Vector2.ZERO, radius * ease(k, 0.3), 0.0, TAU, 40, Color(1, 0.9, 0.7, 0.8 * fade), 3.0 * fade + 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Boule de feu, puis fumée qui monte
	if k < 0.4:
		var f := 1.0 - k / 0.4
		draw_circle(Vector2(0, -8), radius * 0.35 * (0.6 + k), Color(1.0, 0.95, 0.7, f))
		draw_circle(Vector2(0, -10), radius * 0.5 * (0.5 + k), Color(color, 0.8 * f))
	for i in 3:
		var c := Vector2((i - 1) * radius * 0.2, -14.0 - k * 40.0 - i * 6.0)
		draw_circle(c, radius * (0.15 + 0.25 * k), Color(0.3, 0.3, 0.3, 0.45 * fade))
	# Débris projetés
	for d in _debris:
		var p: Vector2 = d[0] * radius * d[1] * ease(k, 0.4) + Vector2(0, -30.0 * sin(k * PI) * d[1])
		draw_circle(p, d[2], Color(0.25, 0.2, 0.15, fade))
