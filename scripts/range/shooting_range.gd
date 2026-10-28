extends Node2D
## Champ de tir : une petite carte pour essayer les armes.
## - Un survivant, qui ne meurt pas et n'a ni faim ni soif.
## - Toutes les armes de data/weapons, au choix (boutons ou touches 1 à 9).
## - Des mannequins à 100, 200, 300 et 400 px (PV infinis), un mannequin qui
##   se déplace sur un rail, un rocher pour les impacts sur obstacle.
## - Des monstres à faire apparaître (type et niveau au choix), inoffensifs
##   ou non, pour tester dégâts, éléments, résistances et recul.
## - Statistiques : tirs, touches, précision, dégâts par seconde (3 dernières
##   secondes) et dégâts totaux.

const MENU_SCENE := "res://scenes/menu.tscn"
const WEAPON_DIR := "res://data/weapons/"
const MOB_TYPES := ["rongeur", "cracheur", "cogneur", "feu_follet"]
const DPS_WINDOW := 3.0

## Limites de la carte (px).
const AREA := Rect2(-720, -360, 1420, 720)
const START := Vector2(-200, 0)
const DUMMY_DISTANCES := [100.0, 200.0, 300.0, 400.0]
## Les mannequins sont disposés en éventail pour qu'aucun ne cache l'autre.
const DUMMY_ANGLES := [-24.0, -8.0, 8.0, 24.0]
## La caméra regarde un peu devant le tireur, vers les cibles.
const CAMERA_LEAD := Vector2(200, 0)

var world: Node2D
var survivor: Survivor
var camera: Camera2D
var weapons: Array[WeaponData] = []
var dummies: Array[TrainingDummy] = []
var mob_level := 1

var shots := 0                 # projectiles tirés par le survivant
var hits := 0                  # projectiles qui ont touché une cible
var total_damage := 0.0
var _recent: Array = []        # [instant, dégâts] sur la fenêtre DPS
var _t := 0.0

var _stats: Label
var _weapon_label: Label
var _level_label: Label
var _harmless: CheckButton
var _weapon_buttons: Array[Button] = []


func _enter_tree() -> void:
	InputSetup.register()


func _ready() -> void:
	Terrain.enabled = false
	Nav.clear()
	Survivor.shelter = null
	Survivor.night = false
	Mob.harmless = true
	Survivor.alert = false
	Survivor.squad_focus = null
	BuildManager.placing = false

	add_child(RangeGround.new())
	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)
	world.child_entered_tree.connect(_on_world_child)
	_build_bounds()
	_place_targets()

	var stock := VillageStock.new()
	add_child(stock)
	survivor = Survivor.new()
	survivor.world = world
	survivor.stock = stock
	survivor.needs_enabled = false
	survivor.camp_regen = false
	survivor.hp_floor = 1          # on ne meurt pas au champ de tir
	survivor.village_center = Vector2(-99999, -99999)
	survivor.position = START
	world.add_child(survivor)
	survivor.selected = true

	var ring := RangeRing.new()
	ring.survivor = survivor
	world.add_child(ring)

	camera = Camera2D.new()
	camera.zoom = Vector2(1.3, 1.3)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = int(AREA.position.x - 80)
	camera.limit_right = int(AREA.end.x + 80)
	camera.limit_top = int(AREA.position.y - 80)
	camera.limit_bottom = int(AREA.end.y + 80)
	add_child(camera)
	camera.make_current()

	weapons = load_weapons()
	_build_hud()
	select_weapon(0)
	camera.position = survivor.global_position + CAMERA_LEAD
	camera.reset_smoothing()


## Toutes les armes du dossier data/weapons, de la plus faible à la plus forte
## (le lance-pierre en premier).
static func load_weapons() -> Array[WeaponData]:
	var out: Array[WeaponData] = []
	for f in DirAccess.get_files_at(WEAPON_DIR):
		var file := f.trim_suffix(".remap")   # projet exporté
		if not file.ends_with(".tres"):
			continue
		var w := load(WEAPON_DIR + file) as WeaponData
		if w and not out.has(w):
			out.append(w)
	out.sort_custom(func(a: WeaponData, b: WeaponData):
		if a.resource_path == Survivor.SLINGSHOT_PATH:
			return true
		if b.resource_path == Survivor.SLINGSHOT_PATH:
			return false
		return a.dps() < b.dps())
	return out


func select_weapon(i: int) -> void:
	if i < 0 or i >= weapons.size():
		return
	survivor.equip(weapons[i])
	for k in _weapon_buttons.size():
		_weapon_buttons[k].modulate = UIStyle.ACCENT if k == i else Color.WHITE
	var w := weapons[i]
	var t := "%s\n%.0f × %d dégâts · %.1f tirs/s · dispersion %.0f°\nportée %.0f px · vitesse %.0f px/s · recul %.0f" % [
		w.weapon_name, w.damage, w.bullets_per_shot, w.fire_rate, w.spread_deg, w.max_range, w.projectile_speed, w.recoil]
	if w.element != WeaponData.Element.AUCUN:
		t += "\n%s +%.0f par projectile" % [WeaponData.element_name(w.element), w.element_damage]
	t += "\n≈ %.0f dégâts/s en théorie" % w.dps()
	_weapon_label.text = t
	reset_stats()


