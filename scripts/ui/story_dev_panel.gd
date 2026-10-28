class_name StoryDevPanel
extends PanelContainer
## Panneau développeur du mode histoire (F1) : temps, survivants, stock,
## monstres et déroulé des chapitres. Outil de développement : à retirer ou
## masquer dans la version finale.

const WEAPON_DIR := "res://data/weapons/"
const Story := preload("res://scripts/story/prologue.gd")

var story: Node   # la scène du mode histoire (prologue.gd)

var _info: Label
var _invincible: CheckBox
var _harmless: CheckBox
var _weapon: OptionButton
var _weapons: Array[WeaponData] = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIStyle.box(Color(0.08, 0.1, 0.12, 0.95), Color(0.3, 0.55, 0.7), 12, 2, 12))
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -332
	offset_right = -12
	offset_top = 56
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)
	root.add_child(UIStyle.label("DÉVELOPPEUR  ·  F1 pour fermer", 15, Color(0.5, 0.8, 1.0)))
	_info = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_info)

	_section(root, "Temps")
	var g := _grid(root)
	_button(g, "+1 h", func(): _dn().set_hour(_dn().hour + 1.0))
	_button(g, "+6 h", func(): _dn().set_hour(_dn().hour + 6.0))
	_button(g, "Aube (6 h)", func(): _dn().set_hour(DayNight.DAWN))
	_button(g, "Midi", func(): _dn().set_hour(12.0))
	_button(g, "Crépuscule (20 h 30)", func(): _dn().set_hour(DayNight.DUSK - 0.5))
	_button(g, "Minuit", func(): _dn().set_hour(0.0))
	var sp := _grid(root, 4)
	for v in [0.0, 1.0, 4.0, 16.0]:
		_button(sp, "Pause" if v == 0.0 else "×%d" % int(v), func(): _dn().speed = v)

	_section(root, "Survivant dirigé")
	g = _grid(root)
	_button(g, "Soigner", func(): _each(func(s): s.hp = s.max_hp, true))
	_button(g, "Eau et faim pleines", func(): _each(_feed, true))
	_button(g, "Assoiffé et affamé", func(): _each(_starve, true))
	_button(g, "+100 XP", func(): _each(func(s): s.add_xp(100), true))
	_button(g, "Au refuge", func(): _each(func(s): s.global_position = story.REFUGE_POS + Vector2(40, 30), true))
	_button(g, "Blesser (−30 PV)", func(): _each(func(s): s.take_damage(30.0), true))
	var wrow := HBoxContainer.new()
	root.add_child(wrow)
	_weapon = OptionButton.new()
	_weapon.focus_mode = Control.FOCUS_NONE
	_weapon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_weapon.add_theme_font_size_override("font_size", 12)
	for f in DirAccess.get_files_at(WEAPON_DIR):
		var w := load(WEAPON_DIR + f.trim_suffix(".remap")) as WeaponData
		if w and not _weapons.has(w):
			_weapons.append(w)
			_weapon.add_item(w.weapon_name)
	wrow.add_child(_weapon)
	_button(wrow, "Équiper", func():
		if _weapon.selected >= 0:
			_each(func(s): s.equip(_weapons[_weapon.selected]), true))
	_invincible = _check(root, "Invincibles (tous les survivants)", func(on):
		for s in story.alive_survivors():
			s.hp_floor = 1 if on else 0)

	_section(root, "Tous les survivants")
	g = _grid(root)
	_button(g, "Soigner tout le monde", func(): _each(func(s): s.hp = s.max_hp, false))
	_button(g, "Nourrir tout le monde", func(): _each(_feed, false))

	_section(root, "Stock du refuge")
	g = _grid(root, 3)
	_button(g, "+3 eau", func(): story.stock.add("eau", 3))
	_button(g, "+3 nourriture", func(): story.stock.add("nourriture", 3))
	_button(g, "+8 bois", func(): story.stock.add("bois", 8))
	_button(g, "Vider", func():
		for k in ["eau", "nourriture", "bois"]:
			story.stock.take(k, 999))

	_section(root, "Monstres")
	_harmless = _check(root, "Inoffensifs", func(on): Mob.harmless = on)
	g = _grid(root)
	_button(g, "Tuer les proches (400 px)", func(): _kill_mobs(400.0))
	_button(g, "Tuer tous les monstres", func(): _kill_mobs(INF))

	_section(root, "Déroulé")
	g = _grid(root)
	_button(g, "Étape suivante", _next_step)
	_button(g, "Aller au chapitre 1", func():
		if story.chapter == null:
			Story.start_chapter = 1
			get_tree().reload_current_scene())
	_button(g, "Finir la cabane", func():
		var ch = story.chapter
		if ch == null:
			return
		if ch.cabin == null:
			story.stock.add("bois", Chapter1.WOOD_NEEDED)
			ch._advance(Chapter1.Step.BUILD)
			story.controlled.global_position = ch.plot_position() + Vector2(60, 40)
			ch.try_build()
		if ch.cabin:
			ch.cabin.finish())
	_button(g, "Révéler l'objectif", func():
		if story.chapter:
			story.chapter._since_pickup = Chapter1.HINT_DELAY)


