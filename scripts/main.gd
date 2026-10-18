extends Node2D
## Scène principale du prototype.
## Monte le monde, les survivants, les cibles, la mare, le stock, la caméra et le HUD.

const VILLAGE_CENTER := Vector2.ZERO
const START_SURVIVORS := 5
const SQUAD_MAX := 4
const FORMATION_SPACING := 30.0
## Caméra libre (mode gestion) : vitesse en pixels écran par seconde, limites du monde.
const FREE_CAMERA_SPEED := 700.0
const CAMERA_LIMIT := Vector2(2650, 1330)

enum Formation { COLONNE, LIGNE, CERCLE }
const FORMATION_NAMES := ["Colonne", "Ligne", "Cercle"]

## Escouade enregistrée (GDD 6) : conservée quand on entre et sort du mode escouade.
var squad: Array[Survivor] = []
var squad_mode := false
var formation: Formation = Formation.COLONNE
var squad_bar: SquadBar
var _leader_dir := Vector2.DOWN

var world: Node2D
var camera: Camera2D
var stock: VillageStock
var hud_label: Label
var hud_portrait: SurvivorPortrait
var stock_label: Label
var notice_label: Label
var panel: ManagementPanel
var debug_panel: DebugPanel
var wave_manager: WaveManager
var build_manager: BuildManager
var build_bar: BuildBar
var alert_button: Button
var alert_banner: Label
var alert_active := false
## Coffres de loot (GDD 8 bis) : on tire dessus pour les casser.
## Ennemis postés sur la carte (camps) et générateurs de bots.
const ENEMY_CAMPS := [
	[Vector2(1300, -420), 3],
	[Vector2(-950, -300), 3],
	[Vector2(1150, 330), 2],   # gardent le coffre de l'est
	[Vector2(1750, 60), 3],
	[Vector2(-300, -800), 2],  # gardent le coffre du nord
]
## Les deux générateurs gardent le seul passage de la crête (côté est).
const SPAWNER_POSITIONS := [Vector2(Terrain.RIDGE_X + 75, -80), Vector2(Terrain.RIDGE_X + 75, 80)]
const CHEST_POSITIONS := [Vector2(-880, -140), Vector2(-260, -760), Vector2(1080, 360), Vector2(-160, 520), Vector2(1850, -320)]
var loot_panel: LootPanel
var survivors: Array[Survivor] = []
var resource_nodes: Array[ResourceNode] = []
var selected: Survivor = null


func _enter_tree() -> void:
	_register_inputs()


func _ready() -> void:
	var ground := IsoGround.new()
	ground.z_index = -10
	add_child(ground)

	stock = VillageStock.new()
	stock.name = "VillageStock"
	add_child(stock)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	# Crête rocheuse qui coupe la carte en deux, un seul passage (+ bordure de carte)
	var ridge := Ridge.new()
	ridge.name = "Crete"
	ridge.world = world
	add_child(ridge)
	ridge.build()

	# Point de récolte d'eau
	var pond := ResourceNode.new()
	pond.name = "Mare"
	pond.position = Vector2(520, 200)
	world.add_child(pond)
	resource_nodes.append(pond)

	# Point de récolte de nourriture
	var grove := ResourceNode.new()
	grove.name = "Cocotiers"
	grove.display_name = "Cocotiers"
	grove.resource_type = "nourriture"
	grove.visual = ResourceNode.Visual.COCOTIERS
	grove.gather_time = 3.0
	grove.radius = 44.0
	grove.position = Vector2(-500, 470)
	world.add_child(grove)
	resource_nodes.append(grove)

	# Point de récolte de bois (construction)
	var forest := ResourceNode.new()
	forest.name = "Foret"
	forest.display_name = "Forêt"
	forest.resource_type = "bois"
	forest.visual = ResourceNode.Visual.FORET
	forest.gather_time = 4.0
	forest.radius = 48.0
	forest.position = Vector2(-320, -440)
	world.add_child(forest)
	resource_nodes.append(forest)

	for i in START_SURVIVORS:
		_spawn_survivor(VILLAGE_CENTER + Vector2(randf_range(-60, 60), randf_range(-30, 30)), i == 0)

	# Vagues de monstres (déclenchées depuis le panneau debug pour l'instant)
	wave_manager = WaveManager.new()
	wave_manager.name = "WaveManager"
	wave_manager.world = world
	wave_manager.village_center = VILLAGE_CENTER
	wave_manager.wave_started.connect(func(n, c, d): _notify("Vague n°%d : %d monstres arrivent par le %s !" % [n, c, d.to_lower()]))
	wave_manager.wave_cleared.connect(func(n): _notify("Vague n°%d repoussée" % n))
	add_child(wave_manager)

	# Constructions (murs, tourelles)
	build_manager = BuildManager.new()
	build_manager.name = "BuildManager"
	build_manager.world = world
	build_manager.stock = stock
	build_manager.message.connect(_notify)
	build_manager.placed.connect(func(b): _notify("Chantier lancé : %s" % b.display_name))
	add_child(build_manager)

	var pickup := ItemPickup.new()
	pickup.item = load("res://data/weapons/shotgun.tres")
	pickup.position = Vector2(-320, 260)
	world.add_child(pickup)

	respawn_chests()
	_plant_trees()
	setup_map_enemies()

	camera = Camera2D.new()
	camera.zoom = Vector2(1.6, 1.6)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()

	_build_hud()
	_select(survivors[0])


