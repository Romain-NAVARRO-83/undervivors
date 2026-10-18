class_name Survivor
extends CharacterBody2D
## Un survivant (voir GDD, section 5).
## - Sélectionné : déplacement au clavier, visée à la souris, tir au clic (maintenu).
## - Non sélectionné : erre autour du centre du village et tire en autonome.

signal died(survivor: Survivor)

const WANDER_SPEED := 60.0
const XP_PER_LEVEL := 100
## Valeur maximale affichée pour les stats (barres du panneau).
const STAT_MAX := 20
const HP_PER_POINT := 10

## Statistiques (GDD 5.1). Vitesse, précision et force vont de 1 à STAT_MAX.
@export var max_hp: int = 100
var hp: int = 100
var xp: int = 0
var level: int = 1
var speed_stat: int = 5
var accuracy: int = 5
var strength: int = 5
## Points gagnés en montant de niveau, à attribuer dans le panneau de gestion.
var stat_points: int = 0

var first_name: String = ""
var last_name: String = ""
var is_hero: bool = false
var appearance: SurvivorAppearance
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
	if appearance == null:
		appearance = SurvivorAppearance.random(_rng)
	speed_stat = _rng.randi_range(3, 8)
	accuracy = _rng.randi_range(3, 8)
	strength = _rng.randi_range(3, 8)
	if is_hero:
		speed_stat += 2
		accuracy += 2
		strength += 2
	hp = max_hp
	_body_color = appearance.shirt_color
	_pick_wander_target()


## Vitesse de déplacement en px/s : 150 pour une stat de 5.
func move_speed() -> float:
	return 110.0 + speed_stat * 8.0


## Multiplicateur de dispersion : 1 pour une précision de 5, plus serré au-delà.
func spread_factor() -> float:
	return clampf(1.3 - accuracy * 0.06, 0.2, 1.5)


## XP accumulée depuis le dernier niveau, et XP nécessaire pour le suivant.
func xp_in_level() -> int:
	return xp - (level - 1) * XP_PER_LEVEL


## Dépense un point de stat. `stat` : "pv_max", "vitesse", "precision" ou "force".
func spend_point(stat: String) -> bool:
	if stat_points <= 0:
		return false
	match stat:
		"pv_max":
			max_hp += HP_PER_POINT
			hp += HP_PER_POINT
		"vitesse":
			if speed_stat >= STAT_MAX: return false
			speed_stat += 1
		"precision":
			if accuracy >= STAT_MAX: return false
			accuracy += 1
		"force":
			if strength >= STAT_MAX: return false
			strength += 1
		_:
			return false
	stat_points -= 1
	return true


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
	velocity = input * move_speed()
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_dir = to_mouse.normalized()
	# Pas de tir quand la souris survole l'interface (panneau, boutons).
	if Input.is_action_pressed("shoot") and get_viewport().gui_get_hovered_control() == null:
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
		var spread := weapon.spread_deg * spread_factor()
		var offset := deg_to_rad(_rng.randf_range(-spread, spread) * 0.5)
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
		stat_points += 1  # le joueur choisit la stat (GDD 5.1)


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
	# Corps (placeholder) : vêtement + tête issue de l'apparence
	draw_circle(Vector2(0, -12), 9.0, _body_color)
	if is_hero:
		draw_arc(Vector2(0, -12), 9.0, 0.0, TAU, 20, Color(0.95, 0.75, 0.2), 2.0)
	SurvivorAppearance.draw_face(self, Vector2(0, -26), 7.0, appearance, false)
	# Visée
	draw_line(Vector2(0, -12), Vector2(0, -12) + aim_dir * 18.0, Color(0.2, 0.15, 0.1), 3.0)
	# Barre de PV
	var w := 24.0
	draw_rect(Rect2(-w / 2, -38, w, 3), Color(0.2, 0, 0))
	draw_rect(Rect2(-w / 2, -38, w * float(hp) / max_hp, 3), Color(0.3, 0.9, 0.3))
