class_name Mob
extends CharacterBody2D
## Monstre (GDD 1, Ennemis). Ses caractéristiques viennent de son type
## (`mob_type`, fichier .tres dans data/mobs) multipliées par son niveau.
##
## Deux modes d'attaque :
## - Corps à corps : il fonce au contact et bondit sur sa cible.
## - À distance : il se tient à `keep_distance` et crache des projectiles.
## Deux comportements :
## - Vague : chasse le survivant le plus proche, sinon marche vers le village.
## - Posté (`posted = true`) : erre autour de `home` ; poursuit un survivant qui
##   s'approche, mais abandonne au-delà de `leash_range` de chez lui et y revient.
## Effets élémentaires reçus (GDD 7) : feu (brûlure), glace (ralenti),
## électrique (arc vers les voisins), poison (cumulable), modulés par les
## résistances et faiblesses du type.

signal died(mob: Mob)

const DEFAULT_TYPE := "res://data/mobs/rongeur.tres"
## Bonus par niveau au-delà du premier.
const HP_PER_LEVEL := 0.20
const DAMAGE_PER_LEVEL := 0.15
const XP_PER_LEVEL := 0.25
## Monstre spécial : plus gros, plus solide, meilleur loot.
const SPECIAL_HP_MULT := 4.0
const SPECIAL_DAMAGE_MULT := 1.5
const SPECIAL_XP_MULT := 4.0
const SPECIAL_SIZE_MULT := 1.4

## Effets élémentaires.
const BURN_TIME := 3.0          # le feu ne se cumule pas : un nouveau coup relance la brûlure
const POISON_TIME := 5.0        # le poison se cumule (jusqu'à POISON_MAX_STACKS doses)
const POISON_MAX_STACKS := 5
const SLOW_TIME := 2.0
const SLOW_BASE := 0.4          # ralenti de 40 % (modulé par la faiblesse / résistance)
const ARC_RANGE := 80.0
const ARC_TARGETS := 2
const ARC_RATIO := 0.6          # part des dégâts électriques transmise aux voisins

## Debug : monstres inoffensifs (panneau F1).
static var harmless := false

@export var mob_type: MobType
@export var level: int = 1
## Monstre spécial (apparition à un endroit précis) : nom propre, loot à sa mort.
@export var special := false
@export var special_name := ""
@export var aggro_range: float = 420.0

var max_hp: float = 30.0
var hp: float = 30.0
var speed: float = 70.0
var damage: float = 8.0
var xp_reward: int = 20
var size: float = 1.0
var village_center := Vector2.ZERO

## Ennemi posté (GDD : ennemis placés sur la carte et issus des générateurs).
var posted := false
var home := Vector2.ZERO
@export var wander_radius: float = 70.0
@export var leash_range: float = 340.0
var _wander_target := Vector2.ZERO
var _wander_wait := 0.0
var chasing := false
## Monde (nœud trié en Y) où ajouter les crachats et le loot.
var world: Node2D

var _alive := true
var _stats_ready := false
var _flash := 0.0
var _heal_fx := 0.0
var _t := 0.0
var _lunge := 0.0
var _attack_cooldown := 0.0
var _rng := RandomNumberGenerator.new()
var _last_attacker: Node = null

# Effets élémentaires en cours
var _burn_time := 0.0
var _burn_dps := 0.0
var _poison_time := 0.0
var _poison_stacks := 0
var _poison_dps := 0.0          # par dose
var _slow_time := 0.0
var _slow := 0.0
var _arcs: Array = []            # [cible (Vector2 locale), durée restante]
var _dot_shown := 0.0
var _dot_color := Color.WHITE


func _ready() -> void:
	_rng.randomize()
	add_to_group("enemies")
	add_to_group("mobs")
	if special:
		add_to_group("special_mobs")
	apply_stats()
	collision_layer = 2   # touché par les projectiles
	collision_mask = 4 | Building.LAYER  # obstacles et constructions (traverse les survivants)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0 * size
	shape.shape = circle
	shape.position = Vector2(0, -8 * size)
	add_child(shape)
	_t = _rng.randf() * 10.0