func _spawn_survivor(pos: Vector2, hero := false) -> Survivor:
	var s := Survivor.new()
	s.is_hero = hero
	s.world = world
	s.stock = stock
	s.village_center = VILLAGE_CENTER
	s.position = pos
	s.died.connect(_on_survivor_died)
	world.add_child(s)
	survivors.append(s)
	return s


func _register_inputs() -> void:
	# Touches physiques : WASD en QWERTY = ZQSD en AZERTY.
	var map := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"next_survivor": [KEY_TAB],
		"deselect": [KEY_ESCAPE],
		"toggle_panel": [KEY_G],
		"toggle_loot": [KEY_I],
		"toggle_squad": [KEY_F],
		"cycle_formation": [KEY_V],
		"debug_needs": [KEY_F10],
		"toggle_debug": [KEY_F1],
		"toggle_build": [KEY_B],
		"toggle_alert": [KEY_H],
	}
	for action in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
	if not InputMap.has_action("shoot"):
		InputMap.add_action("shoot")
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("shoot", mb)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_panel"):
		_toggle_panel()
	elif event.is_action_pressed("toggle_loot"):
		_toggle_loot()
	elif event.is_action_pressed("toggle_squad"):
		set_squad_mode(not squad_mode)
	elif event.is_action_pressed("debug_needs"):
		debug_starve_all()
	elif event.is_action_pressed("toggle_debug"):
		debug_panel.toggle()
	elif event.is_action_pressed("toggle_build"):
		toggle_build_mode()
	elif event.is_action_pressed("toggle_alert"):
		set_alert(not alert_active)
	elif event.is_action_pressed("cycle_formation"):
		formation = ((formation + 1) % Formation.size()) as Formation
		_notify("Formation : %s" % FORMATION_NAMES[formation])
	elif event.is_action_pressed("next_survivor"):
		_select_next()
	elif event.is_action_pressed("deselect"):
		if panel.visible or loot_panel.visible:
			panel.visible = false
			loot_panel.visible = false
		else:
			release_control()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		# En mode escouade, 1-4 désignent les membres ; sinon tous les survivants.
		var pool: Array = squad if squad_mode else survivors
		if n >= 0 and n < 9 and n < pool.size():
			_select(pool[n])


## Clic droit : sélectionner le survivant sous la souris, sinon assigner
## le survivant contrôlé au point de récolte survolé.
func _on_right_click() -> void:
	var mouse := get_global_mouse_position()
	for s in survivors:
		if s.global_position.distance_to(mouse + Vector2(0, 12)) < 20.0:
			_select(s)
			return
	for t in get_tree().get_nodes_in_group("turrets"):
		if t.contains(mouse):
			if not t.is_built:
				_notify("La tourelle n'est pas encore terminée")
			elif is_instance_valid(selected):
				assign_survivor(selected, t)
			else:
				_notify("Sélectionne d'abord un survivant à poster")
			return
	for node in resource_nodes:
		if node.contains(mouse):
			if is_instance_valid(selected):
				assign_survivor(selected, node)
			else:
				_notify("Sélectionne d'abord un survivant à assigner")
			return


