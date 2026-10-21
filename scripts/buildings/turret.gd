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


var _release_btn: Button


func _ready() -> void:
	super._ready()
	add_to_group("turrets")
	# Bouton au-dessus de la tourelle pour libérer le servant.
	_release_btn = UIStyle.button("Libérer", 10)
	_release_btn.visible = false
	_release_btn.z_index = 30
	_release_btn.focus_mode = Control.FOCUS_NONE
	_release_btn.tooltip_text = "Dissocier le servant de cette tourelle"
	_release_btn.pressed.connect(release_gunner)
	add_child(_release_btn)


## Dissocie le servant de la tourelle (il redescend et retourne errer au camp).
func release_gunner() -> void:
	if is_instance_valid(gunner) and gunner.post == self:
		gunner.assign_post(null)
	gunner = null


func _update_release_button() -> void:
	var show := is_instance_valid(gunner) and gunner.post == self and not is_destroyed and not BuildManager.placing
	_release_btn.visible = show
	if show:
		_release_btn.text = "Libérer %s" % gunner.first_name
		_release_btn.reset_size()
		_release_btn.position = Vector2(-_release_btn.size.x / 2.0, -_top() - 26.0)


func block_height() -> float:
	return 24.0


func _top() -> float:
	return block_height() + HH + 22.0


## Point où se tient le servant : juste devant la tourelle, au pied du bloc
## (le bloc occupe la tuile ; le servant reste visible devant).
func mount_point() -> Vector2:
	return global_position + Vector2(0, HH + 12.0)


## Point où se tient le servant une fois monté sur la plateforme.
func top_point() -> Vector2:
	return global_position + Vector2(-6, -block_height() + 2.0)


func is_manned() -> bool:
	return is_built and is_instance_valid(gunner) and gunner.post == self and gunner.manning


func _process(delta: float) -> void:
	super._process(delta)
	if gunner != null and (not is_instance_valid(gunner) or gunner.post != self):
		gunner = null
	_cooldown = maxf(_cooldown - delta, 0.0)
	_update_release_button()
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
		p.global_position = global_position + Vector2(0, -block_height() - 6.0) + aim_dir * 16.0
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


## Bloc isométrique sur une tuile : socle en pierres, plateforme en planches,
## arbalète lourde orientée vers la cible.
func _draw_built() -> void:
	var h := block_height()
	var stone := _flash_color(Color(0.5, 0.48, 0.44))
	var dark := Color(0.2, 0.19, 0.18)
	var top := draw_iso_block(h, Color(0.55, 0.38, 0.22), stone.darkened(0.05), stone.darkened(0.25), dark)
	# Joints de pierre sur les faces
	for row in range(1, 3):
		var y := -h * row / 3.0
		draw_line(Vector2(-HW, y), Vector2(0, HH + y), dark.lightened(0.15), 1.0)
		draw_line(Vector2(0, HH + y), Vector2(HW, y), dark, 1.0)
	for k in range(1, 4):
		var off := 0.0 if k % 2 == 0 else 0.5
		var pl := Vector2(-HW, 0).lerp(Vector2(0, HH), (k + off * 0.5) / 4.0)
		draw_line(pl + Vector2(0, -h / 3.0), pl + Vector2(0, -2.0 * h / 3.0), dark.lightened(0.15), 1.0)
		var pr := Vector2(0, HH).lerp(Vector2(HW, 0), (k - off * 0.5) / 4.0)
		draw_line(pr, pr + Vector2(0, -h / 3.0), dark, 1.0)
	# Planches du dessus
	for k in range(1, 4):
		var a: Vector2 = top[0].lerp(top[3], k / 4.0)
		var b: Vector2 = top[1].lerp(top[2], k / 4.0)
		draw_line(a, b, Color(0.35, 0.24, 0.14), 1.0)
	# Arbalète lourde sur pivot, au centre du dessus
	var c := Vector2(0, -h - 6)
	draw_line(Vector2(0, -h), c, dark, 3.0)
	draw_line(c - aim_dir * 6.0, c + aim_dir * 16.0, Color(0.3, 0.22, 0.14), 4.0)
	var perp := Vector2(-aim_dir.y, aim_dir.x)
	var bow := c + aim_dir * 11.0
	draw_polyline(PackedVector2Array([bow + perp * 9.0, bow + aim_dir * 3.0, bow - perp * 9.0]), Color(0.2, 0.18, 0.16), 2.0)
	# Numéro et voyant : vert = servie, gris = sans servant
	var lamp := Vector2(HW - 6, -h - 8)
	draw_circle(lamp, 4.0, dark)
	draw_circle(lamp, 3.0, Color(0.4, 0.95, 0.4) if is_manned() else Color(0.5, 0.5, 0.5))
	draw_string_outline(ThemeDB.fallback_font, Vector2(-HW + 2, -h - 4), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
	draw_string(ThemeDB.fallback_font, Vector2(-HW + 2, -h - 4), str(number), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
