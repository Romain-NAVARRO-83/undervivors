extends SceneTree
## Tests automatisés, sans fenêtre :
##   godot --headless --fixed-fps 60 --path . -s tests/run_tests.gd
## (--fixed-fps 60 : une étape de physique par image, pour des tests reproductibles)

var _failures := 0
var _checks := 0


var _main: Node
var _worker: Survivor
var _frames := 0
var _cam_x := 0.0
var _water_before := 0


func _init() -> void:
	test_name_generator()
	test_weapons()
	test_appearance()
	test_level_up()
	test_stock()
	test_needs()
	# Test de scène : cycle de récolte complet à la mare (se termine dans _process).
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		_main._select(null)  # personne n'est contrôlé
		_worker = _main.survivors[1]
		_main.assign_survivor(_worker, _main.resource_nodes[0])
		check(_worker.task_node == _main.resource_nodes[0], "survivant assigné à la mare")
	if _frames == 1500:
		var eau: int = _main.stock.total_added.get("eau", 0)
		check(eau >= 2, "eau rapportée au stock (%d au total)" % eau)
		check(_worker.task_node != null, "toujours assigné après le dépôt (jusqu'à ordre contraire)")
		# Escouade : le travailleur reste assigné pour vérifier la reprise de tâche.
		var m: Array = _main.survivors
		_main.set_squad_mode(true)
		check(not _main.squad_mode, "pas de mode escouade sans membres")
		for i in 5:
			_main.toggle_squad_member(m[i])
		check(_main.squad.size() == 4, "escouade limitée à 4 membres")
		check(not m[4].squad_member, "le 5e n'est pas ajouté")
		_main.set_squad_mode(true)
		check(_main.squad_mode and _main.selected == m[0], "mode escouade : le 1er membre mène")
		check(m[1].following and m[2].following and m[3].following, "les autres suivent")
		_main._select(m[4])
		check(_main.selected == m[0], "impossible de prendre un non-membre comme leader")
		_main._select(m[2])
		check(_main.selected == m[2] and m[0].following and not m[2].following, "changement de leader")
		m[2].global_position += Vector2(200, 60)
	if _frames == 1700:
		var m: Array = _main.survivors
		var ok := true
		for i in [0, 1, 3]:
			if m[i].global_position.distance_to(m[i].follow_point) > 12.0:
				ok = false
				print("écart suiveur %d : %.1f px, vitesse %.1f" % [i, m[i].global_position.distance_to(m[i].follow_point), m[i].velocity.length()])
		check(ok, "les suiveurs ont rejoint leur place en formation")
		_main.formation = _main.Formation.LIGNE
		var offs: Array = _main.formation_offsets(3, Vector2.RIGHT)
		check(offs.size() == 3 and absf(offs[0].x) < 0.01 and offs[0].y == -offs[1].y, "formation en ligne symétrique")
		_main.set_squad_mode(false)
		check(not m[1].following and _main.squad.size() == 4, "fin du mode : composition conservée")
		check(m[1].task_node == _main.resource_nodes[0] and m[1].activity_text() != "Suit le leader en formation", "le travailleur reprend sa tâche")
		# Relâcher le contrôle en plein mode escouade → mode gestion, caméra libre.
		_main.set_squad_mode(true)
		_main.release_control()
		check(_main.selected == null and not _main.squad_mode, "Échap : plus aucun survivant sélectionné, mode escouade quitté")
		check(_main.squad.size() == 4, "composition conservée après relâchement")
		_cam_x = _main.camera.position.x
		Input.action_press("move_right")
	if _frames == 1760:
		Input.action_release("move_right")
		check(_main.camera.position.x > _cam_x + 100.0, "caméra libre déplacée au clavier (%.0f px)" % (_main.camera.position.x - _cam_x))
		check(not _main.survivors[2].selected, "aucun survivant ne bouge sous le clavier")
		# Soif : un survivant libre, loin du village, assoiffé → bulle, puis va boire.
		var t: Survivor = _main.survivors[4]
		t.global_position = Vector2(300, -150)
		t.thirst = 10.0
		t.hunger = 90.0
		t._bubble_cooldown = 0.0
		_main.stock.add("eau", 10)
		_water_before = _main.stock.total_taken.get("eau", 0)
	if _frames == 1765:
		var t: Survivor = _main.survivors[4]
		check(t.bubble.is_showing(), "bulle affichée quand il a soif : « %s »" % t.bubble.text())
		check(t.activity_text() == "Va boire et manger au village", "part boire au village de lui-même")
	if _frames == 2300:
		var t: Survivor = _main.survivors[4]
		check(t.thirst >= Survivor.NEED_REFILLED - 5.0, "a bu au stock (eau %.0f)" % t.thirst)
		check(_main.stock.total_taken.get("eau", 0) > _water_before, "de l'eau a été prise au stock")
		print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
	return false


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
	check(s.carry_capacity() == 4, "niveau 3 → porte 4 par trajet")
	s.free()


func test_needs() -> void:
	var s := Survivor.new()
	s.speed_stat = 5
	var normal := s.move_speed()
	s.thirst = 0.0
	check(is_equal_approx(s.move_speed(), normal * Survivor.EMPTY_SLOWDOWN), "jauge d'eau vide : ralenti")
	s.thirst = 50.0
	s.hunger = 0.0
	check(s.move_speed() < normal, "jauge de nourriture vide : ralenti")
	var st := VillageStock.new()
	s.stock = st
	s.hunger = 50.0
	s.thirst = 20.0
	check(not s.needs_refill(), "stock vide : rien ne se passe (pas de trajet inutile)")
	st.add("eau", 10)
	check(s.needs_refill(), "assoiffé et eau en stock : va boire")
	s._refill("eau")
	check(s.thirst >= Survivor.NEED_REFILLED and st.get_amount("eau") == 6, "boit au stock : 4 unités → jauge remontée")
	s.free()
	st.free()


func test_stock() -> void:
	var st := VillageStock.new()
	st.add("eau", 5)
	check(st.get_amount("eau") == 5, "stock : ajout")
	check(st.take("eau", 8) == 5 and st.get_amount("eau") == 0, "stock : on ne prend pas plus que disponible")
	st.free()
