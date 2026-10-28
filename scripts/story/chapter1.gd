class_name Chapter1
extends Node
## Mode histoire — Chapitre 1 « L'abri ».
##
## Suite directe du prologue, sur la même carte agrandie vers le nord.
## 1. Les deux survivants sont au refuge. Faim et soif reprennent : il faudra
##    manger et boire. L'un reste au camp (il montera la cabane), l'autre
##    explore.
## 2. Une arme traîne à terre au nord du refuge (un lance-pierre, dans une
##    valise éventrée) : on la ramasse en passant dessus. Pas de corps à corps.
## 3. Premier combat : un rongeur.
## 4. Exploration libre de trois coins : la crique (ouest, bois flotté),
##    l'épave (nord-est, planches et un coffre) et le bosquet (nord, plus
##    dangereux, plus de provisions). On ramasse du loot dans le sac et on le
##    rapporte au feu : il faut du bois pour la cabane et de quoi manger.
## 5. Assez de bois au stock : on construit la cabane sur l'emplacement marqué.
## 6. La cabane est debout : fin du chapitre.

enum Step { INTRO, FIND_WEAPON, FIRST_FIGHT, SUPPLIES, BUILD, BUILDING, DONE }

const WOOD_NEEDED := Cabin.COST
## Portions de nourriture à rapporter (une conserve en fait 3).
const FOOD_NEEDED := 6
## Après ce délai sans rien ramasser, la flèche montre le loot le plus proche.
const HINT_DELAY := 45.0

const SLINGSHOT_POS := Vector2(-40, -1240)
const FIRST_MOB_POS := Vector2(220, -1430)

const PLANK := "res://data/items/planche.tres"
const WATER := "res://data/items/eau.tres"
const FOOD := "res://data/items/nourriture.tres"
const BLOWPIPE := "res://data/weapons/blowpipe.tres"

## Objets au sol : [position, ressource].
const LOOT := [
	# La crique (ouest) : bois flotté
	[Vector2(-1180, -1420), PLANK], [Vector2(-990, -1550), PLANK], [Vector2(-1240, -1590), PLANK],
	# L'épave (nord-est) : planches arrachées
	[Vector2(760, -1600), PLANK], [Vector2(950, -1580), PLANK], [Vector2(1020, -1730), PLANK], [Vector2(790, -1790), PLANK],
	# Le bosquet (nord) : conserves
	[Vector2(-270, -2000), FOOD], [Vector2(-30, -2120), FOOD],
]
## Coffres : [position, contenu].
const CHESTS := [
	[Vector2(-1070, -1390), [WATER, WATER]],
	[Vector2(690, -1700), [BLOWPIPE, FOOD]],
	[Vector2(-150, -2080), [PLANK, PLANK, FOOD, WATER]],
]
## Monstres postés : [position, type, niveau].
const MOBS := [
	[Vector2(-930, -1430), "rongeur", 1], [Vector2(-1160, -1660), "rongeur", 1],
	[Vector2(820, -1550), "rongeur", 1], [Vector2(1030, -1630), "rongeur", 1], [Vector2(900, -1830), "cracheur", 1],
	[Vector2(-330, -2120), "rongeur", 2], [Vector2(30, -1990), "cracheur", 2], [Vector2(-150, -2240), "rongeur", 2],
]

var story: Node            # le prologue (scène du mode histoire), qui porte la carte et l'interface
var step: Step = Step.INTRO
var first_mob: Mob
var cabin: Cabin
var loot: Array[Node2D] = []   # objets au sol et coffres encore à prendre
var _step_t := 0.0
var _since_pickup := 0.0
var _food_base := 0
var _handoff_t := 0.0
var _last_bag := -1
var _fought := false


func start() -> void:
	story.open_north()
	_food_base = story.stock.total_added.get("nourriture", 0)
	for s in story.alive_survivors():
		s.needs_enabled = true          # faim et soif reprennent
		s.keep_replaced_weapon = true
		s.hp_floor = 0                  # fini la protection du prologue : mort définitive
		s.thirst = maxf(s.thirst, 85.0)
		s.hunger = maxf(s.hunger, 85.0)
	story.refuge.show_plot = true
	_place_content()
	_advance(Step.INTRO)


