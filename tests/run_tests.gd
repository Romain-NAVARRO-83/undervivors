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
var _picker: Survivor
var _healer_bot: Mob
var _healer_hp := 0.0
var _wall_b: Building
var _turret_b: Turret
var _gunner: Survivor
var _basher: Mob
var _target_mob: Mob
var _wall_hp := 0.0
var _alerted: Survivor
var _victim: Survivor
var _biter: Mob
var _heal_hp := 0
var _count_before := 0
var _fx: Dictionary = {}
var _spitter: Mob
var _target: Survivor
var _pickups_mark := 0
var _walker: Survivor
var _pusher: Survivor
var _push_wall: Building
var _tower: Turret
var _gunner2: Survivor
var _melee_probe: Mob


func _init() -> void:
	test_name_generator()
	test_weapons()
	test_appearance()
	test_level_up()
	test_stock()
	test_needs()
	test_inventory()
	test_consumables()
	test_survivor_sprites()
	test_terrain()
	# Test de scène : cycle de récolte complet à la mare (se termine dans _process).
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		# Les tests de scène qui suivent supposent des monstres inoffensifs ;
		# les blessures sont testées à part, à la fin.
		Mob.harmless = true
		_main._select(null)  # personne n'est contrôlé
		_worker = _main.survivors[1]
		_main.assign_survivor(_worker, _main.resource_nodes[0])
		check(_worker.task_node == _main.resource_nodes[0], "survivant assigné à la mare")
		_main.assign_survivor(_main.survivors[3], _main.resource_nodes[1])
		check(_main.resource_nodes[1].resource_type == "nourriture", "les cocotiers donnent de la nourriture")
		var trees: Array = _main.get_tree().get_nodes_in_group("trees")
		check(trees.size() > 150, "%d arbres plantés" % trees.size())
		var clear := true
		for tr in trees:
			if IsoGround.in_village(BuildManager.world_to_tile(tr.global_position)):
				clear = false
			for n in _main.resource_nodes:
				if TreeField._dist_to_segment(tr.global_position, Vector2.ZERO, n.global_position) < 40.0:
					clear = false
		check(clear, "camp et couloirs vers les ressources dégagés")
		_main.assign_survivor(_main.survivors[2], _main.resource_nodes[2])
		check(_main.resource_nodes[2].resource_type == "bois", "la forêt donne du bois")
	if _frames == 1500:
		var eau: int = _main.stock.total_added.get("eau", 0)
		check(eau >= 2, "eau rapportée au stock (%d au total)" % eau)
		var food: int = _main.stock.total_added.get("nourriture", 0)
		check(food >= 2, "nourriture rapportée des cocotiers (%d au total)" % food)
		var wood: int = _main.stock.total_added.get("bois", 0)
		check(wood >= 2, "bois rapporté de la forêt (%d au total)" % wood)
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
	if _frames == 1960:
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
	if _frames == 2020:
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
	if _frames == 2023:
		check(not _main.squad_bar.visible, "mode gestion : la barre d'escouade est masquée")
	if _frames == 2025:
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
		check(unhurt, "debug « monstres inoffensifs » : aucun survivant blessé")
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
		# Stock plein : le récolteur de la mare se met en pause, puis reprend sous 50 %.
		_main._select(null)
		_picker = _main.survivors[1]
		_picker.carrying = 0
		_picker.thirst = 100.0
		_picker.hunger = 100.0
		_picker.global_position = Vector2(20, 10)
		_main.assign_survivor(_picker, _main.resource_nodes[0])
		_main.stock.add("eau", 99)
		# Soin des bots dans la zone d'un générateur actif
		for sp in _main.get_tree().get_nodes_in_group("spawners"):
			if not sp.is_destroyed:
				_healer_bot = sp.spawn_mob()
				if _healer_bot == null:
					sp.max_alive += 1
					_healer_bot = sp.spawn_mob()
				break
	if _frames == 3292:
		_healer_bot.take_damage(15.0)
		_healer_hp = _healer_bot.hp
	if _frames == 3340:
		check(_picker.work_paused, "stock d'eau plein : le récolteur fait une pause")
		check(_picker.activity_text().begins_with("En pause"), "son activité l'indique : « %s »" % _picker.activity_text())
		var tile_badge: String = _picker.task_node.resource_type
		check(tile_badge == "eau", "badge d'assignation eau sur sa vignette")
		_picker.thirst = 100.0
		_picker.hunger = 100.0
		_main.stock.take("eau", 99)
	if _frames == 3345:
		check(not _picker.work_paused, "stock sous 50 % : il reprend la récolte tout seul")
	if _frames == 3420:
		check(is_instance_valid(_healer_bot) and _healer_bot.hp > _healer_hp + 2.0, "un bot dans la zone d'un générateur se soigne (%.0f → %.0f PV)" % [_healer_hp, _healer_bot.hp])
	if _frames == 3421:
		# --- Constructions ---
		var bm: BuildManager = _main.build_manager
		_main.wave_manager.kill_all()
		_main.stock.take("bois", 999)
		var t_wall := BuildManager.world_to_tile(Vector2(-160, 60))
		check(bm.place("mur", t_wall) == null, "pas de bois : construction refusée")
		_main.stock.add("bois", 20)
		_wall_b = bm.place("mur", t_wall)
		check(_wall_b != null and _main.stock.get_amount("bois") == 18, "mur posé : 2 bois dépensés")
		check(_wall_b != null and not _wall_b.is_built, "le mur commence en chantier")
		check(bm.place("mur", t_wall) == null, "case déjà occupée : refus")
		check(bm.check_tile(BuildManager.world_to_tile(Vector2(Terrain.RIDGE_X, -250)), "mur") != "", "impossible de construire sur la crête")
		check(bm.check_tile(BuildManager.world_to_tile(Vector2(700, -300)), "mur").begins_with("Seulement"), "hors de la place du camp : construction refusée")
		check(IsoGround.in_village(BuildManager.world_to_tile(Vector2(300, 0))), "la place du camp est agrandie (300 px à l'est du feu est constructible)")
		_turret_b = bm.place("tourelle", BuildManager.world_to_tile(Vector2(-60, 140)))
		check(_turret_b != null and _main.stock.get_amount("bois") == 12, "tourelle posée : 6 bois dépensés")
	if _frames == 3421 + 260:
		check(_wall_b.is_built and is_equal_approx(_wall_b.hp, _wall_b.max_hp), "le chantier du mur se termine tout seul (4 s)")
		check(not _turret_b.is_built, "la tourelle prend plus de temps (8 s)")
		_turret_b.finish()
		check(_main.get_task_targets().has(_turret_b), "la tourelle terminée apparaît dans les tâches")
		_gunner = _main.survivors[3]
		_main._select(null)
		_gunner.thirst = 100.0
		_gunner.hunger = 100.0
		_main.assign_survivor(_gunner, _turret_b)
		check(_gunner.post == _turret_b and _turret_b.gunner == _gunner, "survivant assigné à la tourelle")
		# Monstre collé au mur : il le frappe
		_basher = Mob.new()
		_basher.posted = true
		_basher.home = _wall_b.global_position + Vector2(-40, 0)  # contre la pointe ouest du losange
		_basher.aggro_range = 0.0
		_basher.position = _basher.home
		_main.world.add_child(_basher)
		_wall_hp = _wall_b.hp
	if _frames == 3421 + 560:
		check(_gunner.manning and _turret_b.is_manned(), "le servant est à son poste")
		check(not is_instance_valid(_basher) or _wall_b.hp < _wall_hp, "un monstre au contact abîme le mur (%.0f → %.0f)" % [_wall_hp, _wall_b.hp])
		# Cible pour la tourelle
		_target_mob = Mob.new()
		_target_mob.posted = true
		_target_mob.home = _turret_b.global_position + Vector2(260, -40)
		_target_mob.aggro_range = 0.0
		_target_mob.position = _target_mob.home
		_main.world.add_child(_target_mob)
		var t_kill := _wall_b.tile
		_wall_b.take_damage(9999.0)
		check(_wall_b.is_destroyed and not _main.build_manager.occupied.has(t_kill), "mur détruit : la case se libère")
	if _frames == 3421 + 800:
		check(not is_instance_valid(_target_mob) or not _target_mob.is_alive(), "la tourelle servie abat le monstre à portée")
		# --- Alerte ---
		_main._select(null)
		_alerted = _main.survivors[2]
		_alerted.thirst = 100.0
		_alerted.hunger = 100.0
		_main.assign_survivor(_alerted, _main.resource_nodes[2])
		_alerted.global_position = Vector2(-190, -250)
		_main.set_alert(true)
		check(Survivor.alert and _main.alert_banner.visible, "alerte déclenchée")
	if _frames == 3421 + 1100:
		check(_alerted.global_position.distance_to(Vector2.ZERO) < 80.0, "alerte : le récolteur est rentré au camp (%.0f px)" % _alerted.global_position.distance_to(Vector2.ZERO))
		check(_gunner.post == _turret_b, "alerte : le servant reste à sa tourelle")
		check(_alerted.activity_text() == "Alerte : défend le camp", "activité : défend le camp")
		_main.set_alert(false)
		check(not Survivor.alert and _alerted.task_node == _main.resource_nodes[2], "alerte levée : il garde sa tâche et la reprend")
		# --- Blessures : les monstres mordent ---
		Mob.harmless = false
		_main.wave_manager.kill_all()
		for m in _main.get_tree().get_nodes_in_group("mobs"):
			if is_instance_valid(m) and m.is_alive():
				m.take_damage(9999.0)
		_victim = _main.survivors[4]
		_main._select(_victim)  # contrôlé : il reste sur place
		_victim.global_position = Vector2(-190, -250)
		_victim.hp = _victim.max_hp
		_victim.thirst = 100.0
		_victim.hunger = 100.0
		_biter = Mob.new()
		_biter.posted = true
		_biter.home = _victim.global_position + Vector2(14, 0)
		_biter.position = _biter.home
		_main.world.add_child(_biter)
		_biter.max_hp = 5000.0  # encaisse les tirs des autres le temps du test
		_biter.hp = 5000.0
	if _frames == 4521 + 150:
		check(_victim.hp < _victim.max_hp, "un monstre au contact mord le survivant (%d / %d PV)" % [_victim.hp, _victim.max_hp])
		var lost := _victim.max_hp - _victim.hp
		check(lost >= 8 and lost <= 24, "dégâts cohérents : %d PV en 2,5 s pour un monstre" % lost)
		if is_instance_valid(_biter):
			_biter.take_damage(99999.0)
		# Gravement blessé et libre, hors du camp : il rentre se soigner.
		check(not _victim.in_camp(), "la victime est hors du camp")
		_victim.hp = 20
		_main._select(null)
		_victim._since_hit = 99.0
	if _frames == 4521 + 160:
		check(_victim.activity_text() == "Blessé : rentre se soigner", "sous 30 %% PV : « %s »" % _victim.activity_text())
	if _frames == 4521 + 700:
		check(_victim.in_camp(), "le blessé est rentré au camp")
		_heal_hp = _victim.hp
	if _frames == 4521 + 1000:
		check(_victim.hp >= _heal_hp + 12, "soin lent au camp (%d → %d PV en 5 s)" % [_heal_hp, _victim.hp])
		# Mort définitive : tombe, survivant retiré.
		var dying: Survivor = _main.survivors[3]
		_count_before = _main.survivors.size()
		dying.hp = 5
		dying.take_damage(8.0)
		dying.take_damage(8.0)  # deux morsures la même image : une seule mort
		check(_main.survivors.size() == _count_before - 1, "mort définitive : le survivant est retiré du groupe")
		check(not dying.is_alive(), "il n'est plus vivant")
	if _frames == 4521 + 1005:
		var graves: Array = _main.get_tree().get_nodes_in_group("graves")
		check(graves.size() == 1, "une tombe marque l'endroit de sa mort")
		check(graves.size() == 1 and "R.I.P." in (graves[0].get_child(0) as Label).text, "la tombe porte son nom")
		_test_mob_types_and_levels()
		_test_elements_start()
		_test_spitter_start()
	if _frames == 5526 + 60:
		_test_elements_after_1s()
	if _frames == 5526 + 200:
		_test_elements_end()
		_test_spitter_end()
		_test_squad_focus()
		_test_walls_start()
	if _frames == 5726 + 30:
		_test_walls_block()
	if _frames == 5726 + 560:
		_test_walls_end()
		_test_gunner_start()
	if _frames == 5726 + 900:
		_test_gunner_end()
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
	check(s.carry_capacity() == 8, "niveau 3 → porte 8 par trajet")
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
	var a := Vector2(Terrain.RIDGE_X - 300, -200)
	var b := Vector2(Terrain.RIDGE_X + 300, -200)
	var wp := Terrain.route(a, b)
	check(wp.x < Terrain.RIDGE_X and absf(wp.y - Terrain.GAP_Y) < 1.0, "pour traverser la crête, on passe par l'entrée du passage")
	check(Terrain.route(a, Vector2(Terrain.RIDGE_X - 600, 300)) == Vector2(Terrain.RIDGE_X - 600, 300), "même côté : trajet direct")
	var inside := Terrain.route(Vector2(Terrain.RIDGE_X - 20, 5), b)
	check(inside.x > Terrain.RIDGE_X, "dans le passage : on file vers l'autre côté")


