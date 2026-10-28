extends Node2D
## Mode histoire — Prologue « La plage ».
##
## 1. Un survivant, sans arme, se réveille sur la plage parmi les débris d'un
##    accident dont il ne se souvient pas. Pas de monstre sur la plage.
## 2. Une butte rocheuse infranchissable longe la plage : on la suit vers
##    l'est. Au bout, on rencontre un second survivant qui nous suit (escouade,
##    pas encore de changement de personnage).
## 3. Plus loin, des monstres à éviter (on n'a pas d'arme) : une embuscade
##    blesse notre ami.
## 4. Plus loin, un refuge avec un feu de camp : l'ami blessé y reste (il a
##    soif), on part seul chercher de l'eau.
## 5. On trouve deux unités d'eau (bouteilles) en explorant : pas de source,
##    on loote ce qu'on trouve. On les rapporte au feu : elles vont au stock,
##    l'ami vient boire.
## 6. Premier changement de survivant (Tab ou clic droit sur l'ami) : fin du
##    prologue.
##
## Le chapitre 1 (« L'abri », voir Chapter1) enchaîne sur la même carte,
## agrandie vers le nord. Le menu titre peut aussi y mener directement.

const MENU_SCENE := "res://scenes/menu.tscn"

## Chapitre où commence la scène : 0 = prologue, 1 = chapitre 1 (réglé par le
## menu titre et par « Recommencer »).
static var start_chapter := 0

enum Step { WAKE, MOVE, FOLLOW_BUTTE, MEET, TO_REFUGE, REFUGE, FIND_WATER, BRING_WATER, FRIEND_DRINKS, SWITCH, DONE }

const LINES_WAKE := [
	[1.2, "… Aïe. Ma tête."],
	[3.6, "Où suis-je ?"],
	[6.0, "Et… qui suis-je, au juste ?"],
]

## Lieux (au nord de la butte, après son extrémité).
const FRIEND_POS := Vector2(920, -250)
const REFUGE_POS := Vector2(-150, -860)
## Deux bouteilles d'eau à trouver, à l'ouest du refuge (près de débris).
const WATER_POS := [Vector2(-860, -760), Vector2(-1170, -560)]
const WATER_NEEDED := 2
## Monstres à éviter entre l'ami et le refuge.
const DANGER_MOBS := [Vector2(600, -470), Vector2(330, -580), Vector2(460, -790), Vector2(110, -500)]
const DANGER_LINE_Y := -360.0   # en passant cette ligne vers le nord : embuscade

var step: Step = Step.WAKE
var world: Node2D
var survivor: Survivor        # le premier survivant (le joueur au départ)
var friend: Survivor          # le second, rencontré au bout de la butte
var controlled: Survivor      # celui que le joueur dirige
var camera: Camera2D
var refuge: Refuge
var water_items: Array[ItemPickup] = []
var stock: VillageStock
var danger: Array[Mob] = []
var ambusher: Mob

var _t := 0.0
var _step_t := 0.0
var _wake_line := 0
var _start_pos := Vector2.ZERO
var _seen_wreck := false
var _ambushed := false
var _ambush_bitten := false
var _rng := RandomNumberGenerator.new()
var _follow_dir := Vector2.LEFT
var _arrow: ObjectiveArrow
var chapter: Chapter1          # chapitre en cours après le prologue (sinon null)
var day_night: DayNight
var _lamp: PointLight2D        # petite lumière autour du survivant dirigé, la nuit
var _dial: DayDial
var _top_bar: TopBar
var dev_panel: StoryDevPanel
var _card: SurvivorCard
## Accélération du temps quand aucun survivant n'est dirigé (jusqu'à l'aube).
const FAST_TIME := 8.0
const FREE_CAM_SPEED := 420.0
var _continue_btn: Button
var _north_bound: CollisionShape2D
var _title: Label

# Interface
var _objective: Label
var _status: Label
var _fade: ColorRect
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_text: Label
var _overlay_buttons: HBoxContainer
var _pause: PanelContainer
var _chapter_label: Label
var _restart_btn: Button


func _enter_tree() -> void:
	InputSetup.register()


