class_name MobSpawner
extends StaticBody2D
## Générateur de bots : produit des ennemis postés autour de lui, à intervalle
## régulier, tant qu'il n'est pas détruit. Le détruire arrête définitivement la
## production ; la zone est sécurisée quand ses derniers ennemis sont morts.

signal destroyed(spawner: MobSpawner)
signal zone_secured(spawner: MobSpawner)

@export var max_hp: float = 220.0
## Secondes entre deux productions.
@export var spawn_interval: float = 7.0
## Nombre maximum de ses ennemis en vie en même temps.
@export var max_alive: int = 4
## Rayon de la zone qu'il contrôle (affichée au sol).
@export var zone_radius: float = 150.0
## PV rendus par seconde aux monstres présents dans sa zone.
@export var heal_per_second: float = 4.0
var xp_reward: int = 100
var hp: float = 220.0
var world: Node2D
var village_center := Vector2.ZERO
var is_destroyed := false
var is_secured := false

var _timer := 1.5
var _t := 0.0
var _flash := 0.0
var _pulse := 0.0
var _mobs: Array[Mob] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")   # les survivants lui tirent dessus d'eux-mêmes
	add_to_group("spawners")
	collision_layer = 2
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	shape.position = Vector2(0, -10)
	add_child(shape)
	hp = max_hp


func is_alive() -> bool:
	return not is_destroyed


func alive_mobs() -> int:
	var n := 0
	for m in _mobs:
		if is_instance_valid(m) and m.is_alive():
			n += 1
	return n


## Produit un ennemi posté près du générateur. Retourne null si la limite est atteinte.
func spawn_mob() -> Mob:
	if is_destroyed or alive_mobs() >= max_alive:
		return null
	var m := Mob.new()
	m.posted = true
	m.home = global_position
	m.wander_radius = zone_radius * 0.6
	m.leash_range = zone_radius * 2.2
	m.aggro_range = 220.0
	m.village_center = village_center
	var a := _rng.randf() * TAU
	m.position = position + Vector2(cos(a), sin(a) * 0.5) * 30.0
	m.died.connect(_on_mob_died)
	(world if world else get_parent()).add_child(m)
	_mobs.append(m)
	_pulse = 0.4
	return m


## Vrai si le point (monde) est dans la zone (ellipse isométrique).
func in_zone(p: Vector2) -> bool:
	var d := p - global_position
	return (d.x * d.x) / (zone_radius * zone_radius) + (d.y * d.y) / (zone_radius * zone_radius * 0.25) <= 1.0


## Les monstres dans la zone d'un générateur actif se soignent peu à peu.
func _heal_zone(delta: float) -> void:
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.is_alive() and m.hp < m.max_hp and in_zone(m.global_position):
			m.heal(heal_per_second * delta)


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
	remove_from_group("enemies")
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	destroyed.emit(self)
	_check_secured()


func _on_mob_died(_m: Mob) -> void:
	_check_secured()


func _check_secured() -> void:
	if is_destroyed and not is_secured and alive_mobs() == 0:
		is_secured = true
		zone_secured.emit(self)


func _process(delta: float) -> void:
	_t += delta
	_flash = maxf(_flash - delta, 0.0)
	_pulse = maxf(_pulse - delta, 0.0)
	if not is_destroyed:
		_timer -= delta
		if _timer <= 0.0:
			_timer = spawn_interval
			spawn_mob()
		_heal_zone(delta)
	queue_redraw()


func _draw() -> void:
	# Zone contrôlée, en pointillés au sol (rouge = active, vert = sécurisée)
	var zone_col := Color(0.9, 0.3, 0.3, 0.35)
	if is_secured:
		zone_col = Color(0.4, 0.9, 0.4, 0.35)
	elif is_destroyed:
		zone_col = Color(0.9, 0.7, 0.3, 0.3)
	for i in 24:
		var a0 := TAU * i / 24.0
		var a1 := a0 + TAU / 48.0
		draw_line(Vector2(cos(a0), sin(a0) * 0.5) * zone_radius, Vector2(cos(a1), sin(a1) * 0.5) * zone_radius, zone_col, 2.0)
	# Ombre et socle
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var metal := Color(0.28, 0.3, 0.34) if _flash <= 0.0 else Color.WHITE
	var dark := Color(0.15, 0.16, 0.19)
	var base := PackedVector2Array([Vector2(-20, -4), Vector2(0, -14), Vector2(20, -4), Vector2(0, 6)])
	draw_colored_polygon(base, dark)
	if is_destroyed:
		# Carcasse tordue, fumée
		draw_colored_polygon(PackedVector2Array([Vector2(-8, -6), Vector2(-2, -26), Vector2(4, -20), Vector2(10, -6)]), Color(0.22, 0.22, 0.24))
		draw_line(Vector2(-2, -26), Vector2(6, -34), dark, 2.0)
		for k in 3:
			var f := fmod(_t * 0.5 + k / 3.0, 1.0)
			draw_circle(Vector2(sin(_t + k) * 4.0, -28 - f * 30.0), 4.0 + f * 5.0, Color(0.4, 0.4, 0.42, 0.5 * (1.0 - f)))
		return
	# Pylône
	draw_colored_polygon(PackedVector2Array([Vector2(-10, -6), Vector2(-6, -44), Vector2(6, -44), Vector2(10, -6)]), metal)
	draw_line(Vector2(-6, -44), Vector2(-6, -6), dark, 1.0)
	draw_line(Vector2(0, -44), Vector2(0, -56), dark, 2.0)
	draw_circle(Vector2(0, -57), 2.5, Color(0.9, 0.2, 0.2) if fmod(_t, 1.0) < 0.5 else Color(0.4, 0.1, 0.1))
	# Noyau lumineux qui pulse (plus fort quand il produit)
	var glow := 0.55 + 0.25 * sin(_t * 3.0) + _pulse
	draw_circle(Vector2(0, -26), 9.0 + _pulse * 10.0, Color(0.3, 0.9, 1.0, 0.25 * glow))
	draw_circle(Vector2(0, -26), 5.0, Color(0.5, 0.95, 1.0, clampf(glow, 0.0, 1.0)))
	# PV
	draw_rect(Rect2(-18, -68, 36, 4), Color(0.2, 0, 0))
	draw_rect(Rect2(-18, -68, 36 * hp / max_hp, 4), Color(0.9, 0.3, 0.3))