## Tâches possibles : points de récolte et tourelles terminées.
func get_task_targets() -> Array:
	var out: Array = []
	out.append_array(resource_nodes)
	for t in get_tree().get_nodes_in_group("turrets"):
		if t.is_built and not t.is_destroyed:
			out.append(t)
	return out


## Assigne un survivant à un point de récolte ou à une tourelle (null = libérer).
## S'il était contrôlé, on passe au premier survivant libre.
func assign_survivor(s: Survivor, node: Node2D) -> void:
	if node is Turret:
		s.assign_post(node)
	else:
		if s.post != null:
			s.assign_post(null)
		s.assign(node)
	if node:
		_notify("%s est assigné·e à : %s" % [s.first_name, node.display_name])
		if s == selected and not squad_mode:
			var next: Survivor = null
			for other in survivors:
				if other.task_node == null and other.post == null and other != s:
					next = other
					break
			_select(next)
	else:
		_notify("%s est libéré·e" % s.first_name)


func _select(s: Survivor) -> void:
	# En mode escouade, on ne contrôle que le leader, choisi parmi les membres.
	if squad_mode and s != null and not squad.has(s):
		_notify("En mode escouade, choisis le leader parmi les membres (F pour quitter)")
		return
	if squad_mode and s == null:
		return
	if is_instance_valid(selected):
		selected.selected = false
		if squad_mode and squad.has(selected):
			selected.following = true
	selected = s
	if is_instance_valid(selected):
		selected.selected = true
		selected.following = false


func _select_next() -> void:
	var pool: Array = squad if squad_mode else survivors
	if pool.is_empty():
		return
	var idx := pool.find(selected)
	_select(pool[(idx + 1) % pool.size()])


# --- Escouade ---------------------------------------------------------------

func _on_squad_member_clicked(s: Survivor) -> void:
	_select(s)


## Ajoute ou retire un survivant de l'escouade enregistrée (4 membres max).
func toggle_squad_member(s: Survivor) -> void:
	if squad.has(s):
		_remove_from_squad(s)
		_notify("%s quitte l'escouade" % s.first_name)
	elif squad.size() >= SQUAD_MAX:
		_notify("L'escouade est complète (%d membres)" % SQUAD_MAX)
	else:
		squad.append(s)
		s.squad_member = true
		s.following = squad_mode and s != selected
		_reindex_squad()
		_notify("%s rejoint l'escouade (%d/%d)" % [s.first_name, squad.size(), SQUAD_MAX])


func _remove_from_squad(s: Survivor) -> void:
	squad.erase(s)
	s.squad_member = false
	s.following = false
	_reindex_squad()
	if squad_mode:
		if squad.is_empty():
			set_squad_mode(false)
		elif s == selected:
			s.selected = false
			selected = null
			_select(squad[0])


func _reindex_squad() -> void:
	for i in squad.size():
		squad[i].squad_index = i


## Entre ou sort du mode escouade. La composition reste enregistrée.
func set_squad_mode(on: bool) -> void:
	if on == squad_mode:
		return
	if on:
		if squad.is_empty():
			_notify("Compose d'abord une escouade dans le panneau des survivants (G)")
			return
		var leader: Survivor = selected if squad.has(selected) else squad[0]
		squad_mode = true
		if is_instance_valid(selected) and selected != leader:
			selected.selected = false
		selected = null
		for m in squad:
			m.following = true
		_select(leader)
		_notify("Mode escouade : %s mène le groupe" % leader.first_name)
	else:
		squad_mode = false
		for m in squad:
			m.following = false  # chacun reprend sa tâche ou son errance
		_notify("Fin du mode escouade")


func _physics_process(_delta: float) -> void:
	if not squad_mode or not is_instance_valid(selected):
		return
	if selected.velocity.length() > 10.0:
		_leader_dir = selected.velocity.normalized()
	var followers: Array[Survivor] = []
	for m in squad:
		if m != selected:
			followers.append(m)
	var offsets := formation_offsets(followers.size(), _leader_dir)
	for i in followers.size():
		followers[i].follow_point = selected.global_position + offsets[i]
		followers[i].follow_speed = selected.move_speed()