func _ready() -> void:
	_rng.randomize()
	# Réglages partagés avec le mode test (variables statiques) : on repart propre.
	Terrain.enabled = false   # pas de crête de la carte de test ici
	Nav.clear()
	Nav.set_region_world(Rect2(BeachMap.LEFT, BeachMap.NORTH_TOP, BeachMap.RIGHT - BeachMap.LEFT, BeachMap.BOTTOM - BeachMap.NORTH_TOP))
	Mob.harmless = false
	Survivor.alert = false
	Survivor.squad_focus = null
	BuildManager.placing = false
	Survivor.shelter = null

	# Cycle jour/nuit : le prologue commence le matin.
	day_night = DayNight.new()
	day_night.name = "JourNuit"
	day_night.hour = 8.0 if start_chapter == 0 else 9.0
	add_child(day_night)
	day_night.night_started.connect(_on_night)
	day_night.day_started.connect(_on_day)

	add_child(StoryGround.new())
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	stock = VillageStock.new()
	stock.name = "Stock"
	add_child(stock)

	_build_butte()
	_build_bounds()
	_place_decor()
	_place_places()

	survivor = _make_survivor(BeachMap.START)
	_start_pos = survivor.global_position
	_set_controlled(survivor)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.6, 1.6)
	camera.position = survivor.global_position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = int(BeachMap.LEFT - 100)
	camera.limit_right = int(BeachMap.RIGHT + 100)
	camera.limit_top = int(BeachMap.TOP - 100)
	camera.limit_bottom = int(BeachMap.BOTTOM + 60)
	add_child(camera)
	camera.make_current()

	_arrow = ObjectiveArrow.new()
	_arrow.follow = controlled
	world.add_child(_arrow)

	# Lumières de nuit : le feu du refuge et une lueur autour du survivant dirigé
	var fire_light := day_night.make_light(300.0, Color(1.0, 0.62, 0.3), 0.8)
	fire_light.scale = Vector2(1.0, 0.6)
	fire_light.position = Vector2(0, -6)
	refuge.add_child(fire_light)
	refuge.light = fire_light
	_lamp = day_night.make_light(190.0, Color(0.85, 0.85, 1.0), 0.75)
	_lamp.scale = Vector2(1.0, 0.65)
	add_child(_lamp)

	_build_hud()
	survivor.died.connect(_on_any_died)
	friend.died.connect(_on_any_died)
	if start_chapter == 1:
		_skip_prologue()
		return
	_set_objective("…")
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_fade, "color:a", 0.0, 2.5)


func _make_survivor(pos: Vector2) -> Survivor:
	var s := Survivor.new()
	s.world = world
	s.stock = stock
	s.unarmed_start = true         # sans arme au début
	s.needs_enabled = false        # prologue : pas encore de faim ni de soif
	s.camp_regen = false           # pas encore de camp
	s.village_center = Vector2(-99999, -99999)
	s.position = pos
	world.add_child(s)
	# Jauges pleines : sinon le premier survivant pourrait boire au feu l'eau
	# rapportée pour l'ami.
	s.thirst = Survivor.NEED_MAX
	s.hunger = Survivor.NEED_MAX
	return s


func _set_controlled(s: Survivor) -> void:
	if is_instance_valid(controlled):
		controlled.selected = false
	var was_free := not is_instance_valid(controlled)
	controlled = s
	if _arrow:
		_arrow.follow = s
	if _card:
		_card.survivor = s
	if s == null:
		return
	s.selected = true
	s.following = false
	if was_free and day_night and day_night.speed > 1.0:
		day_night.speed = 1.0   # on reprend la main : le temps reprend son cours


## Chapitre 1 : Espace — on lâche le survivant dirigé (il redevient libre et
## suit la vie du camp). Sans survivant dirigé, le temps file jusqu'à l'aube.
func release_control() -> bool:
	if chapter == null or not is_instance_valid(controlled):
		return false
	var s := controlled
	var f := other_of(s)
	if f and f.following:
		f.following = false
	_set_controlled(null)
	s._pick_wander_target()
	day_night.speed = FAST_TIME
	return true


# --- Décor et monde ---------------------------------------------------------

