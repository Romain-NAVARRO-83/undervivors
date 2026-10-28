class_name Projectile
extends Area2D
## Projectile tiré par un survivant. Touche les corps de la couche « ennemis »
## et s'arrête sur les obstacles. Selon l'arme (voir WeaponData) il peut :
## traverser des ennemis, rebondir sur les obstacles, chercher sa cible,
## onduler, se diviser à l'impact, exploser, revenir comme un boomerang,
## soigner le tireur, ou voler en cloche jusqu'au point visé (catapulte,
## mortier) pour exploser au sol.

## Émis au contact, avant d'appliquer les dégâts (statistiques du champ de tir).
signal hit_body(body: Node, projectile: Projectile)

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var element: WeaponData.Element = WeaponData.Element.AUCUN
var element_damage: float = 0.0
var max_distance: float = 360.0
var color: Color = Color.WHITE
var shooter: Node = null

## Effets (recopiés de l'arme par le tireur)
var pierce := 0
var ricochet := 0
var homing := 0.0
var wave := 0.0
var split := 0
var vampire := 0.0
var boomerang := false
var aoe_radius := 0.0
var size_k := 1.0
var fish := false
## Éclat issu d'une division (ne se redivise pas, ne compte pas comme un tir).
var is_fragment := false
## Tir en cloche : point d'arrivée au sol (pieds), hauteur de la cloche.
var lob := false
var lob_target := Vector2.ZERO

## Rayon de la zone de touche (plus large que la balle dessinée, pour
## pardonner une visée approximative).
const HIT_RADIUS := 8.0
## La balle vole à hauteur de buste (10 px au-dessus du sol) mais les
## monstres ont leur zone de touche aux pieds : on recale la zone vers le bas.
const HIT_DROP := 8.0
const HOMING_RANGE := 260.0
const WAVE_LENGTH := 70.0
const LOB_HEIGHT_PER_PX := 0.35
const BOOMERANG_TURN := 7.0     # rad/s

var _travelled := 0.0
var _done := false
var _hit := {}              # corps déjà touchés (perforation, boomerang)
var _base_pos := Vector2.ZERO
var _returning := false
var _lob_start := Vector2.ZERO
var _lob_t := 0.0
var _lob_time := 1.0
var _spin := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4  # ennemis + obstacles (les rochers arrêtent les tirs)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS * maxf(size_k, 1.0)
	shape.shape = circle
	shape.position = Vector2(0, HIT_DROP)
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_base_pos = position
	if lob:
		# En vol au-dessus de tout : il ne touche rien avant d'atterrir.
		monitoring = false
		_lob_start = position + Vector2(0, 10)   # aux pieds du tireur
		var dist := _lob_start.distance_to(lob_target)
		_lob_time = maxf(dist / maxf(velocity.length(), 1.0), 0.25)
	z_index = 5 if lob else 0


func _physics_process(delta: float) -> void:
	_spin += delta * 12.0
	if lob:
		_process_lob(delta)
		return
	if homing > 0.0:
		var target := _homing_target()
		if target:
			var want: Vector2 = (target.global_position + Vector2(0, -10) - global_position).normalized()
			var ang := velocity.angle_to(want)
			velocity = velocity.rotated(clampf(ang, -homing * delta, homing * delta))
	var step := velocity * delta
	_base_pos += step
	_travelled += step.length()
	if wave > 0.0:
		var perp := velocity.normalized().orthogonal()
		position = _base_pos + perp * sin(_travelled / WAVE_LENGTH * TAU) * wave
	else:
		position = _base_pos
	if boomerang:
		if not _returning and _travelled >= max_distance * 0.55:
			_returning = true
			_hit.clear()   # il peut retoucher au retour
		if _returning and is_instance_valid(shooter):
			# Demi-tour en arc (vitesse constante), puis cap sur le tireur
			var back: Vector2 = shooter.global_position + Vector2(0, -10) - _base_pos
			var turn := velocity.angle_to(back)
			velocity = velocity.rotated(clampf(turn, -BOOMERANG_TURN * delta, BOOMERANG_TURN * delta))
			if back.length() < 18.0:
				queue_free()
		if _travelled >= max_distance * 2.5:
			queue_free()
		queue_redraw()
		return
	if _travelled >= max_distance:
		queue_free()
	if fish or size_k > 1.2:
		queue_redraw()


func _process_lob(delta: float) -> void:
	_lob_t += delta / _lob_time
	var t := minf(_lob_t, 1.0)
	var ground := _lob_start.lerp(lob_target, t)
	var h := 4.0 * _lob_start.distance_to(lob_target) * LOB_HEIGHT_PER_PX * t * (1.0 - t)
	position = ground + Vector2(0, -10.0 - h)
	queue_redraw()
	if t >= 1.0:
		_done = true
		set_physics_process(false)
		Explosion.blast(get_parent(), lob_target, aoe_radius, damage, element, element_damage, shooter, color, self)
		queue_free()


## Normale de l'obstacle touché : rayon lancé le long du tir, au niveau de la
## zone de touche (rochers, arbres, bords de carte…).
func _surface_normal() -> Vector2:
	var dir := velocity.normalized()
	var from := global_position + Vector2(0, HIT_DROP) - dir * (HIT_RADIUS + velocity.length() / 30.0)
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * (HIT_RADIUS * 3.0 + velocity.length() / 30.0), 4)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return -dir
	return hit["normal"]