## Calcule les caractéristiques depuis le type et le niveau. Appelé une fois à
## l'entrée dans l'arbre ; on peut ensuite retoucher max_hp/hp à la main (tests).
func apply_stats() -> void:
	if _stats_ready:
		return
	_stats_ready = true
	if mob_type == null:
		mob_type = load(DEFAULT_TYPE)
	level = maxi(level, 1)
	var l := level - 1
	max_hp = mob_type.max_hp * (1.0 + HP_PER_LEVEL * l)
	damage = mob_type.damage * (1.0 + DAMAGE_PER_LEVEL * l)
	xp_reward = int(round(mob_type.xp_reward * (1.0 + XP_PER_LEVEL * l)))
	speed = mob_type.speed
	size = mob_type.size
	if special:
		max_hp *= SPECIAL_HP_MULT
		damage *= SPECIAL_DAMAGE_MULT
		xp_reward = int(xp_reward * SPECIAL_XP_MULT)
		size *= SPECIAL_SIZE_MULT
	hp = max_hp


func display_name() -> String:
	if special and special_name != "":
		return special_name
	return mob_type.type_name if mob_type else "Monstre"


func is_alive() -> bool:
	return _alive


func is_ranged() -> bool:
	return mob_type.attack == MobType.Attack.DISTANCE


## Soin (zone d'un générateur actif) ; affiche un petit « + » vert.
func heal(amount: float) -> void:
	if not _alive or hp >= max_hp:
		return
	hp = minf(hp + amount, max_hp)
	_heal_fx = 0.35


## Dégâts simples (sans élément ni attaquant). Retourne true si le coup a tué.
func take_damage(amount: float, element := 0) -> bool:
	return take_hit(amount, element, 0.0, null)


## Coup d'une arme : dégâts de base + part élémentaire modulée par les
## résistances / faiblesses, puis effet de l'élément. Retourne true si mortel.
func take_hit(base: float, element: int, element_damage: float, source: Node) -> bool:
	if not _alive:
		return false
	if is_instance_valid(source):
		_last_attacker = source
	var mult := mob_type.element_mult(element) if element != 0 else 1.0
	var elem := element_damage * mult
	var total := base + elem
	_flash = 0.1
	_spawn_number(total, _element_color(element) if element != 0 and element_damage > 0.0 else Color(1, 0.9, 0.4), mult)
	if element != 0 and element_damage > 0.0 and mult > 0.0:
		_apply_element(element, elem, mult, source)
	return _hurt(total)


func _hurt(amount: float) -> bool:
	if not _alive:
		return false
	hp -= amount
	if hp <= 0.0:
		_die()
		return true
	return false


func _apply_element(element: int, elem: float, mult: float, source: Node) -> void:
	match element:
		WeaponData.Element.FEU:
			# Brûlure : la moitié des dégâts de feu chaque seconde, pendant 3 s.
			_burn_dps = maxf(_burn_dps if _burn_time > 0.0 else 0.0, elem * 0.5)
			_burn_time = BURN_TIME
		WeaponData.Element.POISON:
			# Poison : chaque dose ajoute 30 % des dégâts de poison par seconde.
			_poison_stacks = mini(_poison_stacks + 1, POISON_MAX_STACKS)
			_poison_dps = maxf(_poison_dps, elem * 0.3)
			_poison_time = POISON_TIME
		WeaponData.Element.GLACE:
			_slow = clampf(SLOW_BASE * mult, 0.0, 0.8)
			_slow_time = SLOW_TIME
		WeaponData.Element.ELECTRIQUE:
			_chain_lightning(elem, source)


## Arc électrique : touche jusqu'à 2 monstres proches (sans rebond).
func _chain_lightning(elem: float, source: Node) -> void:
	var hits := 0
	for m in get_tree().get_nodes_in_group("mobs"):
		if hits >= ARC_TARGETS:
			break
		if m == self or not m.is_alive():
			continue
		if global_position.distance_to(m.global_position) > ARC_RANGE:
			continue
		hits += 1
		_arcs.append([m.global_position - global_position + Vector2(0, -10 * m.size), 0.15])
		var mm: float = m.mob_type.electric_mult
		if mm <= 0.0:
			continue
		var dmg := elem * ARC_RATIO * mm
		m._flash = 0.1
		m._spawn_number(dmg, _element_color(WeaponData.Element.ELECTRIQUE), mm)
		if is_instance_valid(source):
			m._last_attacker = source
		if m._hurt(dmg):
			m._give_xp_to_last_attacker()