## Places des suiveurs par rapport au leader, selon la formation et la direction.
func formation_offsets(n: int, dir: Vector2) -> Array[Vector2]:
	var perp := Vector2(-dir.y, dir.x)
	var out: Array[Vector2] = []
	for i in n:
		match formation:
			Formation.COLONNE:
				out.append(-dir * FORMATION_SPACING * (i + 1))
			Formation.LIGNE:
				var side := 1.0 if i % 2 == 0 else -1.0
				out.append(perp * FORMATION_SPACING * ceilf((i + 1) / 2.0) * side)
			Formation.CERCLE:
				var a: float = dir.angle() + PI + TAU * i / maxf(n, 1.0)
				out.append(Vector2(cos(a), sin(a) * 0.6) * FORMATION_SPACING * 1.4)
	return out


func _on_survivor_died(s: Survivor) -> void:
	survivors.erase(s)
	if squad.has(s):
		_remove_from_squad(s)  # passe le commandement au membre suivant
	if s == selected:
		selected = null
	if survivors.is_empty():
		# Défaite totale : un seul nouveau survivant au centre du village (GDD 11).
		# Le stock du village est conservé ; la charge portée est perdue avec le survivant.
		var fresh := Survivor.new()
		fresh.world = world
		fresh.stock = stock
		fresh.village_center = VILLAGE_CENTER
		fresh.position = VILLAGE_CENTER
		fresh.died.connect(_on_survivor_died)
		world.add_child.call_deferred(fresh)
		survivors.append(fresh)


## Relâche le survivant contrôlé : plus personne n'est sélectionné, on passe
## en mode gestion avec caméra libre (GDD 4.2). En mode escouade, on quitte
## d'abord le mode (la composition reste enregistrée).
func release_control() -> void:
	if not is_instance_valid(selected):
		return
	if squad_mode:
		set_squad_mode(false)
	_select(null)
	_notify("Mode gestion : caméra libre")


func _process(delta: float) -> void:
	if is_instance_valid(selected):
		camera.position = selected.global_position
	else:
		# Caméra libre : mêmes touches que le déplacement, vitesse constante à l'écran.
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		camera.position += input * FREE_CAMERA_SPEED / camera.zoom.x * delta
		camera.position = camera.position.clamp(-CAMERA_LIMIT, CAMERA_LIMIT)
	panel.sync(survivors)
	# En mode gestion (personne de sélectionné), la barre d'escouade se masque.
	squad_bar.refresh(squad, selected, squad_mode, FORMATION_NAMES[formation])
	if not is_instance_valid(selected):
		squad_bar.visible = false
	_update_hud()


## Arbres obstacles : lisière sur les bords hors mer, bosquets dispersés, en
## gardant dégagés le camp, les points d'intérêt et les couloirs qui y mènent.
func _plant_trees() -> void:
	var field := TreeField.new()
	field.world = world
	var gap := Vector2(Terrain.RIDGE_X, Terrain.GAP_Y)
	for n in resource_nodes:
		field.keep_clear.append([n.global_position, n.radius + 70.0])
		field.corridors.append([VILLAGE_CENTER, n.global_position])
	for pos in CHEST_POSITIONS:
		field.keep_clear.append([pos, 70.0])
		field.corridors.append([VILLAGE_CENTER if pos.x < Terrain.RIDGE_X else gap, pos])
	for camp in ENEMY_CAMPS:
		field.keep_clear.append([camp[0], 110.0])
		field.corridors.append([VILLAGE_CENTER if camp[0].x < Terrain.RIDGE_X else gap, camp[0]])
	for pos in SPAWNER_POSITIONS:
		field.keep_clear.append([pos, 170.0])
	field.corridors.append([VILLAGE_CENTER, gap])
	field.keep_clear.append([Vector2(-320, 260), 60.0])  # fusil au sol
	# Arrivées des vagues et leur trajet vers le camp
	for d in WaveManager.DIRECTIONS.values():
		var spawn: Vector2 = VILLAGE_CENTER + d * WaveManager.SPAWN_DISTANCE
		field.keep_clear.append([spawn, 170.0])
		field.corridors.append([spawn, gap if spawn.x > Terrain.RIDGE_X else VILLAGE_CENTER])
	add_child(field)
	field.build()


