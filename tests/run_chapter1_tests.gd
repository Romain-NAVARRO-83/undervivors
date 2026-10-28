extends SceneTree
## Tests automatisés du chapitre 1 « L'abri », sans fenêtre :
##   godot --headless --fixed-fps 60 --path . -s tests/run_chapter1_tests.gd
## On démarre directement au chapitre 1 (comme depuis le menu titre) et on
## enchaîne les étapes en téléportant le survivant contrôlé.

var _failures := 0
var _checks := 0
var _f := 0
## Scripts préchargés : le test marche même si le cache des noms de classes
## de Godot n'est pas encore à jour.
const Story := preload("res://scripts/story/prologue.gd")

var _p: Node
var _ch: Chapter1
var _c: Survivor
var _q: Array = []       # file d'actions : [frame, Callable]
var _thirst0 := 0.0


func _init() -> void:
	Story.start_chapter = 1
	_p = load("res://scenes/story.tscn").instantiate()
	root.add_child(_p)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("ÉCHEC : " + msg)


func at(frame: int, fn: Callable) -> void:
	_q.append([frame, fn])


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_setup_checks()
		_plan()
	for a in _q.duplicate():
		if a[0] == _f:
			a[1].call()
			_q.erase(a)
	if _q.is_empty() and _f > 2:
		print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
	return false


func _setup_checks() -> void:
	_ch = _p.chapter
	check(_ch != null, "on démarre au chapitre 1")
	check(_ch.step == Chapter1.Step.INTRO, "introduction du chapitre")
	_c = _p.controlled
	check(_c == _p.friend, "on dirige le second survivant, comme à la fin du prologue")
	check(_p.refuge.lit and _p.refuge.show_plot, "refuge allumé, emplacement de la cabane marqué")
	for s in _p.alive_survivors():
		check(s.weapon == null, "%s commence sans arme" % s.first_name)
		check(s.needs_enabled, "faim et soif actives au chapitre 1")
		check(s.hp_floor == 0, "plus de protection : mort définitive")
	check(_p.camera.limit_top <= int(BeachMap.NORTH_TOP), "la caméra monte jusqu'au nord de l'île")
	check(_p.get_tree().get_nodes_in_group("chests").size() == Chapter1.CHESTS.size(), "coffres placés")
	check(_p.stock.get_amount("bois") == 0, "pas de bois au départ")
	var planks := 0
	for n in _p.get_tree().get_nodes_in_group("item_pickups"):
		if n.item is ConsumableData and n.item.resource_type == "bois":
			planks += 1
	for e in Chapter1.CHESTS:
		for path in e[1]:
			if path == Chapter1.PLANK:
				planks += 1
	check(planks >= Chapter1.WOOD_NEEDED, "assez de planches sur la carte (%d)" % planks)
	_thirst0 = _c.thirst