func test_stock() -> void:
	var cap := VillageStock.new()
	check(cap.add("eau", 14) == 10 and cap.is_full("eau"), "stock plafonné à 10")
	check(cap.add("bois", 30) == 20, "stock de bois plafonné à 20")
	check(not cap.needs_restock("eau"), "stock plein : pas besoin de récolter")
	cap.take("eau", 6)
	check(cap.needs_restock("eau"), "sous 50 % : la récolte doit reprendre")
	cap.free()
	var st := VillageStock.new()
	st.add("eau", 5)
	check(st.get_amount("eau") == 5, "stock : ajout")
	check(st.take("eau", 8) == 5 and st.get_amount("eau") == 0, "stock : on ne prend pas plus que disponible")
	st.free()


# --- Monstres : types, niveaux, zones, spécial ------------------------------

func _spawn_test_mob(type_id: String, pos: Vector2, level := 1) -> Mob:
	var m := Mob.new()
	m.mob_type = MobType.by_id(type_id)
	m.level = level
	m.posted = true
	m.home = pos
	m.aggro_range = 0.0  # ne bouge pas, n'attaque pas
	m.wander_radius = 0.0
	m.position = pos
	m.world = _main.world
	_main.world.add_child(m)
	return m


func _test_mob_types_and_levels() -> void:
	for id in MobType.TYPE_IDS:
		check(MobType.by_id(id) != null, "type de monstre « %s » chargé" % id)
	check(MobType.by_id("cracheur").attack == MobType.Attack.DISTANCE, "le cracheur attaque à distance")
	check(MobType.by_id("cogneur").max_hp > MobType.by_id("rongeur").max_hp * 3.0, "le cogneur est bien plus solide")
	check(MobType.by_id("feu_follet").speed > MobType.by_id("rongeur").speed, "le feu follet est rapide")
	var r1 := _spawn_test_mob("rongeur", Vector2(-600, 450), 1)
	var r3 := _spawn_test_mob("rongeur", Vector2(-640, 450), 3)
	check(is_equal_approx(r1.max_hp, 30.0) and is_equal_approx(r3.max_hp, 42.0), "niveau 3 : +40 %% de PV (%.0f → %.0f)" % [r1.max_hp, r3.max_hp])
	check(is_equal_approx(r3.damage, 8.0 * 1.3) and r3.xp_reward == 30, "niveau 3 : +30 %% de dégâts, +50 %% d'XP")
	r1.take_damage(999.0)
	r3.take_damage(999.0)
	# Zones de niveau
	check(LevelZones.level_at(Vector2(100, 50)) == 1, "zone du camp : niveau 1")
	check(LevelZones.level_at(Vector2(-950, -300)) == 2, "côte ouest : niveau 2")
	check(LevelZones.level_at(Vector2(1300, -420)) == 3, "au-delà de la crête : niveau 3")
	_main.setup_map_enemies()
	var ok := true
	for m in _main.get_tree().get_nodes_in_group("mobs"):
		if m.posted and not m.special and not m.is_queued_for_deletion() and m.level != LevelZones.level_at(m.home):
			if not _main.get_tree().get_nodes_in_group("spawners").any(func(sp): return sp._mobs.has(m)):
				ok = false
	check(ok, "les ennemis postés ont le niveau de leur zone")
	# Monstre spécial
	var boss: Mob = null
	for m in _main.get_tree().get_nodes_in_group("special_mobs"):
		if not m.is_queued_for_deletion():
			boss = m
	check(boss != null and boss.display_name() == "Le Vieux Cogneur", "un monstre spécial est posté sur la carte")
	if boss:
		check(boss.level == 4 and boss.max_hp > 500.0, "monstre spécial : niveau 4, %.0f PV" % boss.max_hp)
		_pickups_mark = _main.get_tree().get_nodes_in_group("item_pickups").size()
		boss.take_damage(99999.0)


