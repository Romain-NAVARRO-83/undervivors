class_name Survivor
extends CharacterBody2D
## Un survivant (voir GDD, section 5).
## - Sélectionné : déplacement au clavier, visée à la souris, tir au clic (maintenu).
## - Non sélectionné : erre autour du centre du village et tire en autonome.

signal died(survivor: Survivor)

const SPEED := 150.0
const WANDER_SPEED := 60.0
const XP_PER_LEVEL := 100

@export var max_hp: int = 100
var hp: int = 100
var xp: int = 0
var level: int = 1
var first_name: String = ""
var last_name: String = ""
var is_hero: bool = false
var weapon: WeaponData
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

## Monde (nœud trié en Y) où ajouter les projectiles.
var world: Node2D
var village_center: Vector2 = Vector2.ZERO
var wander_radius: float = 140.0
var aim_dir: Vector2 = Vector2.RIGHT

var _rng := RandomNumberGenerator.new()
var _wander_target: Vector2
var _wander_wait := 0.0
var _cooldown := 0.0
var _body_color := Color(0.3, 0.6, 0.9)


func _ready() -> void:
	_rng.randomize()
	collision_layer = 1   # survivants
	collision_mask = 2 | 4  # ennemis + obstacles (les survivants se traversent entre eux)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	if first_name.is_empty():
		first_name = NameGenerator.generate_part(_rng)["text"]
		last_name = NameGenerator.generate_part(_rng)["text"]
	if weapon == null:
		weapon = load("res://data/weapons/slingshot.tres")
	hp = max_hp
	_body_color = Color(0.95, 0.75, 0.2) if is_hero else Color.from_hsv(_rng.randf_range(0.5, 0.7), 0.5, 0.85)
	_pick_wander_target()


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func _physics_process(delta: float) -> void:
	_cooldown = max(_cooldown - delta, 0.0)
	if selected:
		_process_controlled()
	else:
		_process_autonomous(delta)
	move_and_slide()
	queue_redraw()


func _process_controlled() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * SPEED
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_dir = to_mouse.normalized()
	if Input.is_action_pressed("shoot"):
		try_shoot(aim_dir)


func _process_autonomous(delta: float) -> void:
	# Errance autour du centre du village.
	if _wander_wait > 0.0:
		_wander_wait -= delta
		velocity = Vector2.ZERO
	else:
		var to_target := _wander_target - global_position
		if to_target.length() < 6.0:
			velocity = Vector2.ZERO
			_wander_wait = _rng.randf_range(1.0, 3.0)
			_pick_wander_target()
		else:
			velocity = to_target.normalized() * WANDER_SPEED
	# Tir autonome sur l'ennemi le plus proche à portée.
	var target := _nearest_enemy()
	if target:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		aim_dir = dir
		try_shoot(dir)
	elif velocity.length() > 1.0:
		aim_dir = velocity.normalized()


func _pick_wander_target() -> void:
	var angle := _rng.randf() * TAU
	var dist := _rng.randf_range(20.0, wander_radius)
	_wander_target = village_center + Vector2(cos(angle), sin(angle) * 0.5) * dist


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_dist := weapon.max_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func try_shoot(dir: Vector2) -> void:
	if _cooldown > 0.0 or weapon == null or world == null:
		return
	_cooldown = weapon.cooldown()
	for i in weapon.bullets_per_shot:
		var offset := deg_to_rad(_rng.randf_range(-weapon.spread_deg, weapon.spread_deg) * 0.5)
		var p := Projectile.new()
		p.velocity = dir.rotated(offset) * weapon.projectile_speed
		p.damage = weapon.damage
		p.element = weapon.element
		p.element_damage = weapon.element_damage
		p.max_distance = weapon.max_range
		p.color = weapon.projectile_color
		p.shooter = self
		p.global_position = global_position + dir * 12.0 + Vector2(0, -10)
		world.add_child(p)


func equip(new_weapon: WeaponData) -> void:
	weapon = new_weapon


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= level * XP_PER_LEVEL:
		level += 1
		max_hp += 10
		hp = max_hp


func take_damage(amount: float) -> void:
	hp -= int(amount)
	if hp <= 0:
		died.emit(self)
		queue_free()  # mort définitive


func _draw() -> void:
	# Ombre
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.3))
	if selected:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Corps (placeholder)
	draw_circle(Vector2(0, -12), 9.0, _body_color)
	draw_circle(Vector2(0, -24), 6.0, _body_color.lightened(0.3))
	# Visée
	draw_line(Vector2(0, -12), Vector2(0, -12) + aim_dir * 18.0, Color(0.2, 0.15, 0.1), 3.0)
	# Barre de PV
	var w := 24.0
	draw_rect(Rect2(-w / 2, -38, w, 3), Color(0.2, 0, 0))
	draw_rect(Rect2(-w / 2, -38, w * float(hp) / max_hp, 3), Color(0.3, 0.9, 0.3))