# --- Contenu ----------------------------------------------------------------

func _place_content() -> void:
	var world: Node2D = story.world
	# Le lance-pierre, dans une valise éventrée
	var suitcase := Wreck.new()
	suitcase.kind = Wreck.Kind.SUITCASE
	suitcase.position = SLINGSHOT_POS + Vector2(-26, -12)
	world.add_child(suitcase)
	_add_pickup(SLINGSHOT_POS, load("res://data/weapons/slingshot.tres"))
	# L'épave du nord-est : un second gros morceau, qui fume encore
	for p in [[Wreck.Kind.HULL, BeachMap.WRECK2_CENTER], [Wreck.Kind.PANEL, BeachMap.WRECK2_CENTER + Vector2(-110, 60)],
			[Wreck.Kind.SEAT, BeachMap.WRECK2_CENTER + Vector2(120, 30)], [Wreck.Kind.PANEL, BeachMap.WRECK2_CENTER + Vector2(60, -110)],
			[Wreck.Kind.SUITCASE, BeachMap.WRECK2_CENTER + Vector2(-60, -90)]]:
		var w := Wreck.new()
		w.kind = p[0]
		w.position = p[1]
		world.add_child(w)
	for entry in LOOT:
		_add_pickup(entry[0], load(entry[1]))
	for entry in CHESTS:
		var c := LootChest.new()
		c.position = entry[0]
		c.world = world
		for path in entry[1]:
			c.contents.append(load(path))
		c.broken.connect(func(_c): _since_pickup = 0.0)
		world.add_child(c)
		loot.append(c)
	for entry in MOBS:
		_add_mob(entry[0], entry[1], entry[2])
	_place_decor()


func _add_pickup(pos: Vector2, item: Resource) -> ItemPickup:
	var p := ItemPickup.new()
	p.item = item
	p.position = pos
	story.world.add_child(p)
	if item is ConsumableData:
		loot.append(p)
	return p


func _add_mob(pos: Vector2, type_id: String, lvl: int) -> Mob:
	var m := Mob.new()
	m.mob_type = MobType.by_id(type_id)
	m.level = lvl
	m.posted = true
	m.home = pos
	m.position = pos
	m.wander_radius = 60.0
	m.leash_range = 260.0
	m.aggro_range = 190.0
	m.world = story.world
	story.world.add_child(m)
	return m