func _plan() -> void:
	# Recul des armes : aucun pour le lance-pierre, net pour le fusil à pompe
	var spot: Vector2 = _p.REFUGE_POS + Vector2(260, -40)
	var res := {}
	for w in [["slingshot", 0.0], ["shotgun", 20.0], ["pistol", 6.0]]:
		var start := 20 + res.size() * 40
		res[w[0]] = Vector2.ZERO
		at(start, func():
			_c.weapon = load("res://data/weapons/%s.tres" % w[0])
			_c.global_position = spot
			_c._cooldown = 0.0
			_c.try_shoot(Vector2.RIGHT))
		at(start + 30, func():
			var moved: float = spot.x - _c.global_position.x
			if w[1] == 0.0:
				check(absf(moved) < 1.0, "%s : pas de recul (%.1f px)" % [w[0], moved])
			else:
				check(moved > w[1] * 0.6 and moved < w[1] * 2.0, "%s : recul vers l'arrière (%.1f px)" % [w[0], moved])
			_c.weapon = null)
	var f := 7 * 60 + 30
	at(f, func():
		check(_ch.step == Chapter1.Step.FIND_WEAPON, "objectif : trouver une arme")
		check(_p._arrow.target == Chapter1.SLINGSHOT_POS, "la flèche montre l'arme")
		check(_c.thirst < _thirst0, "la soif monte (%.1f → %.1f)" % [_thirst0, _c.thirst])
		Mob.harmless = true   # les monstres ne nous dérangent pas pendant le test
		# On franchit à pied l'ancienne limite nord du prologue
		_c.global_position = Vector2(-150, BeachMap.TOP + 60)
		Input.action_press("move_up"))
	f += 70
	at(f, func():
		Input.action_release("move_up")
		check(_c.global_position.y < BeachMap.TOP - 60, "le nord de l'île est ouvert (y = %.0f)" % _c.global_position.y)
		_c.global_position = Chapter1.SLINGSHOT_POS)
	f += 60
	at(f, func():
		check(_c.weapon != null and _c.weapon.resource_path == Survivor.SLINGSHOT_PATH, "lance-pierre ramassé à terre et équipé")
		check(_ch.step == Chapter1.Step.FIRST_FIGHT, "premier combat")
		check(is_instance_valid(_ch.first_mob), "un rongeur à abattre")
		# Tir un peu au-dessus des pieds du monstre (hauteur de buste) : il touche
		var m: Mob = _ch.first_mob
		m.set_physics_process(false)
		var pr := Projectile.new()
		pr.velocity = Vector2(560, 0)
		pr.damage = 1.0
		pr.max_distance = 200.0
		pr.color = Color.YELLOW
		pr.position = m.global_position + Vector2(-70, -20)
		_p.world.add_child(pr))
	f += 12
	at(f, func():
		var m: Mob = _ch.first_mob
		check(m.hp < m.max_hp, "la balle touche un monstre visé à hauteur de buste (PV %.0f/%.0f)" % [m.hp, m.max_hp])
		var fx := 0
		for n in _p.world.get_children():
			if n is HitEffect:
				fx += 1
		check(fx >= 1, "animation d'impact")
		m.set_physics_process(true)
		m.take_damage(999.0))
	f += 30
	at(f, func():
		check(_ch.step == Chapter1.Step.SUPPLIES, "objectif : provisions et bois")
		# La crique : trois planches, puis le coffre (deux bouteilles d'eau)
		for e in Chapter1.LOOT.slice(0, 3):
			_c.global_position = e[0]
			_physics_tick())
	f += 5
	at(f, func():
		check(_c.inventory.size() == 3, "trois planches dans le sac (%d)" % _c.inventory.size())
		_break_chest(0))
	f += 80
	at(f, func():
		_grab_near(Chapter1.CHESTS[0][0]))
	f += 10
	at(f, func():
		check(_c.inventory.size() == _c.bag_capacity(), "sac plein (%d/%d)" % [_c.inventory.size(), _c.bag_capacity()])
		var left := _pickups_near(Chapter1.CHESTS[0][0])
		check(left.size() == 1, "sac plein : un objet reste au sol (%d)" % left.size())
		_c.global_position = _p.REFUGE_POS + Vector2(6, 4))
	f += 10
	at(f, func():
		check(_p.stock.get_amount("bois") == 3, "trois planches au stock (%d)" % _p.stock.get_amount("bois"))
		check(_c.inventory.is_empty(), "sac vidé au feu")
		_grab_near(Chapter1.CHESTS[0][0]))
	f += 10
	# L'épave : quatre planches, puis le coffre (sarbacane + conserve)
	at(f, func():
		_c.global_position = _p.REFUGE_POS + Vector2(6, 4))
	f += 10
	at(f, func():
		for e in Chapter1.LOOT.slice(3, 7):
			_c.global_position = e[0]
			_physics_tick())
	f += 5
	at(f, func():
		check(_c.inventory.size() == 4, "quatre planches de l'épave (%d)" % _c.inventory.size())
		_c.global_position = _p.REFUGE_POS + Vector2(6, 4))
	f += 10
	at(f, func():
		check(_p.stock.get_amount("bois") == 7, "sept planches au stock (%d)" % _p.stock.get_amount("bois"))
		check(_ch.step == Chapter1.Step.SUPPLIES, "pas encore assez de bois")
		_break_chest(1))
	f += 80
	at(f, func():
		_grab_near(Chapter1.CHESTS[1][0]))
	f += 10
	at(f, func():
		check(_c.weapon != null and _c.weapon.resource_path == Chapter1.BLOWPIPE, "sarbacane trouvée et équipée")
		var kept := false
		for it in _c.inventory:
			if it is WeaponData and it.resource_path == Survivor.SLINGSHOT_PATH:
				kept = true
		check(kept, "le lance-pierre part dans le sac au lieu de disparaître")
		_c.global_position = _p.REFUGE_POS + Vector2(6, 4))
	f += 70
	at(f, func():
		var o: Survivor = _p.other_of(_c)
		check(o.weapon != null, "l'arme rapportée au feu va au survivant resté au camp")
		check(_ch.food_brought() == 3, "une conserve rapportée : 3 portions (%d)" % _ch.food_brought())
		# Le bosquet : deux conserves, le coffre (planches, conserve, eau)
		for e in Chapter1.LOOT.slice(7, 9):
			_c.global_position = e[0]
			_physics_tick()
		check(_c.inventory.size() == 2, "deux conserves du bosquet (%d)" % _c.inventory.size())
		_c.global_position = _p.REFUGE_POS + Vector2(6, 4))
	f += 10
	at(f, func():
		_break_chest(2))
	f += 80
	at(f, func():
		_grab_near(Chapter1.CHESTS[2][0]))
	f += 10
	at(f, func():
		_c.global_position = _p.REFUGE_POS + Vector2(6, 4))
	f += 10
	at(f, func():
		_c.global_position = _p.REFUGE_POS + Vector2(6, 4)
		check(_p.stock.get_amount("bois") >= Chapter1.WOOD_NEEDED, "assez de bois au stock (%d)" % _p.stock.get_amount("bois"))
		check(_ch.food_brought() >= Chapter1.FOOD_NEEDED, "assez de nourriture rapportée (%d)" % _ch.food_brought()))
	f += 5
	at(f, func():
		check(_ch.step == Chapter1.Step.BUILD, "objectif : construire la cabane")
		check(_p._arrow.target == _ch.plot_position(), "la flèche montre les piquets")
		# Escouade de deux : F, puis Tab
		var o: Survivor = _p.other_of(_c)
		check(_p.toggle_follow() and o.following, "F : l'autre nous suit")
		check(_p.switch_survivor() and _p.controlled == o, "Tab : on change de survivant")
		check(_c.following and not o.following, "l'escouade garde sa forme : l'ancien suit le nouveau")
		_c = _p.controlled
		_c.global_position = _p.REFUGE_POS + Vector2(300, 0)
		check(not _ch.try_build(), "trop loin des piquets pour construire")
		_c.global_position = _ch.plot_position() + Vector2(60, 40))
	f += 5
	at(f, func():
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_E
		ev.pressed = true
		Input.parse_input_event(ev))
	f += 5
	at(f, func():
		check(_ch.step == Chapter1.Step.BUILDING and is_instance_valid(_ch.cabin), "E : le chantier de la cabane démarre")
		check(_p.stock.get_amount("bois") < Chapter1.WOOD_NEEDED, "la cabane a coûté %d bois" % Chapter1.WOOD_NEEDED)
		check(_p.refuge.has_cabin, "les piquets laissent place au chantier")
		# Mort définitive pendant le chapitre : on garde la main sur l'autre
		var o: Survivor = _p.other_of(_c)
		o.take_damage(9999.0))
	f += 5
	at(f, func():
		check(_p.alive_survivors().size() == 1, "un survivant de moins")
		check(_p.get_tree().get_nodes_in_group("graves").size() == 1, "une tombe")
		check(_p.controlled == _c and _ch.step == Chapter1.Step.BUILDING, "le chapitre continue avec le survivant restant")
		_ch.cabin.finish())
	f += 10
	at(f, func():
		check(_ch.step == Chapter1.Step.DONE, "cabane debout : fin du chapitre"))
	f += 14 * 60
	at(f, func():
		check(_p._overlay.visible and _p._overlay_title.text == "Fin du chapitre 1", "écran de fin du chapitre 1")
		Mob.harmless = false)


## Le ramassage se fait en physique : on laisse passer une image.
func _physics_tick() -> void:
	for n in _p.get_tree().get_nodes_in_group("item_pickups"):
		if n.global_position.distance_to(_c.global_position) < 14.0 and n._t >= ItemPickup.PICKUP_DELAY:
			for body in [_c]:
				if body.try_pick_up(n.item):
					n.queue_free()


func _break_chest(i: int) -> void:
	for c in _p.get_tree().get_nodes_in_group("chests"):
		if c.global_position.distance_to(Chapter1.CHESTS[i][0]) < 2.0:
			c.take_damage(999.0)


func _pickups_near(p: Vector2) -> Array:
	var out := []
	for n in _p.get_tree().get_nodes_in_group("item_pickups"):
		if not n.is_queued_for_deletion() and n.global_position.distance_to(p) < 80.0:
			out.append(n)
	return out


func _grab_near(p: Vector2) -> void:
	for n in _pickups_near(p):
		_c.global_position = n.global_position
		_physics_tick()
