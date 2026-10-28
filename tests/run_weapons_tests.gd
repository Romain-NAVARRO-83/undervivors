extends SceneTree
## Tests automatisés des armes (bases, générateur, effets spéciaux), sans fenêtre :
##   godot --headless --fixed-fps 60 --path . -s tests/run_weapons_tests.gd
## Les effets sont testés au champ de tir, sur des monstres immobiles.

var _failures := 0
var _checks := 0
var _f := 0
var _r: Node
var _s: Survivor
var _q: Array = []
var _mobs: Array = []
var _hp: Array = []
var _frags := 0


func _init() -> void:
	_static_checks()
	_r = load("res://scenes/range.tscn").instantiate()
	root.add_child(_r)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("ÉCHEC : " + msg)


func at(frame: int, fn: Callable) -> void:
	_q.append([frame, fn])


func _static_checks() -> void:
	# Armes faites à la main
	var names := {}
	var per_tier := {}
	for f in DirAccess.get_files_at("res://data/weapons/"):
		if not f.ends_with(".tres"):
			continue
		var w: WeaponData = load("res://data/weapons/" + f)
		check(w != null and w.weapon_name != "", "%s se charge" % f)
		check(w.tier >= 1 and w.tier <= 5, "%s : niveau 1 à 5 (%d)" % [f, w.tier])
		check(not names.has(w.weapon_name), "nom unique : %s" % w.weapon_name)
		names[w.weapon_name] = true
		per_tier[w.tier] = per_tier.get(w.tier, 0) + 1
	for t in range(1, 6):
		check(per_tier.get(t, 0) >= 2, "au moins 2 armes de niveau %d (%d)" % [t, per_tier.get(t, 0)])
	var slingshot: WeaponData = load(Survivor.SLINGSHOT_PATH)
	check(slingshot.recoil == 0.0, "pas de recul pour le lance-pierre")
	for f in ["assault_rifle", "military_rifle"]:
		var w: WeaponData = load("res://data/weapons/%s.tres" % f)
		check(w.fire_rate >= 8.0, "%s : tir rapide (%.0f/s)" % [w.weapon_name, w.fire_rate])
	for f in ["catapult", "mortar"]:
		var w: WeaponData = load("res://data/weapons/%s.tres" % f)
		check(w.lob and w.aoe_radius > 0.0 and w.recoil >= 30.0, "%s : tir en cloche, zone, fort recul" % w.weapon_name)
	# Générateur
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var avg_rarity := []
	var legendary_named := true
	var traits_ok := true
	var all_ok := true
	var shared_ok := true
	for level in range(1, 6):
		var sum := 0.0
		for i in 300:
			var w := WeaponGenerator.generate(rng, level)
			sum += w.rarity
			if w.damage <= 0.0 or w.fire_rate <= 0.0 or w.weapon_name == "" or w.tier != level:
				all_ok = false
			if w.rarity >= 4 and not w.weapon_name.begins_with("«"):
				legendary_named = false
			var n_fx := 0
			for prop in ["pierce", "ricochet", "split"]:
				if w.get(prop) > 0:
					n_fx += 1
			for prop in ["homing", "wave", "vampire"]:
				if w.get(prop) > 0.0:
					n_fx += 1
			for prop in ["chaos", "boomerang", "fish"]:
				if w.get(prop):
					n_fx += 1
			if n_fx > 5:
				traits_ok = false
		avg_rarity.append(sum / 300.0)
	var base: WeaponData = load("res://data/weapons/pistol.tres")
	check(base.weapon_name == "Pistolet rouillé" and base.ricochet == 0 and base.rarity == 0, "le générateur n'abîme pas les armes de base")
	check(all_ok, "armes générées valides (dégâts, cadence, nom, niveau)")
	check(avg_rarity[4] > avg_rarity[0] + 0.5, "plus le niveau est haut, plus c'est rare (%.2f → %.2f)" % [avg_rarity[0], avg_rarity[4]])
	check(legendary_named, "les légendaires ont un nom propre")
	check(traits_ok, "au plus 3 effets ajoutés à ceux de la base")
	var epic := WeaponGenerator.generate(rng, 4, 3)
	check(epic.rarity == 3 and epic.effect_lines().size() >= 2, "une épique a des effets (%s)" % ", ".join(epic.effect_lines()))
	var roll := LootTable.roll(rng, 30, 30, 4)
	var gen := 0
	for it in roll:
		if it is WeaponData and it.resource_path == "":
			gen += 1
	check(gen > 0, "les coffres peuvent contenir des armes générées (%d sur 30)" % gen)


## Monstres immobiles à des positions relatives au tireur.
func _place_mobs(offsets: Array) -> void:
	_r.clear_mobs()
	_mobs.clear()
	_hp.clear()
	for o in offsets:
		var m: Mob = _r.spawn_mob("cogneur")
		m.set_physics_process(false)
		m.global_position = _s.global_position + o
		m.home = m.global_position
		_mobs.append(m)


func _mark() -> void:
	_hp.clear()
	for m in _mobs:
		_hp.append(m.hp if is_instance_valid(m) else 0.0)


func _hurt(i: int) -> bool:
	var m: Mob = _mobs[i]
	return not is_instance_valid(m) or m.hp < _hp[i]