func _test_elements_start() -> void:
	_main.wave_manager.kill_all()
	for m in _main.get_tree().get_nodes_in_group("mobs"):
		if m.is_alive():
			m.take_damage(9999.0)
	var base := Vector2(-560, 330)
	# Feu follet : immunisé au feu (ni dégâts de feu ni brûlure), faible à la glace.
	var wisp := _spawn_test_mob("feu_follet", base)
	wisp.take_hit(2.0, WeaponData.Element.FEU, 10.0, null)
	check(is_equal_approx(wisp.hp, 18.0) and wisp._burn_time <= 0.0, "feu follet immunisé au feu (%.0f PV)" % wisp.hp)
	wisp.take_hit(0.0, WeaponData.Element.GLACE, 2.0, null)
	check(wisp._slow > Mob.SLOW_BASE and wisp.current_speed() < wisp.speed * 0.5, "glace sur un feu follet (faible) : très ralenti")
	check(is_equal_approx(wisp.hp, 14.0), "faiblesse : dégâts de glace doublés")
	# Brûlure sur un rongeur
	var burned := _spawn_test_mob("rongeur", base + Vector2(200, 0))
	burned.take_hit(0.0, WeaponData.Element.FEU, 4.0, null)
	_fx["burn_hp"] = burned.hp
	_fx["burned"] = burned
	# Poison cumulable
	var poisoned := _spawn_test_mob("rongeur", base + Vector2(200, 80))
	for i in 3:
		poisoned.take_hit(0.0, WeaponData.Element.POISON, 2.0, null)
	check(poisoned._poison_stacks == 3, "le poison se cumule (3 doses)")
	_fx["poisoned"] = poisoned
	_fx["poison_hp"] = poisoned.hp
	# Électrique : arc vers les voisins
	var center := _spawn_test_mob("cogneur", base + Vector2(0, 160))
	var n1 := _spawn_test_mob("rongeur", base + Vector2(40, 160))
	var n2 := _spawn_test_mob("rongeur", base + Vector2(-40, 170))
	var far := _spawn_test_mob("rongeur", base + Vector2(200, 160))
	center.take_hit(0.0, WeaponData.Element.ELECTRIQUE, 10.0, null)
	check(is_equal_approx(center.hp, 120.0 - 15.0), "cogneur faible à l'électricité (%.0f PV)" % center.hp)
	check(n1.hp < n1.max_hp and n2.hp < n2.max_hp, "l'arc électrique touche les voisins")
	check(is_equal_approx(far.hp, far.max_hp), "l'arc ne touche pas les monstres éloignés")