## Butte rocheuse : rochers serrés sur deux rangs + collision continue.
func _build_butte() -> void:
	var body := StaticBody2D.new()
	body.name = "Butte"
	body.collision_layer = 4   # obstacles : bloque survivants, monstres et tirs
	body.collision_mask = 0
	add_child(body)
	var x := BeachMap.BUTTE_START
	var prev := Vector2(x, BeachMap.butte_y(x))
	while x < BeachMap.BUTTE_END:
		x = minf(x + 40.0, BeachMap.BUTTE_END)
		var p := Vector2(x, BeachMap.butte_y(x))
		_add_segment(body, prev + Vector2(0, -6), p + Vector2(0, -6))
		prev = p
	# Bout arrondi de la butte (on le contourne par l'est)
	var tip := Vector2(BeachMap.BUTTE_END, BeachMap.butte_y(BeachMap.BUTTE_END))
	_add_segment(body, tip + Vector2(0, -6), tip + Vector2(10, -40))
	_add_segment(body, tip + Vector2(10, -40), tip + Vector2(-20, -90))
	# Rochers visibles
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	x = BeachMap.BUTTE_START
	while x <= BeachMap.BUTTE_END:
		var y := BeachMap.butte_y(x)
		for row in 3:
			var rock := Ridge.Rock.new()
			rock.position = Vector2(x + rng.randf_range(-6, 6), y - 10.0 - row * 22.0 + rng.randf_range(-4, 4))
			rock.size = rng.randf_range(1.3, 1.9) - row * 0.15
			rock.seed_value = rng.randi()
			world.add_child(rock)
		x += 22.0
	# Pointe : quelques rochers qui remontent vers le nord
	for k in 4:
		var rock := Ridge.Rock.new()
		rock.position = tip + Vector2(rng.randf_range(-8, 8), -30.0 - k * 22.0)
		rock.size = rng.randf_range(1.0, 1.5)
		rock.seed_value = rng.randi()
		world.add_child(rock)


## Limites : la mer au sud, une falaise à l'ouest, les bords de la carte.
func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.name = "Limites"
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	# Ligne d'eau : on peut marcher dans l'écume, pas nager.
	var x := BeachMap.LEFT - 100.0
	var prev := Vector2(x, BeachMap.shore_y(x) + 22.0)
	while x < BeachMap.RIGHT + 100.0:
		x += 40.0
		var p := Vector2(x, BeachMap.shore_y(x) + 22.0)
		_add_segment(body, prev, p)
		prev = p
	# Falaise ouest, de la butte jusqu'à la mer
	var w := BeachMap.BUTTE_START
	_add_segment(body, Vector2(w, BeachMap.butte_y(w) - 6), Vector2(w - 20, BeachMap.shore_y(w) + 40))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var y := BeachMap.butte_y(w)
	while y < BeachMap.shore_y(w) + 20:
		var rock := Ridge.Rock.new()
		rock.position = Vector2(w - 14 + rng.randf_range(-6, 6), y)
		rock.size = rng.randf_range(1.3, 1.8)
		rock.seed_value = rng.randi()
		world.add_child(rock)
		y += 18.0
	# Bords de la carte
	# Les bords est et ouest vont jusqu'au nord du chapitre 1 ; le bord nord du
	# prologue (TOP) s'ouvre au chapitre 1 (open_north).
	var r := Rect2(BeachMap.LEFT, BeachMap.NORTH_TOP, BeachMap.RIGHT - BeachMap.LEFT, BeachMap.BOTTOM - BeachMap.NORTH_TOP)
	_add_segment(body, r.position, Vector2(r.end.x, r.position.y))
	_add_segment(body, Vector2(r.end.x, r.position.y), r.end)
	_add_segment(body, Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y))
	_add_segment(body, Vector2(BeachMap.LEFT, BeachMap.TOP), Vector2(BeachMap.RIGHT, BeachMap.TOP))
	_north_bound = body.get_child(body.get_child_count() - 1)


## Chapitre 1 : le nord de l'île s'ouvre (bord du prologue retiré, caméra libérée).
func open_north() -> void:
	if is_instance_valid(_north_bound):
		_north_bound.queue_free()
	camera.limit_top = int(BeachMap.NORTH_TOP - 100)


