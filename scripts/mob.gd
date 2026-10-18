class_name Mob
extends CharacterBody2D
## Monstre de base (placeholder de créature). Pour l'instant il ne fait PAS de
## dégâts : il se jette sur sa cible sans la blesser. Deux comportements :
## - Vague : chasse le survivant le plus proche, sinon marche vers le village.
## - Posté (`posted = true`) : erre autour de `home` ; poursuit un survivant qui
##   s'approche, mais abandonne au-delà de `leash_range` de chez lui et y revient.

signal died(mob: Mob)

@export var max_hp: float = 30.0
@export var speed: float = 70.0
@export var aggro_range: float = 420.0
var xp_reward: int = 20
var hp: float = 30.0
var village_center := Vector2.ZERO

## Ennemi posté (GDD : ennemis placés sur la carte et issus des générateurs).
var posted := false
var home := Vector2.ZERO
@export var wander_radius: float = 70.0
@export var leash_range: float = 340.0
var _wander_target := Vector2.ZERO
var _wander_wait := 0.0
var chasing := false

var _alive := true
var _flash := 0.0
var _t := 0.0
var _lunge := 0.0
var _lunge_cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _hue := 0.0


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	add_to_group("mobs")
	collision_layer = 2   # touché par les projectiles
	collision_mask = 4    # obstacles seulement (traverse les survivants)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	shape.position = Vector2(0, -8)
	add_child(shape)
	hp = max_hp
	_t = _rng.randf() * 10.0
	_hue = _rng.randf_range(0.72, 0.85)


func is_alive() -> bool:
	return _alive


## Retourne true si le coup a tué le monstre.
func take_damage(amount: float, _element := 0) -> bool:
	if not _alive:
		return false
	hp -= amount
	_flash = 0.1
	_spawn_damage_number(amount)
	if hp <= 0.0:
		_die()
		return true
	return false


func _die() -> void:
	_alive = false
	died.emit(self)
	set_physics_process(false)
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 0.2), 0.18)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _physics_process(delta: float) -> void:
	_t += delta
	_lunge = maxf(_lunge - delta, 0.0)
	_lunge_cooldown -= delta
	if posted:
		_process_posted(delta)
		return
	var target := _nearest_survivor()
	var goal: Vector2 = target.global_position if target else village_center
	var to_goal := goal - global_position
	var dist := to_goal.length()
	var to_way := Terrain.route(global_position, goal) - global_position
	var dir := to_way / maxf(to_way.length(), 0.001)
	if target and dist < 20.0:
		# Au contact : bond d'attaque, sans dégâts pour l'instant.
		velocity = Vector2.ZERO
		if _lunge_cooldown <= 0.0:
			_lunge = 0.25
			_lunge_cooldown = 1.2
	elif dist > 8.0:
		velocity = dir * speed + _separation() * 40.0
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	queue_redraw()


func _process_posted(delta: float) -> void:
	var target := _nearest_survivor()
	# Poursuite limitée : la cible doit rester à portée de laisse de chez lui.
	if target and target.global_position.distance_to(home) > leash_range:
		target = null
	if global_position.distance_to(home) > leash_range + 40.0:
		target = null  # trop loin : il rentre, même s'il voit quelqu'un
	chasing = target != null
	if target:
		var to_t: Vector2 = target.global_position - global_position
		if to_t.length() < 20.0:
			velocity = Vector2.ZERO
			if _lunge_cooldown <= 0.0:
				_lunge = 0.25
				_lunge_cooldown = 1.2
		else:
			velocity = (Terrain.route(global_position, target.global_position) - global_position).normalized() * speed + _separation() * 40.0
	elif global_position.distance_to(home) > wander_radius + 12.0:
		# Retour au point d'attache
		velocity = (Terrain.route(global_position, home) - global_position).normalized() * speed * 0.9
		_wander_wait = 0.0
	else:
		# Errance sur une petite distance
		if _wander_wait > 0.0:
			_wander_wait -= delta
			velocity = Vector2.ZERO
		else:
			var to_w := _wander_target - global_position
			if _wander_target == Vector2.ZERO or to_w.length() < 5.0:
				var a := _rng.randf() * TAU
				_wander_target = home + Vector2(cos(a), sin(a) * 0.55) * _rng.randf_range(10.0, wander_radius)
				_wander_wait = _rng.randf_range(0.8, 2.5)
				velocity = Vector2.ZERO
			else:
				velocity = to_w.normalized() * speed * 0.45
	move_and_slide()
	queue_redraw()


func _nearest_survivor() -> Node2D:
	var best: Node2D = null
	var best_d := aggro_range
	for s in get_tree().get_nodes_in_group("survivors"):
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


## Évite que les monstres s'empilent.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	for m in get_tree().get_nodes_in_group("mobs"):
		if m == self:
			continue
		var d: Vector2 = global_position - m.global_position
		var l := d.length()
		if l > 0.01 and l < 18.0:
			push += d / l * (18.0 - l) / 18.0
	return push


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta


func _spawn_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = str(int(round(amount)))
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 11)
	label.position = Vector2(_rng.randf_range(-10, 4), -40)
	label.z_index = 10
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 18, 0.5)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


func _draw() -> void:
	var wobble := sin(_t * 9.0) * 1.5
	var hop := -absf(sin(_t * 9.0)) * 2.0 - _lunge * 18.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := Color.from_hsv(_hue, 0.55, 0.45)
	if _flash > 0.0:
		body = Color.WHITE
	var c := Vector2(0, -10 + hop)
	# Corps en goutte, petites cornes
	draw_set_transform(c, 0.0, Vector2(1.0 + wobble * 0.03, 1.0 - wobble * 0.03))
	draw_circle(Vector2.ZERO, 10.0, body)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -6), Vector2(-4, -15), Vector2(-2, -7)]), body.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(7, -6), Vector2(4, -15), Vector2(2, -7)]), body.darkened(0.3))
	# Yeux jaunes et sourire plein de dents
	draw_circle(Vector2(-3.5, -2), 2.6, Color(1, 0.85, 0.2))
	draw_circle(Vector2(3.5, -2), 2.6, Color(1, 0.85, 0.2))
	draw_circle(Vector2(-3.5, -2), 1.1, Color(0.1, 0.05, 0.05))
	draw_circle(Vector2(3.5, -2), 1.1, Color(0.1, 0.05, 0.05))
	draw_arc(Vector2(0, 2), 5.0, 0.15 * PI, 0.85 * PI, 10, Color(0.1, 0.05, 0.05), 2.0)
	for k in 3:
		var x := -3.0 + k * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1, 5.5), Vector2(x + 1, 5.5), Vector2(x, 7.5)]), Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# PV
	if hp < max_hp:
		draw_rect(Rect2(-11, -30 + hop, 22, 3), Color(0.2, 0, 0))
		draw_rect(Rect2(-11, -30 + hop, 22 * hp / max_hp, 3), Color(0.9, 0.3, 0.3))