func _test_elements_after_1s() -> void:
	var burned: Mob = _fx["burned"]
	check(is_instance_valid(burned) and burned.hp < _fx["burn_hp"] - 1.0, "la brûlure fait des dégâts dans la durée (%.1f → %.1f)" % [_fx["burn_hp"], burned.hp])


func _test_elements_end() -> void:
	var burned: Mob = _fx["burned"]
	check(burned._burn_time <= 0.0, "la brûlure s'éteint au bout de 3 s")
	var poisoned: Mob = _fx["poisoned"]
	var lost: float = _fx["poison_hp"] - poisoned.hp
	check(lost > 3.0, "le poison (3 doses) ronge le monstre (%.1f PV perdus)" % lost)
	var n := _main.get_tree().get_nodes_in_group("item_pickups").size()
	check(n >= _pickups_mark + 2, "le monstre spécial laisse du butin (%d objets)" % (n - _pickups_mark))


# --- Cracheur : attaque à distance ------------------------------------------

func _test_spitter_start() -> void:
	_target = _main.survivors[0]
	_main._select(_target)
	_target.global_position = Vector2(-620, -60)
	_target.hp = _target.max_hp
	_target._since_hit = 0.0
	_spitter = Mob.new()
	_spitter.mob_type = MobType.by_id("cracheur")
	_spitter.posted = true
	_spitter.home = _target.global_position + Vector2(-200, 0)
	_spitter.position = _spitter.home
	_spitter.world = _main.world
	_main.world.add_child(_spitter)
	_spitter.max_hp = 5000.0
	_spitter.hp = 5000.0