# --- Outils de debug (panneau F1) ------------------------------------------

## Remplace les coffres cassés et pose ceux qui manquent.
func respawn_chests() -> void:
	for c in get_tree().get_nodes_in_group("chests"):
		if c.is_broken:
			c.remove_from_group("chests")
			c.queue_free()
	for pos in CHEST_POSITIONS:
		var exists := false
		for c in get_tree().get_nodes_in_group("chests"):
			if c.position == pos and not c.is_broken:
				exists = true
		if not exists:
			var chest := LootChest.new()
			chest.world = world
			chest.position = pos
			world.add_child(chest)


## (Re)place les ennemis postés et les générateurs de bots.
func setup_map_enemies() -> void:
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.posted:
			m.queue_free()
	for sp in get_tree().get_nodes_in_group("spawners"):
		sp.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for camp in ENEMY_CAMPS:
		var home: Vector2 = camp[0]
		for i in camp[1]:
			var m := Mob.new()
			m.posted = true
			m.home = home
			m.aggro_range = 200.0
			m.village_center = VILLAGE_CENTER
			m.position = home + Vector2(rng.randf_range(-30, 30), rng.randf_range(-15, 15))
			world.add_child(m)
	for pos in SPAWNER_POSITIONS:
		var sp := MobSpawner.new()
		sp.world = world
		sp.village_center = VILLAGE_CENTER
		sp.position = pos
		sp.zone_radius = 120.0
		sp.destroyed.connect(func(_s): _notify("Générateur détruit ! Éliminez ses derniers bots."))
		sp.zone_secured.connect(func(_s): _notify("Zone sécurisée"))
		world.add_child(sp)


func debug_destroy_spawners() -> void:
	for sp in get_tree().get_nodes_in_group("spawners"):
		if not sp.is_destroyed:
			sp.take_damage(99999.0)


func debug_recruit() -> void:
	var s := _spawn_survivor(VILLAGE_CENTER + Vector2(randf_range(-40, 40), randf_range(-20, 20)))
	_notify("%s rejoint le village" % s.full_name())


func debug_give_xp(amount: int) -> void:
	if is_instance_valid(selected):
		selected.add_xp(amount)
		_notify("%s : +%d XP" % [selected.first_name, amount])
	else:
		_notify("Aucun survivant contrôlé")


func debug_heal_all() -> void:
	for s in survivors:
		s.hp = s.max_hp
		s.thirst = Survivor.NEED_MAX
		s.hunger = Survivor.NEED_MAX
	_notify("Tout le monde est soigné et rassasié")


func debug_starve_all() -> void:
	for s in survivors:
		s.thirst = 20.0
		s.hunger = 25.0
	_notify("Debug : tous les survivants ont faim et soif")


func debug_add_random_weapon() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var item: Resource = LootTable.roll(rng, 1, 1)[0]
	stock.add_item(item)
	_notify("Stock : +1 %s" % LootTable.item_name(item))


# --- Construction et alerte -------------------------------------------------

func toggle_build_mode() -> void:
	build_bar.visible = not build_bar.visible
	if not build_bar.visible:
		build_manager.set_tool("")


func _on_build_tool(tool: String) -> void:
	build_manager.set_tool(tool)
	if tool != "":
		build_bar.visible = true


## Alerte générale : les survivants libres rentrent défendre le camp ; les
## servants restent à leur tourelle. À la levée, chacun reprend sa tâche.
func set_alert(on: bool) -> void:
	alert_active = on
	Survivor.alert = on
	alert_banner.visible = on
	alert_button.text = "Lever l'alerte  [H]" if on else "ALERTE  [H]"
	alert_button.add_theme_stylebox_override("normal", UIStyle.box(Color(0.55, 0.12, 0.1) if on else Color(0.35, 0.1, 0.08), Color(1, 0.4, 0.3), 8, 2, 6))
	for s in survivors:
		if not s.selected and not s.following and s.post == null:
			s._say("On rentre au camp !" if on else "Fausse alerte ?", 2.0)
	_notify("ALERTE : tout le monde au camp !" if on else "Alerte levée : chacun reprend sa tâche")