func reset_stats() -> void:
	shots = 0
	hits = 0
	total_damage = 0.0
	_recent.clear()
	for d in dummies:
		d.reset()


# --- Carte ------------------------------------------------------------------

func _build_bounds() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	var r := AREA
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		var shape := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = pts[i]
		seg.b = pts[(i + 1) % 4]
		shape.shape = seg
		body.add_child(shape)


func _place_targets() -> void:
	# Des mannequins en éventail devant le pas de tir, un mannequin mobile plus loin
	for i in DUMMY_DISTANCES.size():
		var d: float = DUMMY_DISTANCES[i]
		var dummy := TrainingDummy.new()
		dummy.position = START + Vector2(d, 0).rotated(deg_to_rad(DUMMY_ANGLES[i]))
		dummy.label = "%d px" % int(d)
		world.add_child(dummy)
		dummy.damaged.connect(_on_damage)
		dummies.append(dummy)
	var mover := TrainingDummy.new()
	mover.position = START + Vector2(300, -170)
	mover.rail = 150.0
	mover.label = "mobile"
	world.add_child(mover)
	mover.damaged.connect(_on_damage)
	dummies.append(mover)
	# Rocher (impact sur obstacle) et coffre (impact sur bois)
	var rock_body := StaticBody2D.new()
	rock_body.collision_layer = 4
	rock_body.position = START + Vector2(200, 170)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 18.0
	cs.shape = circle
	rock_body.add_child(cs)
	var rock := Ridge.Rock.new()
	rock.size = 1.5
	rock.seed_value = 7
	rock_body.add_child(rock)
	world.add_child(rock_body)


## Fait apparaître un monstre posté dans la zone libre, à droite.
func spawn_mob(type_id: String) -> Mob:
	var m := Mob.new()
	m.mob_type = MobType.by_id(type_id)
	m.level = mob_level
	m.posted = true
	var p := START + Vector2(randf_range(420, 620), randf_range(-120, 200))
	m.home = p
	m.position = p
	m.wander_radius = 50.0
	m.leash_range = 300.0
	m.aggro_range = 300.0
	m.world = world
	world.add_child(m)
	return m


func clear_mobs() -> void:
	for m in get_tree().get_nodes_in_group("mobs"):
		m.queue_free()


# --- Statistiques -----------------------------------------------------------

func _on_world_child(n: Node) -> void:
	if n is Projectile and n.shooter == survivor:
		shots += 1
		n.hit_body.connect(_on_projectile_hit)


func _on_projectile_hit(body: Node, _p: Projectile) -> void:
	if body is TrainingDummy or body is Mob:
		hits += 1
		if body is Mob:
			# Dégâts réels après résistances : on lit la perte de PV juste après.
			var before: float = body.hp
			await get_tree().process_frame
			if is_instance_valid(body):
				_on_damage(maxf(before - body.hp, 0.0))


func _on_damage(amount: float) -> void:
	total_damage += amount
	_recent.append([_t, amount])


func dps() -> float:
	var sum := 0.0
	for r in _recent:
		sum += r[1]
	return sum / DPS_WINDOW


func _process(delta: float) -> void:
	_t += delta
	while not _recent.is_empty() and _t - _recent[0][0] > DPS_WINDOW:
		_recent.pop_front()
	camera.position = survivor.global_position + CAMERA_LEAD
	var acc := 100.0 * hits / shots if shots > 0 else 0.0
	_stats.text = "Tirs %d · touches %d · précision %d %%\nDégâts/s (3 s) : %.1f · dégâts totaux : %.0f" % [shots, hits, roundi(acc), dps(), total_damage]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.physical_keycode
		if k >= KEY_1 and k <= KEY_9:
			select_weapon(k - KEY_1)
			get_viewport().set_input_as_handled()
		elif k == KEY_R:
			reset_stats()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("deselect"):
		_to_menu()
		get_viewport().set_input_as_handled()


func _to_menu() -> void:
	Mob.harmless = false
	get_tree().change_scene_to_file(MENU_SCENE)