## Arbres du bosquet (en couronne, avec une trouée au sud), palmiers de la
## crique, bosquets épars dans la prairie, et des repères pour s'orienter :
## panneau au carrefour, cairns le long des sentiers, drapeau à la crique,
## arbre mort à l'entrée du bosquet. Rien sur les sentiers ni sur le loot.
## Chaque arbre occupe une case entière de la grille (voir TreeField.plant).
func _place_decor() -> void:
	var world: Node2D = story.world
	var rng := RandomNumberGenerator.new()
	rng.seed = 1028
	var keep := [SLINGSHOT_POS, FIRST_MOB_POS, BeachMap.GROVE_CENTER, BeachMap.CROSSROADS]
	for entry in LOOT + CHESTS + MOBS:
		keep.append(entry[0])
	var attempts := 0
	var planted := 0
	while planted < 52 and attempts < 2000:
		attempts += 1
		var ang := rng.randf() * TAU
		# Trouée au sud du bosquet : le sentier y entre
		if absf(wrapf(ang - PI / 2.0, -PI, PI)) < 0.4:
			continue
		var r := rng.randf_range(0.4, 1.05) * BeachMap.GROVE_RADIUS
		var p := BeachMap.GROVE_CENTER + Vector2(cos(ang), sin(ang) * 0.5) * r
		if _tree_ok(p, keep, 64.0) and TreeField.plant(world, p, rng):
			planted += 1
	# Bosquets épars dans la prairie (petits groupes de 2 à 4 arbres)
	var clumps := 0
	attempts = 0
	while clumps < 14 and attempts < 400:
		attempts += 1
		var c := Vector2(rng.randf_range(BeachMap.LEFT + 150, BeachMap.RIGHT - 150), rng.randf_range(BeachMap.NORTH_TOP + 180, BeachMap.TOP - 60))
		if BeachMap.ground_at(c) != BeachMap.Ground.GRASS or not _tree_ok(c, keep, 120.0):
			continue
		if c.distance_to(story.REFUGE_POS) < 280.0 or BeachMap._iso_dist(c, BeachMap.WRECK2_CENTER) < 280.0:
			continue
		for k in rng.randi_range(2, 4):
			var p := c + Vector2(rng.randf_range(-70, 70), rng.randf_range(-35, 35))
			if _tree_ok(p, keep, 90.0):
				TreeField.plant(world, p, rng)
		clumps += 1
	# Rochers isolés (sans collision)
	for k in 10:
		var p := Vector2(rng.randf_range(BeachMap.LEFT + 120, BeachMap.RIGHT - 120), rng.randf_range(BeachMap.NORTH_TOP + 160, BeachMap.TOP - 40))
		if BeachMap.ground_at(p) == BeachMap.Ground.GRASS and _tree_ok(p, keep, 100.0):
			var rock := Ridge.Rock.new()
			rock.position = p
			rock.size = rng.randf_range(1.0, 1.6)
			rock.seed_value = rng.randi()
			world.add_child(rock)
	# Palmiers autour de la crique
	for k in 14:
		var p := BeachMap.COVE_CENTER + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1) * 0.5) * BeachMap.COVE_RADIUS * 1.2
		if not _clear(p, keep, 60.0) or BeachMap.path_distance(p) < BeachMap.PATH_HALF + 20.0:
			continue
		var palm := Palm.new()
		palm.position = p
		palm.height = rng.randf_range(60, 90)
		palm.lean = rng.randf_range(-0.35, 0.35)
		world.add_child(palm)
	# Repères
	_add_landmark(Landmark.Kind.SIGNPOST, BeachMap.CROSSROADS + Vector2(34, 10),
		[["Bosquet", 0], ["Crique", -1], ["Épave", 1], ["Refuge", 2]])
	_add_landmark(Landmark.Kind.SIGNPOST, Vector2(-40, -960), [["Carrefour", 0], ["Plage", 1]])
	_add_landmark(Landmark.Kind.FLAG, BeachMap.COVE_CENTER + Vector2(110, -40))
	_add_landmark(Landmark.Kind.DEAD_TREE, Vector2(-80, -1890))
	for path in BeachMap.PATHS.slice(0, 4):
		var length := 0.0
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var d := a.distance_to(b)
			var next_cairn := 260.0 - fmod(length, 260.0)
			while next_cairn < d:
				var q := a.lerp(b, next_cairn / d)
				var side := (b - a).normalized().orthogonal() * (BeachMap.PATH_HALF + 16.0)
				_add_landmark(Landmark.Kind.CAIRN, q + side)
				next_cairn += 260.0
			length += d


func _add_landmark(kind: Landmark.Kind, pos: Vector2, labels: Array = []) -> Landmark:
	var l := Landmark.new()
	l.kind = kind
	l.position = pos
	l.labels = labels
	story.world.add_child(l)
	return l


## Un arbre peut pousser là : loin du loot, des monstres et des sentiers.
func _tree_ok(p: Vector2, keep: Array, dist: float) -> bool:
	return _clear(p, keep, dist) and BeachMap.path_distance(p) > BeachMap.PATH_HALF + 40.0


static func _clear(p: Vector2, points: Array, dist: float) -> bool:
	for q in points:
		if p.distance_to(q) < dist:
			return false
	return true


# --- Déroulé ----------------------------------------------------------------