## Les deux panneaux (survivants, objets) ne s'affichent pas en même temps.
func _toggle_panel() -> void:
	loot_panel.visible = false
	panel.toggle()


func _toggle_loot() -> void:
	panel.visible = false
	loot_panel.toggle()


func _notify(text: String) -> void:
	notice_label.text = text
	notice_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(notice_label, "modulate:a", 0.0, 0.6)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var info := PanelContainer.new()
	info.position = Vector2(12, 12)
	info.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2, 10))
	layer.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	info.add_child(row)
	hud_portrait = SurvivorPortrait.new()
	hud_portrait.custom_minimum_size = Vector2(64, 64)
	row.add_child(hud_portrait)
	hud_label = UIStyle.label("", 14)
	row.add_child(hud_label)

	# Stock du village, en haut au centre
	var stock_box := PanelContainer.new()
	stock_box.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2, 8))
	stock_box.anchor_left = 0.5
	stock_box.anchor_right = 0.5
	stock_box.offset_left = -290
	stock_box.offset_right = 200
	stock_box.offset_top = 12
	layer.add_child(stock_box)
	stock_label = UIStyle.label("", 15)
	stock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock_box.add_child(stock_label)

	notice_label = UIStyle.label("", 15, UIStyle.ACCENT)
	notice_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	notice_label.add_theme_constant_override("outline_size", 4)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.anchor_left = 0.5
	notice_label.anchor_right = 0.5
	notice_label.offset_left = -300
	notice_label.offset_right = 300
	notice_label.offset_top = 62
	notice_label.modulate.a = 0.0
	layer.add_child(notice_label)

	var toggle := UIStyle.button("Survivants  [G]", 15)
	toggle.anchor_left = 1.0
	toggle.anchor_right = 1.0
	toggle.offset_left = -170
	toggle.offset_right = -12
	toggle.offset_top = 12
	toggle.offset_bottom = 48
	layer.add_child(toggle)

	panel = ManagementPanel.new()
	panel.targets_provider = get_task_targets
	panel.survivor_selected.connect(_select)
	panel.assignment_requested.connect(assign_survivor)
	panel.squad_toggle_requested.connect(toggle_squad_member)
	toggle.pressed.connect(_toggle_panel)

	var loot_btn := UIStyle.button("Objets  [I]", 15)
	loot_btn.anchor_left = 1.0
	loot_btn.anchor_right = 1.0
	loot_btn.offset_left = -300
	loot_btn.offset_right = -180
	loot_btn.offset_top = 12
	loot_btn.offset_bottom = 48
	layer.add_child(loot_btn)
	loot_panel = LootPanel.new()
	loot_panel.survivors = survivors
	loot_panel.message.connect(_notify)
	loot_btn.pressed.connect(_toggle_loot)

	squad_bar = SquadBar.new()
	squad_bar.member_clicked.connect(_on_squad_member_clicked)
	layer.add_child(squad_bar)
	layer.add_child(panel)  # au-dessus de la barre d'escouade
	layer.add_child(loot_panel)
	loot_panel.setup(stock)

	build_bar = BuildBar.new()
	build_bar.stock = stock
	build_bar.tool_selected.connect(_on_build_tool)
	build_manager.tool_changed.connect(build_bar.show_tool)
	layer.add_child(build_bar)
	var build_btn := UIStyle.button("Construire  [B]", 15)
	build_btn.anchor_left = 1.0
	build_btn.anchor_right = 1.0
	build_btn.anchor_top = 1.0
	build_btn.anchor_bottom = 1.0
	build_btn.offset_left = -232
	build_btn.offset_right = -12
	build_btn.offset_top = -140
	build_btn.offset_bottom = -104
	build_btn.pressed.connect(toggle_build_mode)
	layer.add_child(build_btn)
	alert_button = UIStyle.button("ALERTE  [H]", 15)
	alert_button.anchor_left = 1.0
	alert_button.anchor_right = 1.0
	alert_button.anchor_top = 1.0
	alert_button.anchor_bottom = 1.0
	alert_button.offset_left = -232
	alert_button.offset_right = -12
	alert_button.offset_top = -98
	alert_button.offset_bottom = -62
	alert_button.add_theme_color_override("font_color", Color(1, 0.85, 0.8))
	alert_button.add_theme_stylebox_override("normal", UIStyle.box(Color(0.35, 0.1, 0.08), Color(1, 0.4, 0.3), 8, 2, 6))
	alert_button.pressed.connect(func(): set_alert(not alert_active))
	layer.add_child(alert_button)
	alert_banner = UIStyle.label("⚠ ALERTE — tout le monde défend le camp", 18, Color(1, 0.4, 0.3))
	alert_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	alert_banner.add_theme_constant_override("outline_size", 5)
	alert_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_banner.anchor_left = 0.5
	alert_banner.anchor_right = 0.5
	alert_banner.offset_left = -300
	alert_banner.offset_right = 300
	alert_banner.offset_top = 88
	alert_banner.visible = false
	layer.add_child(alert_banner)

	debug_panel = DebugPanel.new()
	debug_panel.main = self
	layer.add_child(debug_panel)
	var debug_btn := UIStyle.button("Debug  [F1]", 15)
	debug_btn.anchor_left = 1.0
	debug_btn.anchor_right = 1.0
	debug_btn.offset_left = -420
	debug_btn.offset_right = -310
	debug_btn.offset_top = 12
	debug_btn.offset_bottom = 48
	debug_btn.pressed.connect(debug_panel.toggle)
	layer.add_child(debug_btn)

	var help := Label.new()
	help.text = "ZQSD / WASD / flèches : bouger   Souris : viser   Clic gauche : tirer   G : survivants   I : objets   B : construire   H : alerte   F1 : debug   F : escouade   V : formation\nTab ou 1-9 : changer de survivant   Clic droit : sélectionner un survivant, ou l'assigner à un point de récolte (mare, cocotiers, forêt)   Échap : relâcher (caméra libre)"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 12
	help.offset_top = -48
	layer.add_child(help)


