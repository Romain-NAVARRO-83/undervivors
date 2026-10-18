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
var _chest: LootChest
var _pickups_before := 0
var _wave: Array = []
var _wave_dist := 0.0
var _cleared := false
var _spawner: MobSpawner
var _bait: Survivor
var _bot: Mob
var _wall: Survivor


func _init() -> void:
	test_name_generator()
	test_weapons()
	test_appearance()
	test_level_up()
	test_stock()
	test_needs()
	test_inventory()
	test_terrain()
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
		_main.assign_survivor(_main.survivors[3], _main.resource_nodes[1])
		check(_main.resource_nodes[1].resource_type == "nourriture", "les cocotiers donnent de la nourriture")
	if _frames == 1500:
		var eau: int = _main.stock.total_added.get("eau", 0)
		check(eau >= 2, "eau rapportée au stock (%d au total)" % eau)
		var food: int = _main.stock.total_added.get("nourriture", 0)
		check(food >= 2, "nourriture rapportée des cocotiers (%d au total)" % food)
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
	if _frames == 1820:
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
	if _frames == 1880:
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
	if _frames == 1883:
		check(not _main.squad_bar.visible, "mode gestion : la barre d'escouade est masquée")
	if _frames == 1885:
		var t: Survivor = _main.survivors[4]
		check(t.bubble.is_showing(), "bulle affichée quand il a soif : « %s »" % t.bubble.text())
		check(t.activity_text() == "Va boire et manger au village", "part boire au village de lui-même")
	if _frames == 2240:
		# Coffre : on le casse en tirant (dégâts directs ici), le loot jaillit au sol.
		_chest = _main.get_tree().get_nodes_in_group("chests")[0]
		_pickups_before = _main.get_tree().get_nodes_in_group("item_pickups").size()
		_chest.take_damage(15.0)
		check(not _chest.is_broken, "le coffre résiste au premier tir")
		_chest.take_damage(20.0)
		check(_chest.is_broken, "le coffre se casse")
	if _frames == 2250:
		var n: int = _main.get_tree().get_nodes_in_group("item_pickups").size() - _pickups_before
		check(n >= 1 and n <= 3, "%d objet(s) au sol après le coffre" % n)
	if _frames == 2260:
		# Panneau des objets : sélection puis équipement depuis l'interface.
		var lp: LootPanel = _main.loot_panel
		var taser: WeaponData = load("res://data/weapons/taser.tres")
		_main.stock.add_item(taser)
		_main._toggle_loot()
		check(lp.visible and not _main.panel.visible, "panneau des objets ouvert (et seul)")
		lp.select_item(taser)
		var who: Survivor = _main.survivors[4]
		lp.equip(who)
		check(who.weapon == taser, "équipé depuis le panneau des objets")
	if _frames == 2270:
		check(_main.loot_panel._items_box.get_child_count() >= 1, "le panneau liste les objets du stock")
	if _frames == 2300:
		var t: Survivor = _main.survivors[4]
		check(t.thirst >= Survivor.NEED_REFILLED - 5.0, "a bu au stock (eau %.0f)" % t.thirst)
		check(_main.stock.total_taken.get("eau", 0) > _water_before, "de l'eau a été prise au stock")
		# Vagues : plus de mannequins, une vague de monstres sans dégâts.
		check(_main.wave_manager.alive_count() == 0, "aucun monstre au départ (mannequins retirés)")
		_main.debug_heal_all()
		_main.wave_manager.wave_cleared.connect(func(_n): _cleared = true)
		_wave = _main.wave_manager.spawn_wave(4, "Est")
		check(_wave.size() == 4 and _main.wave_manager.alive_count() == 4, "vague de 4 monstres lancée")
		_wave_dist = _wave[0].global_position.distance_to(Vector2.ZERO)
	if _frames == 2700:
		var moved := false
		var hit := false
		for m in _wave:
			if is_instance_valid(m):
				if m.global_position.distance_to(Vector2.ZERO) < _wave_dist - 100.0:
					moved = true
				if m.hp < m.max_hp:
					hit = true
			else:
				hit = true
		check(moved or hit, "les monstres avancent vers le village et se font tirer dessus")
		var unhurt := true
		for s in _main.survivors:
			if s.hp < s.max_hp:
				unhurt = false
		check(unhurt, "les monstres ne font pas de dégâts")
		_main.wave_manager.kill_all()
		check(_main.wave_manager.alive_count() == 0 and _cleared, "tuer tous les monstres : vague repoussée")
		_main.debug_panel.toggle()
		check(_main.debug_panel.visible, "panneau debug ouvert")
		# Ennemis postés et générateurs : on replace tout puis on teste.
		_main.setup_map_enemies()
	if _frames == 2705:
		var sp: MobSpawner = _main.get_tree().get_nodes_in_group("spawners")[0]
		_spawner = sp
		check(_main.get_tree().get_nodes_in_group("spawners").size() == 2, "2 générateurs sur la carte")
		var posted := 0
		for m in _main.get_tree().get_nodes_in_group("mobs"):
			if m.posted:
				posted += 1
		check(posted >= 8, "%d ennemis postés dans les camps" % posted)
		for i in 6:
			sp.spawn_mob()
		check(sp.alive_mobs() == sp.max_alive, "le générateur plafonne à %d bots" % sp.max_alive)
		# Laisse : un survivant s'approche d'un bot, le bot le poursuit.
		_bait = _main.survivors[4]
		_main._select(_bait)  # contrôlé : il reste où on le met
		_bot = sp._mobs[0]
		_bait.global_position = _bot.global_position + Vector2(90, 0)
	if _frames == 2740:
		check(_bot.chasing, "le bot poursuit le survivant qui s'approche")
		_bait.global_position = _bot.home + Vector2(-900, 300)
	if _frames == 3200:
		check(not _bot.chasing and _bot.global_position.distance_to(_bot.home) <= _bot.wander_radius + 20.0, "survivant trop loin : le bot abandonne et rentre (%.0f px de chez lui)" % _bot.global_position.distance_to(_bot.home))
		_spawner.take_damage(99999.0)
		check(_spawner.is_destroyed and _spawner.spawn_mob() == null, "générateur détruit : plus de production")
		check(not _spawner.is_secured, "zone pas encore sécurisée tant que ses bots vivent")
		for m in _spawner._mobs:
			if is_instance_valid(m) and m.is_alive():
				m.take_damage(9999.0)
		check(_spawner.is_secured, "ses bots éliminés : zone sécurisée")
		# Crête : un survivant contrôlé qui fonce vers l'est est arrêté par les rochers.
		_wall = _main.survivors[0]
		_main._select(_wall)
		_wall.global_position = Vector2(Terrain.RIDGE_X - 80, -250)
		Input.action_press("move_right")
	if _frames == 3290:
		Input.action_release("move_right")
		check(_wall.global_position.x < Terrain.RIDGE_X, "la crête bloque le passage hors du col (x = %.0f)" % _wall.global_position.x)
		check(_main.get_tree().get_nodes_in_group("spawners").size() == 2, "deux générateurs")
		var near_gap := true
		for sp in _main.get_tree().get_nodes_in_group("spawners"):
			if sp.global_position.distance_to(Vector2(Terrain.RIDGE_X, Terrain.GAP_Y)) > 150.0:
				near_gap = false
		check(near_gap, "les deux générateurs gardent le passage")
	if _frames == 3291:
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