func _test_spitter_end() -> void:
	check(_target.hp < _target.max_hp, "le cracheur touche le survivant à distance (%d PV)" % _target.hp)
	var d := _spitter.global_position.distance_to(_target.global_position)
	check(d > 60.0, "le cracheur garde ses distances (%.0f px)" % d)


# --- Escouade : tir groupé sur un coffre ------------------------------------

func _test_squad_focus() -> void:
	for m in _main.get_tree().get_nodes_in_group("mobs"):
		if is_instance_valid(m) and m.is_alive():
			m.take_damage(99999.0)
	_main.set_squad_mode(false)
	_main._select(null)
	for m in _main.squad.duplicate():
		_main.toggle_squad_member(m)
	var members: Array = _main.survivors.slice(0, 3)
	for m in members:
		_main.toggle_squad_member(m)
	_main.set_squad_mode(true)
	var leader: Survivor = _main.selected
	var follower: Survivor = members[1] if members[0] == leader else members[0]
	follower.global_position = leader.global_position + Vector2(-20, 10)
	var chest := LootChest.new()
	chest.max_hp = 9999.0
	chest.world = _main.world
	chest.position = leader.global_position + Vector2(120, 0)
	_main.world.add_child(chest)
	var p := Projectile.new()
	p.shooter = leader
	p.damage = 1.0
	p._on_body_entered(chest)
	check(Survivor.squad_focus == chest, "le leader tire sur un coffre : il devient la cible de l'escouade")
	follower._cooldown = 0.0
	follower._autonomous_shooting()
	var to_chest := (chest.global_position - follower.global_position).normalized()
	check(follower.aim_dir.dot(to_chest) > 0.99, "les suiveurs visent le coffre")
	chest.is_broken = true
	check(not Survivor._focus_valid() and Survivor.squad_focus == null, "coffre cassé : fin du tir groupé")
	Survivor.squad_focus = chest
	_main.set_squad_mode(false)
	check(Survivor.squad_focus == null, "fin du mode escouade : plus de cible commune")
	p.free()