# --- Interface --------------------------------------------------------------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	# À gauche : armes et statistiques
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2, 12))
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(330, 0)
	layer.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(UIStyle.label("CHAMP DE TIR", 12, UIStyle.ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for i in weapons.size():
		var b := UIStyle.button("%d  %s" % [i + 1, weapons[i].weapon_name], 12)
		b.custom_minimum_size = Vector2(150, 30)
		b.pressed.connect(select_weapon.bind(i))
		grid.add_child(b)
		_weapon_buttons.append(b)
	_weapon_label = UIStyle.label("", 13)
	v.add_child(_weapon_label)
	_stats = UIStyle.label("", 13, UIStyle.ACCENT)
	v.add_child(_stats)
	var reset := UIStyle.button("Remettre les compteurs à zéro  [R]", 12)
	reset.pressed.connect(reset_stats)
	v.add_child(reset)
	v.add_child(UIStyle.label("ZQSD : bouger · souris : viser · clic : tirer\nLe cercle montre la portée de l'arme.", 11, UIStyle.TEXT_DIM))
	# À droite : monstres et sortie
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2, 12))
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -232
	right.offset_right = -12
	right.offset_top = 12
	layer.add_child(right)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 6)
	right.add_child(rv)
	var menu := UIStyle.button("Menu  [Échap]", 13)
	menu.pressed.connect(_to_menu)
	rv.add_child(menu)
	rv.add_child(UIStyle.label("MONSTRES", 12, UIStyle.ACCENT))
	var lv := HBoxContainer.new()
	rv.add_child(lv)
	var minus := UIStyle.button("−", 14)
	minus.custom_minimum_size = Vector2(32, 28)
	minus.pressed.connect(func(): _set_level(mob_level - 1))
	lv.add_child(minus)
	_level_label = UIStyle.label("", 13)
	_level_label.custom_minimum_size = Vector2(90, 0)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(_level_label)
	var plus := UIStyle.button("+", 14)
	plus.custom_minimum_size = Vector2(32, 28)
	plus.pressed.connect(func(): _set_level(mob_level + 1))
	lv.add_child(plus)
	_set_level(1)
	for id in MOB_TYPES:
		var b := UIStyle.button("+ " + MobType.by_id(id).type_name, 12)
		b.pressed.connect(func(): spawn_mob(id))
		rv.add_child(b)
	var clear := UIStyle.button("Retirer les monstres", 12)
	clear.pressed.connect(clear_mobs)
	rv.add_child(clear)
	_harmless = CheckButton.new()
	_harmless.text = "Inoffensifs"
	_harmless.button_pressed = true
	_harmless.focus_mode = Control.FOCUS_NONE
	_harmless.add_theme_font_size_override("font_size", 12)
	_harmless.toggled.connect(func(on): Mob.harmless = on)
	rv.add_child(_harmless)


func _set_level(l: int) -> void:
	mob_level = clampi(l, 1, 10)
	_level_label.text = "Niveau %d" % mob_level


## Sol du champ de tir : terre battue, couloir de tir et repères de distance.
class RangeGround:
	extends Node2D

	func _ready() -> void:
		z_index = -10

	func _draw() -> void:
		var r := AREA
		draw_rect(r.grow(400), Color(0.13, 0.12, 0.11))
		draw_rect(r, Color(0.46, 0.4, 0.295))
		var tw := IsoGround.TILE_W
		var th := IsoGround.TILE_H
		for i in range(-30, 31):
			for j in range(-30, 31):
				var c := IsoGround.tile_to_world(i, j)
				if not r.grow(-20).has_point(c):
					continue
				var col := Color(0.47, 0.41, 0.3) if (i + j) & 1 else Color(0.45, 0.39, 0.29)
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -th / 2.0), c + Vector2(tw / 2.0, 0), c + Vector2(0, th / 2.0), c + Vector2(-tw / 2.0, 0)]), col)
		# Zone de tir en éventail et arcs de distance
		var fan := PackedVector2Array([START])
		for k in 17:
			fan.append(START + Vector2(440, 0).rotated(deg_to_rad(-34.0 + 68.0 * k / 16.0)))
		draw_colored_polygon(fan, Color(0.55, 0.48, 0.35, 0.6))
		for d in DUMMY_DISTANCES:
			draw_arc(START, d, deg_to_rad(-34.0), deg_to_rad(34.0), 24, Color(1, 1, 1, 0.35), 2.0, true)
		# Pas de tir
		draw_rect(Rect2(START + Vector2(-30, -40), Vector2(16, 80)), Color(0.95, 0.75, 0.3, 0.7))
		# Clôture
		draw_rect(r, Color(0.3, 0.22, 0.14), false, 4.0)


## Cercle de portée de l'arme autour du survivant (les tirs vont en ligne
## droite à l'écran : la portée est un cercle).
class RangeRing:
	extends Node2D
	var survivor: Survivor

	func _ready() -> void:
		z_index = -5
		z_as_relative = false

	func _process(_d: float) -> void:
		if is_instance_valid(survivor):
			global_position = survivor.global_position
		queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(survivor) or survivor.weapon == null:
			return
		var r := survivor.weapon.max_range
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(1, 0.85, 0.4, 0.35), 2.0, true)