func toggle() -> void:
	visible = not visible


func _feed(s: Survivor) -> void:
	s.thirst = Survivor.NEED_MAX
	s.hunger = Survivor.NEED_MAX


func _starve(s: Survivor) -> void:
	s.thirst = 15.0
	s.hunger = 15.0


func _dn() -> DayNight:
	return story.day_night


## Applique `fn` au survivant dirigé (only_controlled) ou à tous.
func _each(fn: Callable, only_controlled: bool) -> void:
	if only_controlled:
		if is_instance_valid(story.controlled):
			fn.call(story.controlled)
		return
	for s in story.alive_survivors():
		fn.call(s)


func _kill_mobs(radius: float) -> void:
	var c: Vector2 = story.camera.position
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.is_alive() and m.global_position.distance_to(c) <= radius:
			m.take_damage(99999.0)


## Passe l'étape en cours du prologue ou du chapitre 1 (téléporte au besoin).
func _next_step() -> void:
	var ch = story.chapter
	if ch == null:
		match story.step:
			Story.Step.WAKE, Story.Step.MOVE:
				story._advance(Story.Step.FOLLOW_BUTTE)
			Story.Step.FOLLOW_BUTTE:
				story.survivor.global_position = story.FRIEND_POS + Vector2(-60, 40)
			Story.Step.MEET, Story.Step.TO_REFUGE:
				story.survivor.global_position = story.REFUGE_POS + Vector2(60, 40)
				story.friend.global_position = story.REFUGE_POS + Vector2(90, 50)
			Story.Step.REFUGE:
				story._advance(Story.Step.FIND_WATER)
			Story.Step.FIND_WATER:
				for w in story.water_items:
					if is_instance_valid(w):
						story.survivor.try_pick_up(w.item)
						w.queue_free()
			Story.Step.BRING_WATER:
				story.survivor.global_position = story.REFUGE_POS + Vector2(8, 4)
			Story.Step.FRIEND_DRINKS:
				story._advance(Story.Step.SWITCH)
			Story.Step.SWITCH:
				story.switch_survivor()
		return
	match ch.step:
		Chapter1.Step.INTRO:
			ch._advance(Chapter1.Step.FIND_WEAPON)
		Chapter1.Step.FIND_WEAPON:
			if is_instance_valid(story.controlled):
				story.controlled.equip(load(Survivor.SLINGSHOT_PATH))
		Chapter1.Step.FIRST_FIGHT:
			if is_instance_valid(ch.first_mob):
				ch.first_mob.take_damage(99999.0)
		Chapter1.Step.SUPPLIES:
			story.stock.add("bois", Chapter1.WOOD_NEEDED)
			story.stock.add("nourriture", Chapter1.FOOD_NEEDED)
			ch._food_base -= Chapter1.FOOD_NEEDED
		Chapter1.Step.BUILD, Chapter1.Step.BUILDING:
			if ch.cabin == null and is_instance_valid(story.controlled):
				story.controlled.global_position = ch.plot_position() + Vector2(60, 40)
				ch.try_build()
			if ch.cabin:
				ch.cabin.finish()


func _process(_d: float) -> void:
	if not visible or story == null:
		return
	_harmless.set_pressed_no_signal(Mob.harmless)
	var mobs := 0
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.is_alive():
			mobs += 1
	var step_name: String
	if story.chapter:
		step_name = "Chapitre 1 · " + Chapter1.Step.keys()[story.chapter.step]
	else:
		step_name = "Prologue · " + Story.Step.keys()[story.step]
	_info.text = "%s\n%s · vitesse ×%s\nMonstres : %d · FPS %d" % [
		step_name, _dn().clock_text(), str(_dn().speed), mobs, Engine.get_frames_per_second()]


# --- Construction de l'interface -------------------------------------------

func _section(parent: Control, text: String) -> void:
	parent.add_child(HSeparator.new())
	parent.add_child(UIStyle.label(text, 13, UIStyle.ACCENT))


func _grid(parent: Control, cols := 2) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 4)
	g.add_theme_constant_override("v_separation", 4)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	return g


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := UIStyle.button(text, 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _check(parent: Control, text: String, on_toggle: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.focus_mode = Control.FOCUS_NONE
	c.add_theme_font_size_override("font_size", 12)
	c.toggled.connect(on_toggle)
	parent.add_child(c)
	return c
