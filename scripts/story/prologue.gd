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

const MENU_SCENE := "res://scenes/menu.tscn"

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

# Interface
var _objective: Label
var _status: Label
var _fade: ColorRect
var _overlay: PanelContainer
var _overlay_title: Label
var _overlay_text: Label
var _overlay_buttons: HBoxContainer
var _pause: PanelContainer


func _enter_tree() -> void:
	InputSetup.register()


func _ready() -> void:
	_rng.randomize()
	# Réglages partagés avec le mode test (variables statiques) : on repart propre.
	Terrain.enabled = false   # pas de crête de la carte de test ici
	Nav.clear()
	Mob.harmless = false
	Survivor.alert = false
	Survivor.squad_focus = null
	BuildManager.placing = false

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
	survivor.died.connect(_on_survivor_died)
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

	_build_hud()
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
	return s


func _set_controlled(s: Survivor) -> void:
	if is_instance_valid(controlled):
		controlled.selected = false
	controlled = s
	s.selected = true
	s.following = false
	if _arrow:
		_arrow.follow = s


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
	var r := Rect2(BeachMap.LEFT, BeachMap.TOP, BeachMap.RIGHT - BeachMap.LEFT, BeachMap.BOTTOM - BeachMap.TOP)
	_add_segment(body, r.position, Vector2(r.end.x, r.position.y))
	_add_segment(body, Vector2(r.end.x, r.position.y), r.end)
	_add_segment(body, Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y))


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
	if step == Step.DONE or not is_instance_valid(controlled):
		return
	_t += delta
	_step_t += delta
	camera.position = controlled.global_position
	var p := survivor.global_position if is_instance_valid(survivor) else controlled.global_position
	_update_status()
	_update_follow()
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
			if stock.total_added.get("eau", 0) >= WATER_NEEDED:
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


## L'ami suit le joueur, un pas derrière lui (escouade de deux).
func _update_follow() -> void:
	if not friend.following:
		return
	var v := survivor.velocity
	if v.length() > 5.0:
		_follow_dir = v.normalized()
	friend.follow_point = survivor.global_position - _follow_dir * 34.0
	friend.follow_speed = survivor.move_speed()


## Unités d'eau trouvées : dans le sac du survivant ou déjà déposées au stock.
func water_found() -> int:
	var n := 0
	for it in survivor.inventory:
		if it is ConsumableData and it.resource_type == "eau":
			n += 1
	return n + stock.total_added.get("eau", 0)


## Premier changement de survivant (Tab ou clic droit sur l'autre).
func switch_survivor() -> bool:
	if step != Step.SWITCH:
		return false
	_set_controlled(friend if controlled == survivor else survivor)
	controlled._say("À moi. Ça va mieux, avec de l'eau.", 2.5)
	_finish()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if step != Step.SWITCH:
		return
	if event.is_action_pressed("next_survivor"):
		switch_survivor()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var other := friend if controlled == survivor else survivor
		if other.global_position.distance_to(get_global_mouse_position()) < 26.0:
			switch_survivor()
			get_viewport().set_input_as_handled()


func _finish() -> void:
	step = Step.DONE
	_set_objective("Prologue terminé")
	var tw := create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_fade, "color:a", 0.85, 1.5)
	tw.tween_callback(func(): _show_overlay("Fin du prologue", "Un refuge, un peu d'eau, deux survivants.\nÀ suivre…", true))


func _on_survivor_died(_s: Survivor) -> void:
	step = Step.DONE
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.85, 1.2)
	tw.tween_callback(func(): _show_overlay("Mort définitive", "Sur cette île, on ne revient pas.", true))


func _update_status() -> void:
	var lines: PackedStringArray = []
	for s in [survivor, friend]:
		if not is_instance_valid(s) or (s == friend and step < Step.MEET):
			continue
		var arme: String = s.weapon.weapon_name if s.weapon else "sans arme"
		lines.append("%s%s : PV %d/%d · %s" % ["▶ " if s == controlled else "", s.first_name, s.hp, s.max_hp, arme])
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
	v.add_child(UIStyle.label("PROLOGUE", 12, UIStyle.ACCENT))
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
	b1.pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())
	_overlay_buttons.add_child(b1)
	var b2 := UIStyle.button("Menu titre", 16)
	b2.pressed.connect(func(): get_tree().paused = false; get_tree().change_scene_to_file(MENU_SCENE))
	_overlay_buttons.add_child(b2)
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
	for entry in [["Reprendre", _toggle_pause], ["Recommencer le prologue", func(): get_tree().paused = false; get_tree().reload_current_scene()], ["Menu titre", func(): get_tree().paused = false; get_tree().change_scene_to_file(MENU_SCENE)]]:
		var b := UIStyle.button(entry[0], 16)
		b.custom_minimum_size = Vector2(260, 44)
		b.pressed.connect(entry[1])
		pv.add_child(b)
	_pause.visible = false
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
	_overlay_title.text = title
	_overlay_text.text = text
	_overlay.visible = true


func _toggle_pause() -> void:
	if _overlay.visible:
		return
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
