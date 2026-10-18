extends Node2D
## Scène principale du prototype.
## Monte le monde, les survivants, les cibles, la mare, le stock, la caméra et le HUD.

const VILLAGE_CENTER := Vector2.ZERO
const START_SURVIVORS := 4

var world: Node2D
var camera: Camera2D
var stock: VillageStock
var hud_label: Label
var hud_portrait: SurvivorPortrait
var stock_label: Label
var notice_label: Label
var panel: ManagementPanel
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

	# Point de récolte d'eau
	var pond := ResourceNode.new()
	pond.name = "Mare"
	pond.position = Vector2(230, 150)
	world.add_child(pond)
	resource_nodes.append(pond)

	for i in START_SURVIVORS:
		_spawn_survivor(VILLAGE_CENTER + Vector2(randf_range(-60, 60), randf_range(-30, 30)), i == 0)

	for pos in [Vector2(320, -60), Vector2(380, 40), Vector2(-340, 20), Vector2(-260, -120), Vector2(60, -260)]:
		var d := TargetDummy.new()
		d.position = pos
		world.add_child(d)

	var pickup := WeaponPickup.new()
	pickup.weapon = load("res://data/weapons/shotgun.tres")
	pickup.position = Vector2(-160, 160)
	world.add_child(pickup)

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
		panel.toggle()
	elif event.is_action_pressed("next_survivor"):
		_select_next()
	elif event.is_action_pressed("deselect"):
		if panel.visible:
			panel.visible = false
		else:
			_select(null)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < 9 and n < survivors.size():
			_select(survivors[n])


## Clic droit : sélectionner le survivant sous la souris, sinon assigner
## le survivant contrôlé au point de récolte survolé.
func _on_right_click() -> void:
	var mouse := get_global_mouse_position()
	for s in survivors:
		if s.global_position.distance_to(mouse + Vector2(0, 12)) < 20.0:
			_select(s)
			return
	for node in resource_nodes:
		if node.contains(mouse):
			if is_instance_valid(selected):
				assign_survivor(selected, node)
			else:
				_notify("Sélectionne d'abord un survivant à assigner")
			return


## Assigne un survivant à un point de récolte (null = libérer).
## S'il était contrôlé, on passe au premier survivant libre.
func assign_survivor(s: Survivor, node: ResourceNode) -> void:
	s.assign(node)
	if node:
		_notify("%s est assigné·e à : %s" % [s.first_name, node.display_name])
		if s == selected:
			var next: Survivor = null
			for other in survivors:
				if other.task_node == null and other != s:
					next = other
					break
			_select(next)
	else:
		_notify("%s est libéré·e" % s.first_name)


func _select(s: Survivor) -> void:
	if is_instance_valid(selected):
		selected.selected = false
	selected = s
	if is_instance_valid(selected):
		selected.selected = true


func _select_next() -> void:
	if survivors.is_empty():
		return
	var idx := survivors.find(selected)
	_select(survivors[(idx + 1) % survivors.size()])


func _on_survivor_died(s: Survivor) -> void:
	survivors.erase(s)
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


func _process(_delta: float) -> void:
	if is_instance_valid(selected):
		camera.position = selected.global_position
	panel.sync(survivors)
	_update_hud()


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
	stock_box.offset_left = -110
	stock_box.offset_right = 110
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
	panel.resource_nodes = resource_nodes
	panel.survivor_selected.connect(_select)
	panel.assignment_requested.connect(assign_survivor)
	layer.add_child(panel)
	toggle.pressed.connect(panel.toggle)

	var help := Label.new()
	help.text = "ZQSD / WASD / flèches : bouger   Souris : viser   Clic gauche : tirer   G : panneau des survivants\nTab ou 1-9 : changer de survivant   Clic droit : sélectionner un survivant, ou assigner le survivant contrôlé à la mare   Échap : relâcher"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 12
	help.offset_top = -48
	layer.add_child(help)


func _update_hud() -> void:
	stock_label.text = "Eau  %d     Nourriture  %d" % [stock.get_amount("eau"), stock.get_amount("nourriture")]
	var lines: PackedStringArray = []
	if is_instance_valid(selected):
		var w := selected.weapon
		hud_portrait.visible = true
		hud_portrait.appearance = selected.appearance
		hud_portrait.is_hero = selected.is_hero
		lines.append("%s%s" % [selected.full_name(), "  ★" if selected.is_hero else ""])
		var lvl := "PV %d/%d   Niveau %d" % [selected.hp, selected.max_hp, selected.level]
		if selected.stat_points > 0:
			lvl += "   (+%d à attribuer)" % selected.stat_points
		lines.append(lvl)
		lines.append("%s : %.0f × %d dégâts, %.1f tirs/s%s" % [
			w.weapon_name, w.damage, w.bullets_per_shot, w.fire_rate,
			"" if w.element == WeaponData.Element.AUCUN else ", " + WeaponData.element_name(w.element)])
		if selected.carrying > 0:
			lines.append("Porte %d %s : à déposer au feu de camp" % [selected.carrying, selected.carrying_type])
	else:
		hud_portrait.visible = false
		lines.append("Aucun survivant contrôlé")
	hud_label.text = "\n".join(lines)
