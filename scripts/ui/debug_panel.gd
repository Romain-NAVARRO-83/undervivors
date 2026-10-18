class_name DebugPanel
extends PanelContainer
## Panneau de contrôle debug (F1) : vagues, survivants, stock, monde.
## Outil de développement : à retirer ou masquer dans la version finale.

var main: Node  # scène principale (main.gd)

var _count: SpinBox
var _dir: OptionButton
var _auto: CheckBox
var _info: Label
var _speed_label: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIStyle.box(Color(0.08, 0.1, 0.12, 0.95), Color(0.3, 0.55, 0.7), 12, 2, 12))
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 12
	offset_top = 112
	custom_minimum_size = Vector2(300, 0)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	add_child(root)
	var title := UIStyle.label("DEBUG  ·  F1 pour fermer", 15, Color(0.5, 0.8, 1.0))
	root.add_child(title)
	_info = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	root.add_child(_info)

	_section(root, "Vagues")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	root.add_child(row)
	row.add_child(UIStyle.label("Monstres", 12, UIStyle.TEXT_DIM))
	_count = SpinBox.new()
	_count.min_value = 1
	_count.max_value = 30
	_count.value = 5
	_count.focus_mode = Control.FOCUS_NONE
	_count.get_line_edit().focus_mode = Control.FOCUS_CLICK
	row.add_child(_count)
	_dir = OptionButton.new()
	_dir.focus_mode = Control.FOCUS_NONE
	for d in ["Aléatoire", "Nord", "Est", "Sud", "Ouest"]:
		_dir.add_item(d)
	row.add_child(_dir)
	var wrow := _grid(root)
	_button(wrow, "Lancer une vague", func():
		main.wave_manager.spawn_wave(int(_count.value), _dir.get_item_text(_dir.selected)))
	_button(wrow, "Tuer les monstres", func(): main.wave_manager.kill_all())
	_auto = CheckBox.new()
	_auto.text = "Vagues automatiques (toutes les 30 s)"
	_auto.focus_mode = Control.FOCUS_NONE
	_auto.add_theme_font_size_override("font_size", 12)
	_auto.toggled.connect(func(on): main.wave_manager.set_auto(on))
	root.add_child(_auto)

	_section(root, "Survivants")
	var g := _grid(root)
	_button(g, "Recruter", func(): main.debug_recruit())
	_button(g, "+100 XP (contrôlé)", func(): main.debug_give_xp(100))
	_button(g, "Soigner, rassasier", func(): main.debug_heal_all())
	_button(g, "Affamer tous (F10)", func(): main.debug_starve_all())

	_section(root, "Stock")
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 6)
	root.add_child(srow)
	_button(srow, "+10 eau", func(): main.stock.add("eau", 10))
	_button(srow, "+10 nourriture", func(): main.stock.add("nourriture", 10))
	_button(srow, "+1 arme", func(): main.debug_add_random_weapon())

	_section(root, "Monde")
	_button(root, "Faire réapparaître les coffres", func(): main.respawn_chests())
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 6)
	root.add_child(trow)
	_speed_label = UIStyle.label("Vitesse du jeu", 12, UIStyle.TEXT_DIM)
	trow.add_child(_speed_label)
	for k in [1.0, 2.0, 4.0]:
		_button(trow, "×%d" % int(k), func(): Engine.time_scale = k)


func toggle() -> void:
	visible = not visible


func _grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	parent.add_child(g)
	return g


func _section(parent: Control, text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	parent.add_child(UIStyle.label(text, 13, UIStyle.ACCENT))


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := UIStyle.button(text, 12)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _process(_delta: float) -> void:
	if not visible or main == null:
		return
	var wm: WaveManager = main.wave_manager
	var t := "Vague n°%d  ·  monstres en vie : %d" % [wm.wave_number, wm.alive_count()]
	if wm.auto_waves:
		t += "\nProchaine vague auto dans %d s" % ceili(wm.time_to_next_auto_wave())
	t += "\nFPS %d  ·  vitesse ×%d" % [Engine.get_frames_per_second(), int(Engine.time_scale)]
	_info.text = t
