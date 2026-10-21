extends Node2D
## Mode histoire — Prologue « La plage ».
## Un seul survivant se réveille sur la plage, au milieu des débris d'un
## accident dont il ne se souvient pas. Une butte rocheuse infranchissable
## longe la plage : on la suit vers l'est, en apprenant les bases (se
## déplacer, viser et tirer, casser un coffre, ramasser une arme, combattre),
## jusqu'à son extrémité où l'on peut enfin passer de l'autre côté.

const MENU_SCENE := "res://scenes/menu.tscn"

enum Step { WAKE, MOVE, FOLLOW, CHEST, PICKUP, FIRST_MOB, DUO, ROUND_BUTTE, DONE }

const LINES_WAKE := [
	[1.2, "… Aïe. Ma tête."],
	[3.6, "Où suis-je ?"],
	[6.0, "Et… qui suis-je, au juste ?"],
]

var step: Step = Step.WAKE
var world: Node2D
var survivor: Survivor
var camera: Camera2D
var chest: LootChest
var first_mob: Mob
var duo: Array[Mob] = []

var _t := 0.0
var _wake_line := 0
var _start_pos := Vector2.ZERO
var _seen_wreck := false
var _rng := RandomNumberGenerator.new()

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

	_build_butte()
	_build_bounds()
	_place_decor()
	_place_encounters()

	survivor = Survivor.new()
	survivor.world = world
	survivor.needs_enabled = false   # prologue : pas encore de faim ni de soif
	survivor.camp_regen = false      # pas de camp
	survivor.village_center = Vector2(-99999, -99999)
	survivor.position = BeachMap.START
	survivor.died.connect(_on_survivor_died)
	world.add_child(survivor)
	survivor.selected = true
	_start_pos = survivor.global_position

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

	_build_hud()
	_set_objective("…")
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(_fade, "color:a", 0.0, 2.5)


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
	for x in [-400.0, 650.0, 1450.0]:
		var palm := Palm.new()
		palm.position = Vector2(x, BeachMap.butte_y(x) + 28.0)
		palm.height = 75.0
		palm.lean = 0.3
		world.add_child(palm)


func _place_encounters() -> void:
	# Coffre au pied de la butte, parmi des débris
	chest = LootChest.new()
	chest.world = world
	chest.contents.append(load("res://data/weapons/pistol.tres"))
	chest.position = Vector2(-230, BeachMap.butte_y(-230) + 60.0)
	world.add_child(chest)
	# Premier monstre, seul
	first_mob = _spawn_mob(Vector2(700, 80))
	# Puis deux autres
	duo.append(_spawn_mob(Vector2(1620, 30)))
	duo.append(_spawn_mob(Vector2(1690, 85)))


func _spawn_mob(pos: Vector2) -> Mob:
	var m := Mob.new()
	m.mob_type = MobType.by_id("rongeur")
	m.level = 1
	m.posted = true
	m.home = pos
	m.position = pos
	m.wander_radius = 50.0
	m.leash_range = 420.0
	m.aggro_range = 260.0
	m.world = world
	world.add_child(m)
	return m


# --- Déroulé ----------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(survivor) or step == Step.DONE:
		return
	_t += delta
	camera.position = survivor.global_position
	var p := survivor.global_position
	_status.text = "PV %d/%d   ·   %s" % [survivor.hp, survivor.max_hp, survivor.weapon.weapon_name]
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
				_advance(Step.FOLLOW)
		Step.FOLLOW:
			if p.x > -520.0:
				_advance(Step.CHEST)
		Step.CHEST:
			if chest.is_broken:
				_advance(Step.PICKUP)
			elif p.x > 380.0:
				_advance(Step.FIRST_MOB)   # coffre ignoré : on continue quand même
		Step.PICKUP:
			if survivor.weapon.weapon_name != "Lance-pierre" or not survivor.inventory.is_empty():
				survivor._say("Un pistolet rouillé. Mieux que rien.", 2.5)
				_set_objective("Continuer vers l'est, le long de la butte")
				step = Step.FIRST_MOB
			elif p.x > 380.0:
				_advance(Step.FIRST_MOB)
		Step.FIRST_MOB:
			if not is_instance_valid(first_mob) or not first_mob.is_alive():
				survivor._say("C'était quoi, ce truc ?!", 2.5)
				_advance(Step.DUO)
			elif first_mob.chasing or p.x > 420.0:
				_set_objective("Un monstre ! Visez-le et tirez (clic gauche maintenu). Reculez s'il approche.")
		Step.DUO:
			var alive := duo.filter(func(m): return is_instance_valid(m) and m.is_alive())
			if alive.is_empty():
				survivor._say("Il y en a d'autres… Charmant séjour.", 2.5)
				_advance(Step.ROUND_BUTTE)
			elif p.x > 1250.0:
				_set_objective("Encore deux ! Gardez vos distances en tirant.")
		Step.ROUND_BUTTE:
			if BeachMap.past_butte(p):
				_finish()


func _advance(next: Step) -> void:
	step = next
	match next:
		Step.MOVE:
			_set_objective("Se déplacer : ZQSD (ou flèches)")
		Step.FOLLOW:
			_set_objective("Impossible de franchir la butte. La longer vers l'est.")
		Step.CHEST:
			_set_objective("Un coffre ! Visez-le à la souris, clic gauche pour tirer dessus.")
		Step.PICKUP:
			_set_objective("Ramasser ce qui est tombé (passer dessus)")
		Step.FIRST_MOB:
			_set_objective("Continuer vers l'est, le long de la butte")
		Step.DUO:
			_set_objective("Continuer vers l'est")
		Step.ROUND_BUTTE:
			_set_objective("Trouver le bout de la butte et passer de l'autre côté")


func _finish() -> void:
	step = Step.DONE
	_set_objective("Prologue terminé")
	survivor._say("Enfin de l'autre côté. Et maintenant ?", 3.0)
	var tw := create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_fade, "color:a", 0.85, 1.5)
	tw.tween_callback(func(): _show_overlay("Fin du prologue", "Au-delà de la butte, l'île continue.\nÀ suivre…", true))


func _on_survivor_died(_s: Survivor) -> void:
	step = Step.DONE
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.85, 1.2)
	tw.tween_callback(func(): _show_overlay("Mort définitive", "Sur cette île, on ne revient pas.", true))


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
	v.add_child(UIStyle.label("PROLOGUE · LA PLAGE", 12, UIStyle.ACCENT))
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