func _update_hud() -> void:
	stock_label.text = "Eau  %d/%d     Nourriture  %d/%d     Bois  %d/%d     Objets  %d" % [
		stock.get_amount("eau"), stock.get_capacity("eau"),
		stock.get_amount("nourriture"), stock.get_capacity("nourriture"),
		stock.get_amount("bois"), stock.get_capacity("bois"), stock.items.size()]
	var lines: PackedStringArray = []
	if is_instance_valid(selected):
		var w := selected.weapon
		hud_portrait.visible = true
		hud_portrait.show_survivor(selected)
		lines.append("%s%s" % [selected.full_name(), "  ★" if selected.is_hero else ""])
		var lvl := "PV %d/%d   Niveau %d" % [selected.hp, selected.max_hp, selected.level]
		if selected.stat_points > 0:
			lvl += "   (+%d à attribuer)" % selected.stat_points
		lines.append(lvl)
		lines.append("%s : %.0f × %d dégâts, %.1f tirs/s%s" % [
			w.weapon_name, w.damage, w.bullets_per_shot, w.fire_rate,
			"" if w.element == WeaponData.Element.AUCUN else ", " + WeaponData.element_name(w.element)])
		lines.append("Eau %d %%   Nourriture %d %%%s" % [selected.thirst, selected.hunger,
			"   (ralenti !)" if selected.thirst <= 0.0 or selected.hunger <= 0.0 else ""])
		if not selected.inventory.is_empty():
			lines.append("Sac %d/%d : à rapporter au feu de camp" % [selected.inventory.size(), selected.bag_capacity()])
		if selected.carrying > 0:
			lines.append("Porte %d %s : à déposer au feu de camp" % [selected.carrying, selected.carrying_type])
	else:
		hud_portrait.visible = false
		lines.append("Mode gestion  ·  caméra libre")
		lines.append("ZQSD / WASD / flèches : déplacer la caméra")
		lines.append("Tab, 1-9 ou clic droit : reprendre un survivant")
	hud_label.text = "\n".join(lines)
