extends Node2D
## Scène principale du prototype.
## Monte le monde, les survivants, les cibles, la caméra et le HUD.

const VILLAGE_CENTER := Vector2.ZERO
const START_SURVIVORS := 4

var world: Node2D
var camera: Camera2D
var hud_label: Label
var survivors: Array[Survivor] = []
var selected: Survivor = null


func _enter_tree() -> void:
	_register_inputs()


func _ready() -> void:
	var ground := IsoGround.new()
	ground.z_index = -10
	add_child(ground)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	for i in START_SURVIVORS:
		var s := Survivor.new()
		s.is_hero = (i == 0)
		s.world = world
		s.village_center = VILLAGE_CENTER
		s.position = VILLAGE_CENTER + Vector2(randf_range(-60, 60), randf_range(-30, 30))
		s.died.connect(_on_survivor_died)
		world.add_child(s)
		survivors.append(s)

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


func _register_inputs() -> void:
	# Touches physiques : WASD en QWERTY = ZQSD en AZERTY.
	var map := {
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"next_survivor": [KEY_TAB],
		"deselect": [KEY_ESCAPE],
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
	if event.is_action_pressed("next_survivor"):
		_select_next()
	elif event.is_action_pressed("deselect"):
		_select(null)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_select_under_mouse()
	elif event is InputEventKey and event.pressed and not event.echo:
		var n: int = event.physical_keycode - KEY_1
		if n >= 0 and n < 9 and n < survivors.size():
			_select(survivors[n])


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


func _select_under_mouse() -> void:
	var mouse := get_global_mouse_position()
	for s in survivors:
		if s.global_position.distance_to(mouse + Vector2(0, 12)) < 20.0:
			_select(s)
			return


func _on_survivor_died(s: Survivor) -> void:
	survivors.erase(s)
	if s == selected:
		selected = null
	if survivors.is_empty():
		# Défaite totale : un seul nouveau survivant au centre du village (GDD 11).
		var fresh := Survivor.new()
		fresh.world = world
		fresh.village_center = VILLAGE_CENTER
		fresh.position = VILLAGE_CENTER
		fresh.died.connect(_on_survivor_died)
		world.add_child.call_deferred(fresh)
		survivors.append(fresh)


func _process(_delta: float) -> void:
	if is_instance_valid(selected):
		camera.position = selected.global_position
	_update_hud()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	hud_label = Label.new()
	hud_label.add_theme_font_size_override("font_size", 14)
	panel.add_child(hud_label)

	var help := Label.new()
	help.text = "ZQSD / WASD / flèches : bouger   Souris : viser   Clic gauche : tirer\nTab ou 1-9 : changer de survivant   Clic droit : sélectionner   Échap : relâcher"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_left = 12
	help.offset_top = -48
	layer.add_child(help)


func _update_hud() -> void:
	var lines: PackedStringArray = []
	if is_instance_valid(selected):
		var w := selected.weapon
		lines.append("%s%s" % [selected.full_name(), "  ★ HÉROS" if selected.is_hero else ""])
		lines.append("PV %d/%d   Niveau %d   XP %d" % [selected.hp, selected.max_hp, selected.level, selected.xp])
		lines.append("Arme : %s" % w.weapon_name)
		lines.append("  Dégâts %.0f × %d   Cadence %.1f/s   Dispersion %.0f°   Élément %s" % [
			w.damage, w.bullets_per_shot, w.fire_rate, w.spread_deg, WeaponData.element_name(w.element)])
	else:
		lines.append("Aucun survivant contrôlé")
	lines.append("")
	for i in survivors.size():
		var s := survivors[i]
		lines.append("%d. %s%s — PV %d" % [i + 1, s.full_name(), " ★" if s.is_hero else "", s.hp])
	hud_label.text = "\n".join(lines)