func _homing_target() -> Node2D:
	var best: Node2D = null
	var best_d := HOMING_RANGE
	var fwd := velocity.normalized()
	for m in get_tree().get_nodes_in_group("enemies"):
		if _hit.has(m) or (m.has_method("is_alive") and not m.is_alive()):
			continue
		var to: Vector2 = m.global_position - global_position
		var d := to.length()
		if d < best_d and fwd.dot(to / maxf(d, 0.01)) > 0.2:
			best_d = d
			best = m
	return best


func _on_body_entered(body: Node) -> void:
	if _done or _hit.has(body):
		return
	if not is_instance_valid(shooter):
		shooter = null   # le tireur est mort pendant que la balle volait
	var damageable := body is Mob or body is LootChest or body.has_method("take_damage")
	# Obstacle : rebond s'il en reste, sinon le tir s'arrête
	if not damageable:
		if ricochet > 0:
			ricochet -= 1
			var n := _surface_normal()
			velocity = velocity.bounce(n) if velocity.dot(n) < 0.0 else -velocity
			_base_pos = global_position - velocity.normalized() * 2.0 + velocity.normalized() * 8.0
			HitEffect.spawn(get_parent(), global_position, color, HitEffect.Kind.DUST, velocity)
			return
		_finish(body)
		return
	_hit[body] = true
	hit_body.emit(body, self)
	_impact(body)
	var dealt := 0.0
	if body is Mob:
		# Les monstres gèrent la part élémentaire (résistances, effets).
		var before: float = body.hp
		var killed_mob: bool = body.take_hit(damage, element, element_damage, shooter)
		dealt = maxf(before - body.hp, 0.0)
		if killed_mob and is_instance_valid(shooter) and shooter.has_method("add_xp"):
			shooter.add_xp(body.xp_reward)
	elif body is LootChest:
		# Le leader d'escouade tire sur un coffre : toute l'escouade s'y met.
		if shooter is Survivor and shooter.selected and shooter.squad_member:
			Survivor.squad_focus = body
		body.take_damage(damage + element_damage, element)
	elif body.has_method("take_damage"):
		dealt = damage + element_damage
		var killed: bool = body.take_damage(damage + element_damage, element)
		if killed and is_instance_valid(shooter) and shooter.has_method("add_xp"):
			shooter.add_xp(body.get("xp_reward") if body.get("xp_reward") != null else 10)
	if vampire > 0.0 and dealt > 0.0 and shooter is Survivor:
		shooter.heal(dealt * vampire)
	if body is Mob and pierce > 0:
		pierce -= 1
		return   # il continue sa route
	if boomerang and not _returning:
		_returning = true
		return
	_finish(body)


## Fin de course : explosion, éclats, puis disparition.
func _finish(body: Node) -> void:
	_done = true
	if body != null and not (body is Mob or body is LootChest or body.has_method("take_damage")):
		_impact(body)
	if aoe_radius > 0.0:
		Explosion.blast(get_parent(), global_position + Vector2(0, 10), aoe_radius, damage * 0.6, element, element_damage * 0.6, shooter, color, self, body)
	if split > 0 and not is_fragment:
		_spawn_fragments(body)
	set_deferred("monitoring", false)
	queue_free()


func _spawn_fragments(from_body: Node) -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in split:
		var f := Projectile.new()
		var ang := TAU * i / split + randf_range(-0.3, 0.3)
		f.velocity = velocity.rotated(ang) * 0.75
		f.damage = damage * 0.4
		f.element = element
		f.element_damage = element_damage * 0.4
		f.max_distance = 90.0
		f.color = color.lightened(0.2)
		f.shooter = shooter
		f.is_fragment = true
		f.size_k = 0.7
		if from_body:
			f._hit[from_body] = true
		f.position = global_position
		parent.add_child.call_deferred(f)


## Animation d'impact au point de contact.
func _impact(body: Node) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var kind := HitEffect.Kind.DUST
	if body is Mob:
		kind = HitEffect.Kind.CREATURE
	elif body is LootChest or body is Building or body.is_in_group("hit_wood"):
		kind = HitEffect.Kind.WOOD
	HitEffect.spawn(parent, global_position, color, kind, velocity)


func _draw() -> void:
	var r := 3.0 * size_k
	if lob:
		# Ombre au sol, qui guide l'œil vers le point d'impact
		var ground := _lob_start.lerp(lob_target, minf(_lob_t, 1.0)) - position
		draw_set_transform(ground, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 6.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 6.0 * size_k, color.darkened(0.4))
		draw_circle(Vector2(-1.5, -1.5), 4.0 * size_k, color)
		return
	if fish:
		var a := velocity.angle()
		draw_set_transform(Vector2.ZERO, a, Vector2(size_k, size_k))
		draw_colored_polygon(PackedVector2Array([Vector2(7, 0), Vector2(1, -4), Vector2(-5, -2), Vector2(-5, 2), Vector2(1, 4)]), Color(0.55, 0.7, 0.85))
		draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-10, -4 + sin(_spin) * 1.5), Vector2(-10, 4 + sin(_spin) * 1.5)]), Color(0.45, 0.6, 0.75))
		draw_circle(Vector2(4, -1), 1.0, Color.BLACK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	if boomerang:
		draw_set_transform(Vector2.ZERO, _spin, Vector2.ONE)
		draw_line(Vector2(-5, -3) * size_k, Vector2(0, 2) * size_k, color, 2.5)
		draw_line(Vector2(0, 2) * size_k, Vector2(5, -3) * size_k, color, 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	draw_circle(Vector2.ZERO, r, color)
	if size_k > 1.2:
		draw_circle(Vector2(-r * 0.3, -r * 0.3), r * 0.4, color.lightened(0.4))