func _add_segment(body: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var shape := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	shape.shape = seg
	body.add_child(shape)


func _place_decor() -> void:
	# Débris de l'accident autour du point de réveil
	var pieces := [
		[Wreck.Kind.HULL, Vector2(-1000, 20)],
		[Wreck.Kind.SEAT, Vector2(-1210, 125)],
		[Wreck.Kind.SUITCASE, Vector2(-1080, 140)],
		[Wreck.Kind.PANEL, Vector2(-930, 115)],
		[Wreck.Kind.PANEL, Vector2(-760, 40)],
		[Wreck.Kind.SEAT, Vector2(-620, 85)],
	]
	for p in pieces:
		var w := Wreck.new()
		w.kind = p[0]
		w.position = p[1]
		world.add_child(w)
	# Palmiers : derrière la butte (on les voit dépasser) et au-delà de son extrémité
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for k in 26:
		var x := rng.randf_range(BeachMap.LEFT + 100, BeachMap.RIGHT - 100)
		var y := BeachMap.butte_y(clampf(x, BeachMap.BUTTE_START, BeachMap.BUTTE_END)) - rng.randf_range(90, 420)
		var palm := Palm.new()
		palm.position = Vector2(x, y)
		palm.height = rng.randf_range(60, 90)
		palm.lean = rng.randf_range(-0.3, 0.35)
		world.add_child(palm)
	for x in [-400.0, 380.0]:
		var palm := Palm.new()
		palm.position = Vector2(x, BeachMap.butte_y(x) + 28.0)
		palm.height = 75.0
		palm.lean = 0.3
		world.add_child(palm)


func _place_places() -> void:
	# Second survivant, assis au bout de la butte près d'un débris
	friend = _make_survivor(FRIEND_POS)
	friend.hp_floor = 12           # l'ami ne peut pas mourir pendant le prologue
	friend.village_center = FRIEND_POS   # il attend là, assis près du débris
	friend.wander_radius = 30.0
	friend._pick_wander_target()
	var seat := Wreck.new()
	seat.kind = Wreck.Kind.SEAT
	seat.position = FRIEND_POS + Vector2(-34, 16)
	world.add_child(seat)
	# Monstres à éviter, entre l'ami et le refuge
	for p in DANGER_MOBS:
		var m := Mob.new()
		m.mob_type = MobType.by_id("rongeur")
		m.level = 1
		m.posted = true
		m.home = p
		m.position = p
		m.wander_radius = 70.0
		m.leash_range = 240.0
		m.aggro_range = 170.0
		m.world = world
		world.add_child(m)
		danger.append(m)
	# Refuge (futur camp) et mare plus à l'ouest
	refuge = Refuge.new()
	refuge.position = REFUGE_POS
	world.add_child(refuge)
	var kinds := [Wreck.Kind.SUITCASE, Wreck.Kind.PANEL]
	for i in WATER_POS.size():
		var w := ItemPickup.new()
		w.item = load("res://data/items/eau.tres")
		w.position = WATER_POS[i]
		world.add_child(w)
		water_items.append(w)
		var debris := Wreck.new()
		debris.kind = kinds[i]
		debris.position = WATER_POS[i] + Vector2(-30, -14)
		world.add_child(debris)


# --- Déroulé ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(controlled):
		# Personne n'est dirigé : caméra libre (ZQSD / flèches).
		controlled = null
		_lamp.visible = false
		var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		camera.position += dir * FREE_CAM_SPEED * delta
		camera.position.x = clampf(camera.position.x, camera.limit_left, camera.limit_right)
		camera.position.y = clampf(camera.position.y, camera.limit_top, camera.limit_bottom)
		_update_status()
		return
	camera.position = controlled.global_position
	_lamp.visible = true
	_lamp.global_position = controlled.global_position + Vector2(0, -8)
	_update_status()
	_update_follow()
	if step == Step.DONE:
		return
	_t += delta
	_step_t += delta
	var p := survivor.global_position if is_instance_valid(survivor) else controlled.global_position
	# Monologue du réveil
	if _wake_line < LINES_WAKE.size() and _t >= LINES_WAKE[_wake_line][0]:
		survivor._say(LINES_WAKE[_wake_line][1], 2.3)
		_wake_line += 1
	if not _seen_wreck and _t > 8.0 and p.distance_to(Vector2(-1000, 20)) < 160.0:
		_seen_wreck = true
		survivor._say("Des débris… de quoi, au juste ? Je ne me souviens de rien.", 3.5)
	match step:
		Step.WAKE:
			if _t > 6.5:
				_advance(Step.MOVE)
		Step.MOVE:
			if p.distance_to(_start_pos) > 60.0:
				_advance(Step.FOLLOW_BUTTE)
		Step.FOLLOW_BUTTE:
			if p.distance_to(friend.global_position) < 170.0:
				_advance(Step.MEET)
		Step.MEET:
			# Petite discussion, puis l'ami se joint à nous.
			if _step_t > 7.5:
				_advance(Step.TO_REFUGE)
		Step.TO_REFUGE:
			if not _ambushed and p.y < DANGER_LINE_Y:
				_ambush()
			_update_ambush()
			if p.distance_to(REFUGE_POS) < 140.0:
				_advance(Step.REFUGE)
		Step.REFUGE:
			if _step_t > 4.0:
				_advance(Step.FIND_WATER)
		Step.FIND_WATER:
			var n := water_found()
			_set_objective("Trouver de l'eau, seul : à l'ouest du refuge. Eau trouvée : %d/%d" % [n, WATER_NEEDED])
			if n >= WATER_NEEDED:
				_advance(Step.BRING_WATER)
		Step.BRING_WATER:
			if water_in_bag() == 0 and stock.total_added.get("eau", 0) > 0:
				_advance(Step.FRIEND_DRINKS)
		Step.FRIEND_DRINKS:
			if friend.thirst >= Survivor.NEED_LOW or _step_t > 8.0:
				_advance(Step.SWITCH)


func _advance(next: Step) -> void:
	step = next
	_step_t = 0.0
	_arrow.target = Vector2.INF
	match next:
		Step.MOVE:
			_set_objective("Se déplacer : ZQSD (ou flèches)")
		Step.FOLLOW_BUTTE:
			_set_objective("Impossible de franchir la butte. La longer vers l'est.")
			_arrow.target = FRIEND_POS
		Step.MEET:
			_set_objective("Quelqu'un ! Un autre survivant.")
			friend._say("Hé ! Toi aussi, tu étais… dans ce truc ?", 2.6)
			get_tree().create_timer(2.6).timeout.connect(func(): survivor._say("Aucune idée. Je ne me souviens de rien.", 2.4))
			get_tree().create_timer(5.0).timeout.connect(func(): friend._say("Moi non plus. On reste ensemble ?", 2.4))
		Step.TO_REFUGE:
			friend.following = true
			_set_objective("%s vous suit. Trouver un abri au nord-ouest. Sans arme : évitez les monstres !" % friend.first_name)
			_arrow.target = REFUGE_POS
		Step.REFUGE:
			refuge.lit = true
			friend.following = false
			for s in [survivor, friend]:
				s.village_center = REFUGE_POS
				s.camp_regen = true
			friend.wander_radius = 50.0
			friend._pick_wander_target()
			_set_objective("Un refuge, avec un vieux feu de camp.")
			friend.thirst = 25.0   # assoiffé : il le dira, et ira boire dès qu'il y aura de l'eau
			friend._bubble_cooldown = 6.0
			friend._say("Je ne vais pas plus loin… Ma jambe. Trouve de l'eau, il nous en faut.", 3.8)
		Step.FIND_WATER:
			_set_objective("Trouver de l'eau, seul : à l'ouest du refuge. Eau trouvée : 0/%d" % WATER_NEEDED)
		Step.BRING_WATER:
			survivor._say("Deux bouteilles. C'est un début.", 2.5)
			_set_objective("Rapporter l'eau au feu de camp du refuge (passer près du feu)")
			_arrow.target = REFUGE_POS
		Step.FRIEND_DRINKS:
			_set_objective("L'eau est au stock du refuge. %s va boire." % friend.first_name)
		Step.SWITCH:
			_set_objective("Prendre le relais : Tab (ou clic droit sur %s) pour le diriger." % friend.first_name)


## Embuscade : un monstre surgit et mord l'ami.
func _ambush() -> void:
	_ambushed = true
	ambusher = Mob.new()
	ambusher.mob_type = MobType.by_id("rongeur")
	ambusher.level = 1
	ambusher.world = world
	var side := Vector2(1, 0) if friend.global_position.x < 800 else Vector2(-1, 0)
	ambusher.position = friend.global_position + side * 16.0
	ambusher.village_center = ambusher.position
	ambusher.preferred_target = friend
	world.add_child(ambusher)
	ambusher.damage = 30.0   # une vraie morsure
	survivor._say("Attention !", 1.5)


func _update_ambush() -> void:
	if not _ambushed or _ambush_bitten or not is_instance_valid(ambusher):
		return
	if friend.hp < friend.max_hp:
		_ambush_bitten = true
		friend._say("Aaah ! Ma jambe !", 2.5)
		# Le monstre retourne à son coin : on peut l'éviter.
		ambusher.preferred_target = null
		ambusher.posted = true
		ambusher.home = ambusher.global_position
		ambusher.leash_range = 200.0
		ambusher.aggro_range = 150.0
		ambusher.damage = 8.0
		danger.append(ambusher)
		_set_objective("%s est blessé ! Filez au refuge, au nord-ouest." % friend.first_name)


## L'autre survivant suit celui qu'on dirige, un pas derrière lui (escouade de deux).
func _update_follow() -> void:
	var leader := controlled
	if leader == null:
		return
	var f := other_of(leader)
	if f == null or not f.following:
		return
	var v := leader.velocity
	if v.length() > 5.0:
		_follow_dir = v.normalized()
	f.follow_point = leader.global_position - _follow_dir * 34.0
	f.follow_speed = leader.move_speed()


## Survivants encore en vie.
func alive_survivors() -> Array[Survivor]:
	var out: Array[Survivor] = []
	for s in [survivor, friend]:
		if is_instance_valid(s) and s.is_alive():
			out.append(s)
	return out


## L'autre survivant vivant (null s'il n'y en a pas).
func other_of(s: Survivor) -> Survivor:
	for o in alive_survivors():
		if o != s:
			return o
	return null


## Bouteilles d'eau trouvées (ramassées), qu'elles soient encore dans le sac
## ou déjà déposées au stock.
func water_found() -> int:
	var n := 0
	for w in water_items:
		if not is_instance_valid(w) or w.is_queued_for_deletion():
			n += 1
	return n


## Bouteilles encore dans le sac du premier survivant.
func water_in_bag() -> int:
	var n := 0
	for it in survivor.inventory:
		if it is ConsumableData and it.resource_type == "eau":
			n += 1
	return n


## Changement de survivant (Tab ou clic droit sur l'autre). Le premier
## termine le prologue ; au chapitre 1, on change quand on veut.
func switch_survivor() -> bool:
	if chapter == null and step != Step.SWITCH:
		return false
	var other := other_of(controlled)
	if other == null:
		return false
	var had_leader := controlled != null
	var was_following := other.following
	_set_controlled(other)
	if chapter == null:
		controlled._say("À moi. Ça va mieux, avec de l'eau.", 2.5)
		_finish()
	else:
		# L'escouade garde sa forme : si l'autre suivait, c'est l'ancien qui suit.
		var prev := other_of(controlled)
		if prev and had_leader:
			prev.following = was_following
	return true


## Chapitre 1 : F — l'autre survivant nous suit, ou retourne attendre au refuge.
func toggle_follow() -> bool:
	if chapter == null:
		return false
	var o := other_of(controlled)
	if o == null:
		return false
	o.following = not o.following
	if o.following:
		o._say("Je te suis.", 1.8)
	else:
		o._say("Je rentre au refuge.", 1.8)
		o._pick_wander_target()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		dev_panel.toggle()
		get_viewport().set_input_as_handled()
		return
	if chapter != null:
		if chapter.handle_input(event):
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("toggle_squad"):
			toggle_follow()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_SPACE:
			release_control()
			get_viewport().set_input_as_handled()
			return
	if chapter == null and step != Step.SWITCH:
		return
	if event.is_action_pressed("next_survivor"):
		switch_survivor()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		for o in alive_survivors():
			if o != controlled and o.global_position.distance_to(get_global_mouse_position()) < 26.0:
				select_survivor(o)
				get_viewport().set_input_as_handled()
				return


## Prend en main un survivant précis (clic droit).
func select_survivor(s: Survivor) -> bool:
	if chapter == null:
		return switch_survivor()
	if s == controlled or not is_instance_valid(s):
		return false
	var prev := controlled
	var was_following := s.following
	_set_controlled(s)
	if prev:
		prev.following = was_following
	return true


## Fin du prologue : carton de titre, puis le chapitre 1 enchaîne.
func _finish() -> void:
	step = Step.DONE
	_set_objective("Prologue terminé")
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(_fade, "color:a", 1.0, 1.2)
	tw.tween_callback(_start_chapter1)
	tw.tween_callback(func(): _show_title("Chapitre 1", "L'abri"))
	tw.tween_interval(2.4)
	tw.tween_property(_fade, "color:a", 0.0, 1.5)


func _start_chapter1() -> void:
	if chapter != null:
		return
	chapter = Chapter1.new()
	chapter.name = "Chapitre1"
	chapter.story = self
	add_child(chapter)
	_chapter_label.text = "CHAPITRE 1 — L'ABRI"
	chapter.start()


## Départ direct au chapitre 1 (menu titre, « Recommencer ») : on reprend la
## situation de fin du prologue — refuge allumé, les deux survivants au feu,
## sans arme, et l'on dirige le second.
func _skip_prologue() -> void:
	step = Step.DONE
	_wake_line = LINES_WAKE.size()
	_seen_wreck = true
	for w in water_items:
		if is_instance_valid(w):
			w.queue_free()
	refuge.lit = true
	for s in [survivor, friend]:
		s.village_center = REFUGE_POS
		s.camp_regen = true
		s.following = false
	survivor.global_position = REFUGE_POS + Vector2(40, 30)
	friend.global_position = REFUGE_POS + Vector2(-30, 40)
	friend.wander_radius = 50.0
	friend.hp = friend.max_hp
	survivor.wander_radius = 50.0
	survivor._pick_wander_target()
	_set_controlled(friend)
	camera.position = friend.global_position
	camera.reset_smoothing()
	_start_chapter1()
	_show_title("Chapitre 1", "L'abri")
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_fade, "color:a", 0.0, 1.5)