func _weapon(path: String, changes := {}) -> WeaponData:
	var w: WeaponData = load(path).duplicate()
	for k in changes:
		w.set(k, changes[k])
	_s.equip(w)
	_s._cooldown = 0.0
	return w


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_s = _r.survivor
		Mob.harmless = true
		_r.world.child_entered_tree.connect(func(n):
			if n is Projectile and n.is_fragment:
				_frags += 1)
		_plan()
	for a in _q.duplicate():
		if a[0] == _f:
			a[1].call()
			_q.erase(a)
	if _q.is_empty() and _f > 2:
		Mob.harmless = false
		print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
	return false


func _plan() -> void:
	var f := 5
	# Tir en cloche : la catapulte passe par-dessus un monstre et explose sur
	# le groupe visé à 220 px (dégâts de zone), sans toucher le monstre loin du point.
	at(f, func():
		_s.global_position = Vector2(-500, 250)
		_place_mobs([Vector2(110, 0), Vector2(220, 0), Vector2(235, 12), Vector2(420, 0)])
		_mark()
		_weapon("res://data/weapons/catapult.tres", {"spread_deg": 0.0})
		_s.try_shoot(Vector2.RIGHT, 220.0))
	f += 90
	at(f, func():
		check(not _hurt(0), "en cloche : le monstre sous la trajectoire n'est pas touché")
		check(_hurt(1) and _hurt(2), "explosion : deux monstres touchés au point d'impact")
		check(not _hurt(3), "hors de la zone : pas touché"))
	f += 10
	# Perforation : l'arbalète traverse 2 monstres et touche le 3e
	at(f, func():
		_place_mobs([Vector2(80, 0), Vector2(140, 0), Vector2(200, 0), Vector2(260, 0)])
		_mark()
		_weapon("res://data/weapons/crossbow.tres", {"spread_deg": 0.0})
		_s.try_shoot(Vector2.RIGHT))
	f += 40
	at(f, func():
		check(_hurt(0) and _hurt(1) and _hurt(2), "perforation : trois monstres alignés touchés")
		check(not _hurt(3), "perforation 2 : le quatrième est épargné"))
	f += 10
	# Tête chercheuse : un tir à 35° de la cible finit par la toucher
	at(f, func():
		_place_mobs([Vector2(200, 0)])
		_mark()
		_weapon("res://data/weapons/pistol.tres", {"spread_deg": 0.0, "homing": 4.0})
		_s.try_shoot(Vector2.RIGHT.rotated(deg_to_rad(-35))))
	f += 50
	at(f, func(): check(_hurt(0), "tête chercheuse : la cible est touchée"))
	f += 5
	# Fragmentation et vampire
	at(f, func():
		_place_mobs([Vector2(100, 0)])
		_mark()
		_s.hp = 50
		_weapon("res://data/weapons/sniper.tres", {"spread_deg": 0.0, "split": 3, "vampire": 0.5, "pierce": 0})
		_s.try_shoot(Vector2.RIGHT))
	f += 23
	at(f, func(): check(_frags == 3, "fragmentation : 3 éclats (%d)" % _frags))
	at(f, func(): check(_s.hp > 50, "vampire : le tireur récupère des PV (%d)" % _s.hp))
	f += 5
	# Boomerang : touche, revient au tireur
	at(f, func():
		_place_mobs([Vector2(150, 0)])
		_mark()
		_weapon("res://data/weapons/beach_boomerang.tres", {"spread_deg": 0.0})
		_s.try_shoot(Vector2.RIGHT))
	f += 150
	at(f, func():
		check(_hurt(0), "boomerang : touché")
		var left := 0
		for n in _r.world.get_children():
			if n is Projectile and not n.is_queued_for_deletion():
				left += 1
		check(left == 0, "boomerang : revenu au tireur (%d en vol)" % left))
	f += 5
	# Ricochet : le tir rebondit sur le rocher du champ de tir
	at(f, func():
		_r.clear_mobs()
		var rock: Node2D = null
		for n in _r.world.get_children():
			if n is StaticBody2D and not (n is TrainingDummy) and n.collision_layer == 4:
				rock = n
		_s.global_position = rock.global_position + Vector2(-120, -8)
		_weapon("res://data/weapons/pistol.tres", {"spread_deg": 0.0, "ricochet": 1})
		_s.try_shoot(Vector2.RIGHT))
	f += 14
	at(f, func():
		var p: Projectile = null
		for n in _r.world.get_children():
			if n is Projectile and not n.is_queued_for_deletion():
				p = n
		check(p != null and p.velocity.x < 0.0 and p.ricochet == 0, "ricochet : le tir repart après avoir touché le rocher"))
	f += 40
	# Recul du mortier
	at(f, func():
		_s.global_position = Vector2(-500, 250)
		_weapon("res://data/weapons/mortar.tres")
		_s.try_shoot(Vector2.RIGHT, 200.0))
	f += 40
	at(f, func():
		check(_s.global_position.x < -500.0 - 30.0, "mortier : gros recul (%.0f px)" % (-500.0 - _s.global_position.x)))
	f += 60
	# Arme générée au champ de tir
	at(f, func():
		var n0: int = _r.weapons.size()
		var w: WeaponData = _r.generate_weapon(5, 4)
		check(_r.weapons.size() == n0 + 1 and _s.weapon == w and w.rarity == 4, "champ de tir : générer une légendaire de niveau 5 et l'équiper"))