# --- Constructions infranchissables, pas d'enceinte fermée -----------------

func _test_walls_start() -> void:
	for m in _main.get_tree().get_nodes_in_group("mobs"):
		if is_instance_valid(m) and m.is_alive():
			m.take_damage(99999.0)
	var bm: BuildManager = _main.build_manager
	for b in _main.get_tree().get_nodes_in_group("buildings"):
		b.take_damage(99999.0)
	bm.free_build = true
	bm.instant = true
	# Enceinte : entourer une case par ses 4 côtés est refusé au 4e mur.
	var c := Vector2i(-3, -3)
	check(bm.place("mur", c + Vector2i(1, 0)) != null, "mur 1/4 autour d'une case")
	check(bm.place("mur", c + Vector2i(-1, 0)) != null, "mur 2/4")
	check(bm.place("mur", c + Vector2i(0, 1)) != null, "mur 3/4")
	check(bm.check_tile(c + Vector2i(0, -1), "mur").begins_with("Fermerait une enceinte"), "le mur qui fermerait l'enceinte est refusé")
	check(bm.place("mur", c + Vector2i(0, -1)) == null, "la pose est bien bloquée")
	check(bm.check_tile(c + Vector2i(1, -1), "mur") == "", "un mur à côté qui laisse un passage reste possible")
	# Coins : deux constructions qui se touchent par un coin ferment aussi le passage.
	check(Nav.would_enclose(Vector2i(5, 5)) == false, "case isolée : pas d'enceinte")
	# Ligne de murs entre un survivant et le camp : il la contourne.
	for t in [Vector2i(-7, -3), Vector2i(-6, -4), Vector2i(-5, -5), Vector2i(-4, -6), Vector2i(-3, -7)]:
		bm.place("mur", t)
	var a := Vector2(0, -260)
	check(not Nav.segment_clear(a, Vector2.ZERO), "la ligne de murs coupe la ligne droite vers le camp")
	var w := Nav.route(a, Vector2.ZERO)
	check(absf(w.x) > 100.0, "Nav propose un détour par le côté (x = %.0f)" % w.x)
	_main._select(null)
	_walker = _main.survivors[1]
	_walker.task_node = null
	_walker.post = null
	_walker.thirst = 100.0
	_walker.hunger = 100.0
	_walker.hp = _walker.max_hp
	_walker.global_position = a
	_main.set_alert(true)
	# Survivant contrôlé qui pousse contre un mur : il ne passe pas.
	_pusher = _main.survivors[0]
	_main._select(_pusher)
	_push_wall = bm.place("mur", Vector2i(4, -4))
	_pusher.global_position = _push_wall.global_position + Vector2(-70, 0)
	Input.action_press("move_right")