func _process(delta: float) -> void:
	if step == Step.DONE:
		return
	_step_t += delta
	_since_pickup += delta
	_handoff_t += delta
	if _handoff_t > 0.5:
		_handoff_t = 0.0
		_hand_out_weapons()
	_track_bag()
	var c: Survivor = story.controlled
	if not is_instance_valid(c):
		return
	match step:
		Step.INTRO:
			if _step_t > 7.0:
				_advance(Step.FIND_WEAPON)
		Step.FIND_WEAPON:
			if _armed_count() > 0:
				_advance(Step.FIRST_FIGHT)
		Step.FIRST_FIGHT:
			if not is_instance_valid(first_mob) or not first_mob.is_alive():
				_advance(Step.SUPPLIES)
		Step.SUPPLIES:
			story._set_objective(_supplies_text())
			_update_hint()
			if wood_in_stock() >= WOOD_NEEDED and food_brought() >= FOOD_NEEDED:
				_advance(Step.BUILD)
		Step.BUILD:
			if wood_in_stock() < WOOD_NEEDED:
				_advance(Step.SUPPLIES)   # (ne devrait pas arriver : le bois ne se consomme pas)
			elif c.global_position.distance_to(plot_position()) < 70.0:
				story._set_objective("Construire la cabane : E (ou clic sur les piquets) · %d bois" % WOOD_NEEDED)
			else:
				story._set_objective("Assez de bois ! Aller aux piquets, près du feu, pour construire la cabane.")
		Step.BUILDING:
			if is_instance_valid(cabin):
				story._set_objective("La cabane se monte… %d %%" % roundi(cabin.progress * 100.0))


func _advance(next: Step) -> void:
	step = next
	_step_t = 0.0
	story._arrow.target = Vector2.INF
	var c: Survivor = story.controlled
	var o: Survivor = story.other_of(c)
	match next:
		Step.INTRO:
			story._set_objective("Chapitre 1 — L'abri")
			if o:
				o._say("Si on doit rester ici, il nous faut un vrai toit.", 3.0)
				story.get_tree().create_timer(3.0).timeout.connect(func():
					if is_instance_valid(c): c._say("Et de quoi se défendre. Ces bestioles n'ont pas l'air végétariennes.", 3.0))
				story.get_tree().create_timer(6.0).timeout.connect(func():
					if is_instance_valid(o): o._say("J'ai planté des piquets. Ramène du bois, je m'occupe du reste.", 3.2))
		Step.FIND_WEAPON:
			story._set_objective("Trouver de quoi se défendre : explorer au nord du refuge.")
			story._arrow.target = SLINGSHOT_POS
		Step.FIRST_FIGHT:
			var armed := _first_armed()
			if armed:
				armed._say("Un lance-pierre… dans une valise. Quelqu'un partait chasser le pigeon.", 3.2)
			first_mob = _add_mob(FIRST_MOB_POS, "rongeur", 1)
			first_mob.aggro_range = 230.0
			story._set_objective("Viser avec la souris, clic gauche pour tirer. Abattre le rongeur.")
			story._arrow.target = FIRST_MOB_POS
		Step.SUPPLIES:
			_since_pickup = 0.0
			if is_instance_valid(c) and not _fought:
				_fought = true
				c._say("Bon. Ça, je sais faire, apparemment.", 2.5)
		Step.BUILD:
			story._arrow.target = plot_position()
			if is_instance_valid(c):
				c._say("Assez de bois. Au boulot.", 2.2)
		Step.BUILDING:
			story._arrow.target = Vector2.INF
		Step.DONE:
			pass


func _supplies_text() -> String:
	var c: Survivor = story.controlled
	var bag := "%d/%d" % [c.inventory.size(), c.bag_capacity()] if is_instance_valid(c) else "-"
	return "Explorer, ramasser, rapporter au feu. Bois au stock : %d/%d · Nourriture rapportée : %d/%d portions\nUne crique à l'ouest, des débris au nord-est, un bosquet au nord. Sac : %s" % [
		mini(wood_in_stock(), WOOD_NEEDED), WOOD_NEEDED, mini(food_brought(), FOOD_NEEDED), FOOD_NEEDED, bag]


## Rien ramassé depuis un moment : la flèche montre le loot le plus proche,
## ou le feu si le sac est plein.
func _update_hint() -> void:
	var c: Survivor = story.controlled
	if _since_pickup < HINT_DELAY:
		story._arrow.target = Vector2.INF
		return
	if c.inventory.size() >= c.bag_capacity():
		story._arrow.target = story.REFUGE_POS
		return
	var best := Vector2.INF
	var best_d := INF
	for n in loot:
		if not is_instance_valid(n) or (n is LootChest and n.is_broken):
			continue
		var d := c.global_position.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n.global_position
	story._arrow.target = best


