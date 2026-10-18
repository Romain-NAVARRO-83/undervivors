extends SceneTree
## Tests automatisés, sans fenêtre :
##   godot --headless --path . -s tests/run_tests.gd

var _failures := 0
var _checks := 0


func _init() -> void:
	test_name_generator()
	test_weapons()
	test_appearance()
	test_level_up()
	print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		printerr("ÉCHEC : " + msg)


func test_name_generator() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	check(NameGenerator.SYLLABLES.size() >= NameGenerator.MAX_SYLLABLES, "assez de pays pour 4 syllabes")
	var seen_counts := {}
	for i in 2000:
		var part := NameGenerator.generate_part(rng)
		var syl: Array = part["syllables"]
		var n := syl.size()
		seen_counts[n] = true
		check(n >= 2 and n <= 4, "nombre de syllabes entre 2 et 4 (obtenu %d)" % n)
		var countries := {}
		for s in syl:
			countries[s["country"]] = true
		check(countries.size() == n, "pays tous différents dans « %s »" % part["text"])
		var t: String = part["text"]
		check(t.substr(0, 1) == t.substr(0, 1).to_upper(), "majuscule initiale : %s" % t)
	check(seen_counts.size() == 3, "les longueurs 2, 3 et 4 apparaissent toutes")
	var full := NameGenerator.generate(rng)
	check(full.split(" ").size() == 2, "format « Prénom Nom » : %s" % full)
	print("Exemples de noms :")
	for i in 8:
		print("  - " + NameGenerator.generate(rng))


func test_weapons() -> void:
	var sling: WeaponData = load("res://data/weapons/slingshot.tres")
	var shotgun: WeaponData = load("res://data/weapons/shotgun.tres")
	check(sling != null and shotgun != null, "ressources d'armes chargées")
	check(sling.bullets_per_shot == 1, "lance-pierre : 1 projectile")
	check(shotgun.bullets_per_shot > 1, "fusil à pompe : plusieurs projectiles")
	check(is_equal_approx(sling.cooldown(), 0.5), "cadence 2/s → 0,5 s entre deux tirs")
	check(shotgun.element == WeaponData.Element.FEU, "fusil à pompe : dégâts de feu")


func test_appearance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var combos := {}
	for i in 300:
		var a := SurvivorAppearance.random(rng)
		check(SurvivorAppearance.SKIN_TONES.has(a.skin), "teinte de peau valide")
		combos["%s|%s|%s|%s|%s" % [a.skin, a.hair_style, a.face_shape, a.mouth, a.accessory]] = true
	check(combos.size() > 150, "apparences variées (%d combinaisons sur 300)" % combos.size())


func test_level_up() -> void:
	var s := Survivor.new()
	s.speed_stat = 5
	s.max_hp = 100
	s.hp = 100
	check(not s.spend_point("vitesse"), "pas de point à dépenser au départ")
	s.add_xp(250)
	check(s.level == 3, "250 XP → niveau 3 (obtenu %d)" % s.level)
	check(s.stat_points == 2, "2 points gagnés")
	check(s.xp_in_level() == 50, "50 XP dans le niveau en cours")
	check(s.spend_point("vitesse") and s.speed_stat == 6, "point en vitesse")
	check(s.spend_point("pv_max") and s.max_hp == 110 and s.hp == 110, "point en PV max (+10)")
	check(s.stat_points == 0, "points épuisés")
	check(is_equal_approx(s.move_speed(), 158.0), "vitesse 6 → 158 px/s")
	s.free()