func _test_walls_block() -> void:
	Input.action_release("move_right")
	check(_pusher.global_position.x < _push_wall.global_position.x - 20.0, "un survivant ne traverse pas un mur (x = %.0f, mur à %.0f)" % [_pusher.global_position.x, _push_wall.global_position.x])
	_main._select(null)


func _test_walls_end() -> void:
	var d := _walker.global_position.distance_to(Vector2.ZERO)
	check(d < 90.0, "en contournant les murs, le survivant rejoint le camp (%.0f px)" % d)
	_main.set_alert(false)


# --- Servant perché sur sa tourelle, bouton pour le libérer ----------------

func _test_gunner_start() -> void:
	var bm: BuildManager = _main.build_manager
	_tower = bm.place("tourelle", Vector2i(2, 5))
	check(_tower != null and _tower.is_built, "tourelle posée (chantier instantané)")
	_main._select(null)
	_gunner2 = _main.survivors[2]
	_gunner2.thirst = 100.0
	_gunner2.hunger = 100.0
	_gunner2.hp = _gunner2.max_hp
	_gunner2.global_position = _tower.global_position + Vector2(0, 90)
	_main.assign_survivor(_gunner2, _tower)


func _test_gunner_end() -> void:
	check(_gunner2.manning and _tower.is_manned(), "le servant est monté sur sa tourelle")
	check(_gunner2.global_position.distance_to(_tower.top_point()) < 1.0, "il se tient sur la plateforme")
	check(_gunner2.z_index > 0, "il est dessiné au-dessus du bloc")
	check(_tower._release_btn.visible and "Libérer" in _tower._release_btn.text, "bouton « %s » au-dessus de la tourelle" % _tower._release_btn.text)
	# Un monstre au corps à corps ne le cible pas ; un cracheur, si.
	var melee := _spawn_test_mob("rongeur", _tower.global_position + Vector2(0, -60))
	melee.aggro_range = 400.0
	check(melee._nearest_survivor() != _gunner2, "un monstre au corps à corps ne peut pas viser le servant perché")
	var spit := _spawn_test_mob("cracheur", _tower.global_position + Vector2(0, -60))
	spit.aggro_range = 400.0
	check(spit._nearest_survivor() == _gunner2 or spit._nearest_survivor() != null, "un cracheur peut le viser")
	melee.take_damage(9999.0)
	spit.take_damage(9999.0)
	# Bouton : on le libère, il redescend devant la tourelle.
	_tower._release_btn.pressed.emit()
	check(_gunner2.post == null and not _gunner2.manning and _tower.gunner == null, "bouton Libérer : servant dissocié")
	check(_gunner2.global_position.distance_to(_tower.mount_point()) < 1.0 and _gunner2.z_index == 0, "il redescend devant la tourelle")
	_tower._process(0.016)
	check(not _tower._release_btn.visible, "plus de servant : le bouton disparaît")



# --- Unités consommables (eau, nourriture) ---------------------------------