func _process_effects(delta: float) -> void:
	var dot := 0.0
	if _burn_time > 0.0:
		_burn_time -= delta
		dot += _burn_dps * delta
		_dot_color = _element_color(WeaponData.Element.FEU)
		if _burn_time <= 0.0:
			_burn_dps = 0.0
	if _poison_time > 0.0:
		_poison_time -= delta
		dot += _poison_dps * _poison_stacks * delta
		_dot_color = _element_color(WeaponData.Element.POISON)
		if _poison_time <= 0.0:
			_poison_stacks = 0
			_poison_dps = 0.0
	if _slow_time > 0.0:
		_slow_time -= delta
		if _slow_time <= 0.0:
			_slow = 0.0
	for a in _arcs:
		a[1] -= delta
	_arcs = _arcs.filter(func(a): return a[1] > 0.0)
	if dot > 0.0:
		_dot_shown += dot
		if _dot_shown >= 4.0:
			_spawn_number(_dot_shown, _dot_color, 1.0)
			_dot_shown = 0.0
		if _hurt(dot):
			_give_xp_to_last_attacker()


## Mort par effet (brûlure, poison, arc) : l'XP revient au dernier tireur.
func _give_xp_to_last_attacker() -> void:
	if is_instance_valid(_last_attacker) and _last_attacker.has_method("add_xp"):
		_last_attacker.add_xp(xp_reward)


func _die() -> void:
	_alive = false
	died.emit(self)
	if special:
		_drop_loot()
	set_physics_process(false)
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.4, 0.2), 0.18)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


## Monstre spécial : laisse 2 à 4 objets au sol.
func _drop_loot() -> void:
	var items := LootTable.roll(_rng, 2, 4)
	var parent := world if world else get_parent()
	if parent == null:
		return
	for i in items.size():
		var p := ItemPickup.new()
		p.item = items[i]
		var angle := TAU * i / items.size() + _rng.randf_range(-0.4, 0.4)
		p.position = position + Vector2(cos(angle), sin(angle) * 0.5) * _rng.randf_range(30.0, 46.0)
		parent.add_child.call_deferred(p)
		p.ready.connect(p.pop_from.bind(position), CONNECT_ONE_SHOT)


func current_speed() -> float:
	return speed * (1.0 - _slow)


func _physics_process(delta: float) -> void:
	_t += delta
	_lunge = maxf(_lunge - delta, 0.0)
	_attack_cooldown -= delta
	_process_effects(delta)
	if not _alive:
		return
	if _attack_building():
		return
	if posted:
		_process_posted(delta)
		return
	var target := _nearest_survivor()
	if target:
		_engage(target)
	else:
		var to_way := Terrain.route(global_position, village_center) - global_position
		if (village_center - global_position).length() > 8.0:
			velocity = to_way.normalized() * current_speed() + _separation() * 40.0
		else:
			velocity = Vector2.ZERO
	move_and_slide()
	queue_redraw()


## Combat contre une cible : corps à corps (contact) ou à distance (se tenir
## à bonne distance et cracher).
func _engage(target: Node2D) -> void:
	var to_t: Vector2 = target.global_position - global_position
	var dist := to_t.length()
	var toward := (Terrain.route(global_position, target.global_position) - global_position).normalized()
	if is_ranged():
		var keep := mob_type.keep_distance
		if dist > mob_type.attack_range * 0.9:
			velocity = toward * current_speed() + _separation() * 40.0
		elif dist < keep * 0.8:
			velocity = -to_t.normalized() * current_speed() * 0.8 + _separation() * 40.0
		else:
			velocity = _separation() * 40.0
		if dist <= mob_type.attack_range:
			_spit(target)
	else:
		if dist < mob_type.attack_range * size:
			velocity = Vector2.ZERO
			_bite(target)
		else:
			velocity = toward * current_speed() + _separation() * 40.0


## Bond d'attaque sur un survivant au contact (si le bond est rechargé).
func _bite(target: Node2D) -> void:
	if _attack_cooldown > 0.0:
		return
	_lunge = 0.25
	_attack_cooldown = mob_type.attack_cooldown
	if not harmless and target.has_method("take_damage"):
		target.take_damage(damage)