## Le sac change (objet ramassé ou déposé) : on relance le délai de l'indice.
func _track_bag() -> void:
	var c: Survivor = story.controlled
	if not is_instance_valid(c):
		return
	var n := c.inventory.size()
	if n != _last_bag:
		if _last_bag >= 0:
			_since_pickup = 0.0
		_last_bag = n


## Une arme rapportée au feu va à un survivant qui n'en a pas (au camp).
func _hand_out_weapons() -> void:
	var stock: VillageStock = story.stock
	for s in story.alive_survivors():
		if s.weapon != null or s.global_position.distance_to(story.REFUGE_POS) > 120.0:
			continue
		for it in stock.distinct_items():
			if it is WeaponData and s.equip_from_stock(it):
				s._say("%s ? Merci. Je me sens tout de suite plus… armé." % it.weapon_name, 3.0)
				break


func wood_in_stock() -> int:
	return story.stock.get_amount("bois")


func food_brought() -> int:
	return story.stock.total_added.get("nourriture", 0) - _food_base


func plot_position() -> Vector2:
	return story.REFUGE_POS + Refuge.CABIN_OFFSET


func _armed_count() -> int:
	var n := 0
	for s in story.alive_survivors():
		if s.weapon != null:
			n += 1
	return n


func _first_armed() -> Survivor:
	for s in story.alive_survivors():
		if s.weapon != null:
			return s
	return null


## Lance le chantier de la cabane (E ou clic sur les piquets).
func try_build() -> bool:
	if step != Step.BUILD or wood_in_stock() < WOOD_NEEDED:
		return false
	var c: Survivor = story.controlled
	if not is_instance_valid(c) or c.global_position.distance_to(plot_position()) > 110.0:
		return false
	story.stock.take("bois", WOOD_NEEDED)
	story.refuge.has_cabin = true
	cabin = Cabin.new()
	cabin.position = plot_position()
	cabin.built.connect(_on_cabin_built)
	story.world.add_child(cabin)
	var o: Survivor = story.other_of(c)
	if o and not o.following:
		o._say("Passe-moi le marteau. Ah, on n'a pas de marteau.", 3.0)
	_advance(Step.BUILDING)
	return true


func _on_cabin_built(_b: Building) -> void:
	step = Step.DONE
	story._set_objective("La cabane est debout.")
	Survivor.shelter = cabin
	var dn: DayNight = story.day_night
	var win := dn.make_light(130.0, Color(1.0, 0.75, 0.4), 1.0)
	win.scale = Vector2(1.0, 0.6)
	win.position = Vector2(30, -10)
	cabin.add_child(win)
	var speaker: Survivor = story.controlled if is_instance_valid(story.controlled) else story.other_of(null)
	if speaker:
		speaker._say("Un toit. Il fuit sûrement, mais c'est NOTRE toit.", 3.5)
	# La nuit tombe sur la première cabane : l'autre survivant va s'y coucher.
	var o: Survivor = story.other_of(story.controlled)
	if o:
		o.following = false
	var delay := 3.5
	if not dn.is_night():
		var target := DayNight.DUSK + 0.4
		dn.speed = 0.0
		var tw := story.create_tween()
		tw.tween_interval(2.5)
		tw.tween_method(dn.set_hour, dn.hour, target, 5.0)
		tw.tween_callback(func(): dn.speed = 1.0)
		delay = 11.0
	story.end_chapter("Fin du chapitre 1", "Un abri, des provisions, de quoi se défendre.\nEt toujours aucun souvenir.\nÀ suivre…", delay)


func handle_input(event: InputEvent) -> bool:
	if step != Step.BUILD:
		return false
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		return try_build()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse: Vector2 = story.get_global_mouse_position()
		if absf(mouse.x - plot_position().x) / 70.0 + absf(mouse.y - plot_position().y) / 40.0 <= 1.0:
			return try_build()
	return false
