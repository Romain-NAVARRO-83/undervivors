class_name Turret
extends Building
## Tourelle : plateforme en bois avec une arbalète lourde. Elle ne tire que
## si un survivant y est assigné et à son poste (GDD 10). Le servant gagne
## l'XP des monstres abattus.

const COST := 6
const FIRE_RANGE := 430.0
const DAMAGE := 14.0
const FIRE_RATE := 2.0

static var _counter := 0
var number := 0
var gunner: Survivor = null
var aim_dir := Vector2.RIGHT
var _cooldown := 0.0
var world: Node2D


func _init() -> void:
	display_name = "Tourelle"
	cost = COST
	build_time = 8.0
	max_hp = 160.0
	_counter += 1
	number = _counter
	display_name = "Tourelle n°%d" % number


func _ready() -> void:
	super._ready()
	add_to_group("turrets")


func _top() -> float:
	return 52.0


## Point où se tient le servant (sur la plateforme).
func mount_point() -> Vector2:
	return global_position + Vector2(0, 2)


func is_manned() -> bool:
	return is_built and is_instance_valid(gunner) and gunner.post == self and gunner.manning


func contains(world_pos: Vector2) -> bool:
	return global_position.distance_to(world_pos + Vector2(0, 20)) < 30.0


func _process(delta: float) -> void:
	super._process(delta)
	if gunner != null and (not is_instance_valid(gunner) or gunner.post != self):
		gunner = null
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not is_manned():
		return
	var target := _nearest_enemy()
	if target == null:
		return
	aim_dir = (target.global_position - global_position).normalized()
	if _cooldown <= 0.0:
		_cooldown = 1.0 / FIRE_RATE
		var p := Projectile.new()
		p.velocity = aim_dir * 720.0
		p.damage = DAMAGE
		p.max_distance = FIRE_RANGE + 20.0
		p.color = Color(0.9, 0.8, 0.55)
		p.shooter = gunner  # l'XP revient au servant
		p.global_position = global_position + Vector2(0, -40) + aim_dir * 14.0
		(world if world else get_parent()).add_child(p)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := FIRE_RANGE
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _destroy() -> void:
	if is_instance_valid(gunner) and gunner.post == self:
		gunner.assign_post(null)
	super._destroy()


func _draw_built() -> void:
	var wood := _flash_color(Color(0.52, 0.36, 0.2))
	var dark := Color(0.3, 0.2, 0.12)
	# Quatre pieds
	for x in [-16, 16]:
		draw_line(Vector2(x, 6), Vector2(x * 0.7, -30), dark, 4.0)
	for x in [-8, 8]:
		draw_line(Vector2(x, -6), Vector2(x * 0.9, -30), wood.darkened(0.15), 3.0)
	draw_line(Vector2(-14, -12), Vector2(14, -22), dark, 2.0)
	draw_line(Vector2(14, -12), Vector2(-14, -22), dark, 2.0)
	# Plateforme
	var plat := PackedVector2Array([Vector2(0, -38), Vector2(20, -30), Vector2(0, -22), Vector2(-20, -30)])
	draw_colored_polygon(plat, wood)
	draw_polyline(plat + PackedVector2Array([plat[0]]), dark, 1.5)
	# Arbalète lourde orientée vers la cible
	var c := Vector2(0, -40)
	draw_line(c, c + aim_dir * 16.0, Color(0.25, 0.25, 0.27), 4.0)
	var perp := Vector2(-aim_dir.y, aim_dir.x)
	draw_line(c + aim_dir * 10.0 + perp * 8.0, c + aim_dir * 10.0 - perp * 8.0, dark, 2.0)
	# Numéro, et voyant : vert = servie, gris = sans servant
	draw_circle(Vector2(18, -46), 4.0, Color(0.4, 0.9, 0.4) if is_manned() else Color(0.45, 0.45, 0.45))
	draw_string(ThemeDB.fallback_font, Vector2(-22, -44), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.85))