## Fin d'un chapitre : écran de fin (Recommencer / Menu titre).
func end_chapter(title: String, text: String, delay := 3.5) -> void:
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(_fade, "color:a", 0.85, 1.5)
	tw.tween_callback(func(): _show_overlay(title, text, true))


## « Continuer » après la fin d'un chapitre : on reste sur l'île, en libre.
func _continue_free_play() -> void:
	_overlay.visible = false
	create_tween().tween_property(_fade, "color:a", 0.0, 1.0)
	_set_objective("Exploration libre. La suite au chapitre 2.")


# --- Nuit -------------------------------------------------------------------

func _on_night() -> void:
	if step != Step.DONE and chapter == null:
		return   # (le prologue se joue de jour)
	var o := other_of(controlled)
	if o == null or o.following:
		return
	if Survivor._shelter_ready():
		o._say("La nuit tombe. Je rentre à l'abri.", 2.8)
	else:
		o._say("Il fait nuit… Je reste près du feu.", 2.8)


func _on_day() -> void:
	if day_night.speed > 1.0:
		day_night.speed = 1.0   # l'aube arrête l'accélération
	var o := other_of(controlled)
	if o:
		o._say("Encore une journée. Personne n'est venu nous chercher.", 3.2)


## Mort définitive. Au chapitre 1, si l'autre survivant vit encore, on le
## reprend en main ; sinon c'est la fin.
func _on_any_died(s: Survivor) -> void:
	var grave := Grave.new()
	grave.dead_name = s.full_name()
	grave.position = s.global_position
	world.add_child.call_deferred(grave)
	var left := alive_survivors()
	left.erase(s)
	if chapter != null and not left.is_empty():
		var o: Survivor = left[0]
		o.following = false
		if s == controlled:
			_set_controlled(o)
		o._say("%s… Non.\nSur cette île, on ne revient pas." % s.first_name, 3.5)
		return
	step = Step.DONE
	if chapter != null:
		chapter.step = Chapter1.Step.DONE
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.85, 1.2)
	tw.tween_callback(func(): _show_overlay("Mort définitive", "Sur cette île, on ne revient pas.", true))