func test_consumables() -> void:
	var water: ConsumableData = load("res://data/items/eau.tres")
	var food: ConsumableData = load("res://data/items/nourriture.tres")
	check(water.resource_type == "eau" and food.resource_type == "nourriture", "unités d'eau et de nourriture")
	check(LootTable.item_name(water) == "Bouteille d'eau", "nom de l'unité d'eau")
	var s := Survivor.new()
	s.inventory.append(water.instance())
	s.inventory.append(food.instance())
	s.thirst = 80.0
	check(not s._consume_from_bag("eau"), "pas soif : il garde sa bouteille")
	s.thirst = 20.0
	check(s._consume_from_bag("eau") and is_equal_approx(s.thirst, 45.0), "il a soif et porte de l'eau : il la boit (soif %.0f)" % s.thirst)
	check(water.amount == 3 and food.amount == 3, "une bouteille et une conserve font 3 portions")
	check(s.inventory.size() == 2 and s.inventory[0].remaining() == 2, "il reste 2 portions dans la bouteille")
	s.thirst = 20.0
	check(s._consume_from_bag("eau") and s.inventory[0].remaining() == 1, "deuxième gorgée")
	s.thirst = 20.0
	check(s._consume_from_bag("eau") and s.inventory.size() == 1 and s.inventory[0].resource_type == "nourriture", "bouteille vide : elle quitte le sac")
	s.thirst = 20.0
	check(not s._consume_from_bag("eau"), "plus d'eau dans le sac")
	s.hunger = 10.0
	check(s._consume_from_bag("nourriture") and s.inventory.size() == 1, "il a faim : il mange une portion, la conserve reste")
	# Au feu de camp : les unités vont dans le stock du village
	var st := VillageStock.new()
	s.stock = st
	s.inventory.clear()
	s.inventory.append(water.instance())
	s.inventory.append(water.instance())
	s._deposit_inventory()
	check(st.get_amount("eau") == 6 and s.inventory.is_empty(), "portions déposées au stock (eau %d)" % st.get_amount("eau"))
	# Stock presque plein : le reste de la bouteille reste dans le sac
	s.inventory.append(water.instance())
	s.inventory.append(water.instance())
	s._deposit_inventory()
	check(st.get_amount("eau") == 10 and s.inventory.size() == 1 and s.inventory[0].remaining() == 2, "stock plein : la bouteille entamée reste dans le sac")
	check(water.used == 0, "la ressource partagée n'est jamais entamée")
	check(st.items.is_empty(), "elles ne vont pas dans le stock d'objets")
	st.free()
	s.free()



# --- Sprites 3D pré-rendus des survivants ----------------------------------

func test_survivor_sprites() -> void:
	for style in SurvivorSprite.STYLE_FILES:
		check(SurvivorSprite.available(style), "planches présentes : %s" % SurvivorSprite.STYLE_FILES[style])
	var tex: Texture2D = load("res://assets/survivors/court_shade.png")
	check(tex.get_width() == 128 * 7 and tex.get_height() == 160 * 8, "planche 7 × 8 images de 128 × 160")
	check(SurvivorSprite.dir_index(Vector2(1, 0)) == 0, "direction est")
	check(SurvivorSprite.dir_index(Vector2(0, 1)) == 2, "direction face (sud)")
	check(SurvivorSprite.dir_index(Vector2(-1, 0)) == 4, "direction ouest")
	check(SurvivorSprite.dir_index(Vector2(0, -1)) == 6, "direction dos (nord)")
	check(SurvivorSprite.dir_index(Vector2(1, 0.5)) == 1, "diagonale iso sud-est")
	check(SurvivorSprite.dir_index(Vector2(-1, -0.5)) == 5, "diagonale iso nord-ouest")
	var sp := SurvivorSprite.new()
	var a := SurvivorAppearance.new()
	a.hair_style = SurvivorAppearance.HairStyle.LONG
	sp.setup(a)
	check(sp.hframes == 7 and sp.vframes == 8, "découpage de la planche")
	sp.animate(Vector2(-1, 0), Vector2.ZERO, 0.1, 0.0)
	check(sp.frame == 4 * 7, "à l'arrêt vers l'ouest : image de repos (%d)" % sp.frame)
	var seen := {}
	for i in 12:
		sp.animate(Vector2(0, 1), Vector2(0, 150), 1.0 / 30.0, 0.0)
		seen[sp.frame] = true
	check(seen.size() >= 3 and not seen.has(2 * 7), "en marchant vers le bas : images de marche qui défilent")
	sp.free()