## Crachat : un projectile lent qui vise la position actuelle de la cible.
func _spit(target: Node2D) -> void:
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = mob_type.attack_cooldown * _rng.randf_range(0.9, 1.1)
	_lunge = 0.15
	var from := global_position + Vector2(0, -12 * size)
	var aim := (target.global_position + Vector2(0, -10) - from).normalized()
	var p := EnemyProjectile.new()
	p.velocity = aim * mob_type.projectile_speed
	p.damage = damage
	p.building_damage = mob_type.building_damage
	p.max_distance = mob_type.attack_range * 1.4
	p.color = mob_type.projectile_color
	p.global_position = from
	var parent := world if world else get_parent()
	parent.add_child(p)


## Si une construction est collée au monstre, il s'arrête et la frappe.
func _attack_building() -> bool:
	var best: Building = null
	for b in get_tree().get_nodes_in_group("buildings"):
		if not b.is_destroyed and b.is_touching(global_position):
			best = b
			break
	if best == null:
		return false
	velocity = Vector2.ZERO
	if _attack_cooldown <= 0.0:
		_lunge = 0.25
		_attack_cooldown = mob_type.attack_cooldown
		best.take_damage(mob_type.building_damage * (1.0 + DAMAGE_PER_LEVEL * (level - 1)))
	move_and_slide()
	queue_redraw()
	return true


func _process_posted(delta: float) -> void:
	var target := _nearest_survivor()
	# Poursuite limitée : la cible doit rester à portée de laisse de chez lui.
	if target and target.global_position.distance_to(home) > leash_range:
		target = null
	if global_position.distance_to(home) > leash_range + 40.0:
		target = null  # trop loin : il rentre, même s'il voit quelqu'un
	chasing = target != null
	if target:
		_engage(target)
	elif global_position.distance_to(home) > wander_radius + 12.0:
		# Retour au point d'attache
		velocity = (Terrain.route(global_position, home) - global_position).normalized() * current_speed() * 0.9
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
				velocity = to_w.normalized() * current_speed() * 0.45
	move_and_slide()
	queue_redraw()


func _nearest_survivor() -> Node2D:
	var best: Node2D = null
	var best_d := aggro_range
	for s in get_tree().get_nodes_in_group("survivors"):
		if not s.is_alive():
			continue
		var d := global_position.distance_to(s.global_position)
		if d < best_d:
			best_d = d
			best = s
	return best


## Évite que les monstres s'empilent.
func _separation() -> Vector2:
	var push := Vector2.ZERO
	var r := 18.0 * size
	for m in get_tree().get_nodes_in_group("mobs"):
		if m == self:
			continue
		var d: Vector2 = global_position - m.global_position
		var l := d.length()
		if l > 0.01 and l < r:
			push += d / l * (r - l) / r
	return push


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
	if _heal_fx > 0.0:
		_heal_fx -= delta


static func _element_color(e: int) -> Color:
	match e:
		WeaponData.Element.FEU:
			return Color(1.0, 0.55, 0.15)
		WeaponData.Element.GLACE:
			return Color(0.55, 0.85, 1.0)
		WeaponData.Element.ELECTRIQUE:
			return Color(0.85, 0.85, 1.0)
		WeaponData.Element.POISON:
			return Color(0.55, 0.95, 0.3)
	return Color(1, 0.9, 0.4)


## Chiffre de dégâts ; « !» si faiblesse, plus petit si résistance.
func _spawn_number(amount: float, col: Color, mult: float) -> void:
	if amount <= 0.0 and mult > 0.0:
		return
	var label := Label.new()
	if mult == 0.0:
		label.text = "Immunisé"
	else:
		label.text = str(int(round(amount))) + ("!" if mult > 1.0 else "")
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 13 if mult > 1.0 else (9 if mult < 1.0 else 11))
	label.position = Vector2(_rng.randf_range(-10, 4), -40 * size)
	label.z_index = 10
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 18, 0.5)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tw.tween_callback(label.queue_free)


# --- Dessin placeholder ------------------------------------------------------