## Recommence là où l'on en est : le prologue, ou le chapitre en cours.
func _restart() -> void:
	start_chapter = 1 if chapter != null else 0
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	start_chapter = 0
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _update_status() -> void:
	var lines: PackedStringArray = []
	for s in [survivor, friend]:
		if not is_instance_valid(s) or (s == friend and step < Step.MEET and chapter == null):
			continue
		var arme: String = s.weapon.weapon_name if s.weapon else "sans arme"
		var line := "%s%s : PV %d/%d · %s" % ["▶ " if s == controlled else "", s.first_name, s.hp, s.max_hp, arme]
		if chapter != null:
			line += " · soif %d %% · faim %d %%" % [roundi(s.thirst), roundi(s.hunger)]
			if s.following:
				line += " · suit"
		lines.append(line)
	if chapter != null:
		lines.append("Tab : changer de survivant · F : l'autre vous suit / attend · Espace : lâcher")
	_status.text = "\n".join(lines)


# --- Interface --------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2, 12))
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(380, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panel.add_child(v)
	_chapter_label = UIStyle.label("PROLOGUE", 12, UIStyle.ACCENT)
	v.add_child(_chapter_label)
	_objective = UIStyle.label("", 16)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.custom_minimum_size = Vector2(356, 0)
	v.add_child(_objective)
	_status = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	v.add_child(_status)
	var menu_btn := UIStyle.button("Menu  [Échap]", 13)
	menu_btn.anchor_left = 1.0
	menu_btn.anchor_right = 1.0
	menu_btn.offset_left = -150
	menu_btn.offset_right = -12
	menu_btn.offset_top = 12
	menu_btn.pressed.connect(_toggle_pause)
	layer.add_child(menu_btn)
	# Panneau développeur (F1)
	dev_panel = StoryDevPanel.new()
	dev_panel.story = self
	layer.add_child(dev_panel)
	var dev_btn := UIStyle.button("Dev  [F1]", 13)
	dev_btn.anchor_left = 1.0
	dev_btn.anchor_right = 1.0
	dev_btn.offset_left = -250
	dev_btn.offset_right = -158
	dev_btn.offset_top = 12
	dev_btn.pressed.connect(func(): dev_panel.toggle())
	layer.add_child(dev_btn)
	# Cadran du temps (en haut, au centre) et vignette du survivant dirigé
	# (en bas à gauche)
	_top_bar = TopBar.new()
	layer.add_child(_top_bar)
	_top_bar.setup(day_night, stock)
	_dial = _top_bar.dial
	_card = SurvivorCard.new()
	_card.survivor = controlled
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = 12
	_card.offset_bottom = -12
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(_card)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 1)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	_overlay = _make_center_panel(layer)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 12)
	_overlay.add_child(ov)
	_overlay_title = UIStyle.label("", 30, UIStyle.ACCENT)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_overlay_title)
	_overlay_text = UIStyle.label("", 16)
	_overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(_overlay_text)
	_overlay_buttons = HBoxContainer.new()
	_overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_buttons.add_theme_constant_override("separation", 12)
	ov.add_child(_overlay_buttons)
	var b1 := UIStyle.button("Recommencer", 16)
	b1.pressed.connect(_restart)
	_overlay_buttons.add_child(b1)
	var b2 := UIStyle.button("Menu titre", 16)
	b2.pressed.connect(_to_menu)
	_overlay_buttons.add_child(b2)
	_continue_btn = UIStyle.button("Continuer", 16)
	_continue_btn.pressed.connect(_continue_free_play)
	_overlay_buttons.add_child(_continue_btn)
	_overlay.visible = false
	# Pause (Échap)
	_pause = _make_center_panel(layer)
	_pause.process_mode = Node.PROCESS_MODE_ALWAYS
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	_pause.add_child(pv)
	var pt := UIStyle.label("Pause", 26, UIStyle.ACCENT)
	pt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(pt)
	for entry in [["Reprendre", _toggle_pause], ["Recommencer le prologue", _restart], ["Menu titre", _to_menu]]:
		var b := UIStyle.button(entry[0], 16)
		b.custom_minimum_size = Vector2(260, 44)
		b.pressed.connect(entry[1])
		pv.add_child(b)
		if entry[0].begins_with("Recommencer"):
			_restart_btn = b
	_pause.visible = false
	# Carton de titre (début de chapitre), par-dessus le fondu
	_title = UIStyle.label("", 34, UIStyle.ACCENT)
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.modulate.a = 0.0
	layer.add_child(_title)
	var key := PauseKey.new()
	key.on_toggle = _toggle_pause
	add_child(key)