func test_inventory() -> void:
	var s := Survivor.new()
	var st := VillageStock.new()
	s.stock = st
	s.weapon = load("res://data/weapons/slingshot.tres")
	var pistol: WeaponData = load("res://data/weapons/pistol.tres")
	var taser: WeaponData = load("res://data/weapons/taser.tres")
	check(s.bag_capacity() == 4, "sac : 4 objets au niveau 1")
	s.level = 3
	check(s.bag_capacity() == 8, "sac : 8 objets au niveau 3 (+2 par niveau)")
	s.level = 1
	check(s.try_pick_up(pistol) and s.weapon == pistol and s.inventory.is_empty(), "lance-pierre seul : l'arme ramassée est équipée")
	check(s.try_pick_up(taser) and s.weapon == pistol and s.inventory.size() == 1, "déjà armé : l'arme va dans le sac")
	for i in 3:
		s.try_pick_up(taser)
	check(s.inventory.size() == 4 and not s.try_pick_up(taser), "sac plein : l'objet n'est pas ramassé")
	s._deposit_inventory()
	check(s.inventory.is_empty() and st.items.size() == 4, "au feu de camp : le sac rejoint le stock d'objets")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var ok := true
	for i in 50:
		var r := LootTable.roll(rng)
		if r.size() < 1 or r.size() > 3:
			ok = false
	check(ok, "un coffre donne 1 à 3 objets")
	# Stock commun : équiper / ranger
	var harpoon: WeaponData = load("res://data/weapons/harpoon.tres")
	st.add_item(harpoon)
	var before := st.items.size()
	check(s.equip_from_stock(harpoon) and s.weapon == harpoon, "équiper une arme du stock")
	check(st.items.size() == before and st.count_item(pistol) >= 1, "l'ancienne arme retourne au stock")
	check(not s.equip_from_stock(harpoon), "impossible d'équiper une arme absente du stock")
	check(s.unequip_to_stock() and s.has_only_slingshot() and st.count_item(harpoon) == 1, "ranger : arme au stock, retour au lance-pierre")
	check(not s.unequip_to_stock(), "le lance-pierre ne se range pas")
	check(harpoon.dps() > load("res://data/weapons/slingshot.tres").dps(), "le harpon fait plus de dégâts/s que le lance-pierre")
	s.free()
	st.free()


func test_terrain() -> void:
	var a := Vector2(200, -200)
	var b := Vector2(700, -200)
	var wp := Terrain.route(a, b)
	check(wp.x < Terrain.RIDGE_X and absf(wp.y - Terrain.GAP_Y) < 1.0, "pour traverser la crête, on passe par l'entrée du passage")
	check(Terrain.route(a, Vector2(100, 300)) == Vector2(100, 300), "même côté : trajet direct")
	var inside := Terrain.route(Vector2(Terrain.RIDGE_X - 20, 5), b)
	check(inside.x > Terrain.RIDGE_X, "dans le passage : on file vers l'autre côté")


func test_stock() -> void:
	var st := VillageStock.new()
	st.add("eau", 5)
	check(st.get_amount("eau") == 5, "stock : ajout")
	check(st.take("eau", 8) == 5 and st.get_amount("eau") == 0, "stock : on ne prend pas plus que disponible")
	st.free()