func _draw() -> void:
	if mob_type == null:
		return
	var s := size
	var hop := -absf(sin(_t * 9.0)) * 2.0 * s - _lunge * 18.0
	var flying := mob_type.shape == MobType.Shape.FEU_FOLLET
	# Ombre
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 10.0 * s, Color(0, 0, 0, 0.18 if flying else 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Aura du monstre spécial
	if special:
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, 16.0 * s, 0.0, TAU, 32, Color(1.0, 0.8, 0.2, 0.4 + 0.4 * pulse), 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := mob_type.color
	if _slow_time > 0.0:
		body = body.lerp(Color(0.55, 0.85, 1.0), 0.5)
	if _poison_time > 0.0:
		body = body.lerp(Color(0.45, 0.9, 0.3), 0.35)
	if _flash > 0.0:
		body = Color.WHITE
	match mob_type.shape:
		MobType.Shape.CRACHEUR:
			_draw_spitter(body, hop, s)
		MobType.Shape.COGNEUR:
			_draw_brute(body, hop, s)
		MobType.Shape.FEU_FOLLET:
			_draw_wisp(body, s)
		_:
			_draw_rodent(body, hop, s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Brûlure : petites flammes
	if _burn_time > 0.0:
		for k in 3:
			var fx := (k - 1) * 6.0 * s
			var fh := 5.0 + 3.0 * sin(_t * 20.0 + k * 2.0)
			var base := Vector2(fx, -14.0 * s + hop)
			draw_colored_polygon(PackedVector2Array([base + Vector2(-3, 0), base + Vector2(0, -fh * 1.4), base + Vector2(3, 0)]), Color(1.0, 0.5, 0.1, 0.85))
	# Arcs électriques
	for a in _arcs:
		var from := Vector2(0, -10 * s)
		var to: Vector2 = a[0]
		var mid := (from + to) / 2.0 + Vector2(_rng.randf_range(-8, 8), _rng.randf_range(-8, 8))
		draw_polyline(PackedVector2Array([from, mid, to]), Color(0.85, 0.9, 1.0), 2.0)
	# Soin en cours : croix verte qui monte
	if _heal_fx > 0.0:
		var hy := -34.0 * s + hop - (0.35 - _heal_fx) * 30.0
		var gc := Color(0.4, 1.0, 0.45, clampf(_heal_fx * 3.0, 0.0, 1.0))
		draw_line(Vector2(8, hy - 3), Vector2(8, hy + 3), gc, 2.0)
		draw_line(Vector2(5, hy), Vector2(11, hy), gc, 2.0)
	# Niveau, nom (spécial) et PV
	var top := -30.0 * s + hop
	var w := 22.0 * s
	if hp < max_hp or special:
		draw_rect(Rect2(-w / 2, top, w, 3), Color(0.2, 0, 0))
		draw_rect(Rect2(-w / 2, top, w * maxf(hp, 0.0) / max_hp, 3), Color(0.9, 0.3, 0.3) if not special else Color(1.0, 0.75, 0.2))
	var font := ThemeDB.fallback_font
	var tag := "Niv. %d" % level
	if special:
		tag = "%s · niv. %d" % [display_name(), level]
	var tw := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
	var col := Color(1.0, 0.85, 0.3) if special else Color(1, 1, 1, 0.75)
	draw_string_outline(font, Vector2(-tw / 2, top - 3), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-tw / 2, top - 3), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, col)


## Rongeur : goutte à cornes, sourire plein de dents (le monstre d'origine).
func _draw_rodent(body: Color, hop: float, s: float) -> void:
	var wobble := sin(_t * 9.0) * 1.5
	var c := Vector2(0, -10 * s + hop)
	draw_set_transform(c, 0.0, Vector2(1.0 + wobble * 0.03, 1.0 - wobble * 0.03) * s)
	draw_circle(Vector2.ZERO, 10.0, body)
	draw_colored_polygon(PackedVector2Array([Vector2(-7, -6), Vector2(-4, -15), Vector2(-2, -7)]), body.darkened(0.3))
	draw_colored_polygon(PackedVector2Array([Vector2(7, -6), Vector2(4, -15), Vector2(2, -7)]), body.darkened(0.3))
	_draw_eyes(Vector2(-3.5, -2), Vector2(3.5, -2), 2.6)
	draw_arc(Vector2(0, 2), 5.0, 0.15 * PI, 0.85 * PI, 10, Color(0.1, 0.05, 0.05), 2.0)
	for k in 3:
		var x := -3.0 + k * 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(x - 1, 5.5), Vector2(x + 1, 5.5), Vector2(x, 7.5)]), Color.WHITE)