func _make_center_panel(layer: CanvasLayer) -> PanelContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.ACCENT, 12, 2, 22))
	center.add_child(p)
	return p


func _set_objective(text: String) -> void:
	if _objective.text == text:
		return
	_objective.text = text
	_objective.modulate = Color(1.6, 1.4, 0.9)
	create_tween().tween_property(_objective, "modulate", Color.WHITE, 0.8)


func _show_overlay(title: String, text: String, _buttons: bool) -> void:
	# « Continuer » seulement à la fin d'un chapitre (pas après une mort)
	_continue_btn.visible = alive_survivors().size() > 0 and title.begins_with("Fin")
	_overlay_title.text = title
	_overlay_text.text = text
	_overlay.visible = true


## Carton « Chapitre 1 — L'abri » : apparaît, reste un moment, s'efface.
func _show_title(head: String, sub: String) -> void:
	_title.text = "%s\n%s" % [head.to_upper(), sub]
	var tw := create_tween()
	tw.tween_property(_title, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.6)
	tw.tween_property(_title, "modulate:a", 0.0, 0.8)


func _toggle_pause() -> void:
	if _overlay.visible:
		return
	_restart_btn.text = "Recommencer le chapitre" if chapter != null else "Recommencer le prologue"
	_pause.visible = not _pause.visible
	get_tree().paused = _pause.visible



## Échap ouvre / ferme la pause ; ce nœud tourne même jeu en pause.
class PauseKey:
	extends Node
	var on_toggle: Callable

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed("deselect"):
			on_toggle.call()
			get_viewport().set_input_as_handled()