## Cracheur : corps trapu, gros tube-bouche, yeux sur pédoncules.
func _draw_spitter(body: Color, hop: float, s: float) -> void:
	var puff := 1.0 + _lunge * 2.0
	var c := Vector2(0, -9 * s + hop * 0.5)
	draw_set_transform(c, 0.0, Vector2(1.15, 0.9) * s)
	draw_circle(Vector2.ZERO, 10.0, body)
	draw_circle(Vector2(0, 3), 7.0, body.lightened(0.15))
	draw_set_transform(c, 0.0, Vector2(s, s))
	# Pédoncules
	draw_line(Vector2(-4, -7), Vector2(-6, -16), body.darkened(0.3), 2.0)
	draw_line(Vector2(4, -7), Vector2(6, -16), body.darkened(0.3), 2.0)
	_draw_eyes(Vector2(-6, -17), Vector2(6, -17), 2.6)
	# Bouche-tube qui gonfle au moment de cracher
	draw_circle(Vector2(0, -1), 4.5 * puff, body.darkened(0.35))
	draw_circle(Vector2(0, -1), 2.5 * puff, Color(0.12, 0.08, 0.05))
	draw_circle(Vector2(0, -1), 1.2 * puff, mob_type.projectile_color)


## Cogneur : grosse masse, petite tête, poings énormes.
func _draw_brute(body: Color, hop: float, s: float) -> void:
	var c := Vector2(0, -11 * s + hop * 0.5)
	draw_set_transform(c, 0.0, Vector2(s, s))
	var swing := _lunge * 14.0
	# Poings
	draw_circle(Vector2(-11, 3 - swing), 4.5, body.darkened(0.25))
	draw_circle(Vector2(11, 3 - swing), 4.5, body.darkened(0.25))
	# Corps carré arrondi
	draw_rect(Rect2(-9, -9, 18, 15), body)
	draw_circle(Vector2(-9, -2), 7.0, body)
	draw_circle(Vector2(9, -2), 7.0, body)
	draw_circle(Vector2(0, 4), 8.0, body)
	# Petite tête enfoncée, sourcils froncés
	draw_circle(Vector2(0, -11), 5.0, body.lightened(0.1))
	_draw_eyes(Vector2(-2, -11), Vector2(2, -11), 1.4)
	draw_line(Vector2(-4, -14), Vector2(-0.5, -12.5), Color(0.1, 0.05, 0.05), 1.5)
	draw_line(Vector2(4, -14), Vector2(0.5, -12.5), Color(0.1, 0.05, 0.05), 1.5)


## Feu follet : flamme flottante qui vacille.
func _draw_wisp(body: Color, s: float) -> void:
	var float_y := -18.0 * s + sin(_t * 4.0) * 3.0 - _lunge * 10.0
	var c := Vector2(0, float_y)
	draw_set_transform(c, 0.0, Vector2(s, s))
	var flick := sin(_t * 17.0) * 2.0
	draw_circle(Vector2.ZERO, 11.0, Color(body.r, body.g, body.b, 0.25))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7, 2), Vector2(-5, -6), Vector2(-1 + flick, -15), Vector2(2, -8),
		Vector2(5 - flick, -12), Vector2(7, 2), Vector2(0, 7)]), body)
	draw_circle(Vector2(0, 1), 5.5, body.lightened(0.35))
	_draw_eyes(Vector2(-2.5, 0), Vector2(2.5, 0), 1.6)


func _draw_eyes(a: Vector2, b: Vector2, r: float) -> void:
	draw_circle(a, r, Color(1, 0.85, 0.2))
	draw_circle(b, r, Color(1, 0.85, 0.2))
	draw_circle(a, r * 0.42, Color(0.1, 0.05, 0.05))
	draw_circle(b, r * 0.42, Color(0.1, 0.05, 0.05))
