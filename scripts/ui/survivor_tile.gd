class_name SurvivorTile
extends PanelContainer
## Tuile d'un survivant dans le panneau de gestion : vignette, nom, niveau,
## stats en barres de progression, points à attribuer et équipement.

signal select_requested(survivor: Survivor)
signal assignment_requested(survivor: Survivor, node: ResourceNode)
signal squad_toggle_requested(survivor: Survivor)

const SQUAD_MAX := 4

const ROWS := [
	# [clé de barre, libellé, stat à augmenter avec « + » (vide = aucun)]
	["pv", "PV", "pv_max"],
	["vitesse", "Vitesse", "vitesse"],
	["precision", "Précision", "precision"],
	["force", "Force", "force"],
	["xp", "XP", ""],
]

var survivor: Survivor
var resource_nodes: Array = []

var _portrait: SurvivorPortrait
var _activity: Label
var _task: OptionButton
var _squad_btn: Button
var _name: Label
var _level: Label
var _weapon: Label
var _bars := {}
var _values := {}
var _plus := {}
var _hover := false
var _style_normal: StyleBoxFlat
var _style_hover: StyleBoxFlat
var _style_selected: StyleBoxFlat


func setup(s: Survivor, nodes: Array = []) -> SurvivorTile:
	survivor = s
	resource_nodes = nodes
	return self


func _ready() -> void:
	custom_minimum_size = Vector2(290, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style_normal = UIStyle.box(UIStyle.TILE)
	_style_hover = UIStyle.box(UIStyle.TILE_HOVER)
	_style_selected = UIStyle.box(UIStyle.TILE_HOVER, Color(1, 1, 1, 0.85), 10, 3)
	add_theme_stylebox_override("panel", _style_normal)
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# En-tête : vignette + nom + niveau
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override("separation", 10)
	root.add_child(head)
	_portrait = SurvivorPortrait.new()
	_portrait.custom_minimum_size = Vector2(72, 72)
	_portrait.appearance = survivor.appearance
	_portrait.is_hero = survivor.is_hero
	head.add_child(_portrait)
	var titles := VBoxContainer.new()
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(titles)
	_name = UIStyle.label("", 15)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titles.add_child(_name)
	_level = UIStyle.label("", 13, UIStyle.TEXT_DIM)
	titles.add_child(_level)
	_squad_btn = UIStyle.button("", 12)
	_squad_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_squad_btn.pressed.connect(func(): squad_toggle_requested.emit(survivor))
	titles.add_child(_squad_btn)

	# Barres de stats
	var grid := GridContainer.new()
	grid.columns = 3
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	root.add_child(grid)
	for row in ROWS:
		var key: String = row[0]
		var name_label := UIStyle.label(row[1], 12, UIStyle.TEXT_DIM)
		name_label.custom_minimum_size = Vector2(64, 0)
		grid.add_child(name_label)
		grid.add_child(_make_bar(key))
		var plus := UIStyle.button("+", 12)
		plus.custom_minimum_size = Vector2(26, 20)
		for st in ["normal", "hover", "pressed", "disabled"]:
			var sb: StyleBoxFlat = UIStyle.box(UIStyle.TILE, UIStyle.ACCENT if st == "hover" else UIStyle.BORDER, 6, 2, 0)
			plus.add_theme_stylebox_override(st, sb)
		plus.tooltip_text = "Attribuer un point"
		var stat: String = row[2]
		if stat.is_empty():
			plus.modulate.a = 0.0
			plus.disabled = true
			plus.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			plus.pressed.connect(func(): survivor.spend_point(stat))
			_plus[key] = plus
		grid.add_child(plus)

	_weapon = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	root.add_child(_weapon)

	# Tâche : errance ou récolte sur un point
	var task_row := HBoxContainer.new()
	task_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	task_row.add_theme_constant_override("separation", 8)
	root.add_child(task_row)
	task_row.add_child(UIStyle.label("Tâche", 12, UIStyle.TEXT_DIM))
	_task = OptionButton.new()
	_task.focus_mode = Control.FOCUS_NONE
	_task.add_theme_font_size_override("font_size", 12)
	_task.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.BAR_BG, UIStyle.BORDER, 6, 1, 4))
	_task.add_theme_stylebox_override("hover", UIStyle.box(UIStyle.BAR_BG, UIStyle.ACCENT, 6, 1, 4))
	_task.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_task.add_item("Aucune (errance)", 0)
	for i in resource_nodes.size():
		var node: ResourceNode = resource_nodes[i]
		_task.add_item("Récolte : %s (%s)" % [node.display_name, node.resource_type], i + 1)
	_task.item_selected.connect(_on_task_selected)
	task_row.add_child(_task)
	_activity = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	root.add_child(_activity)
	refresh()


func _on_task_selected(index: int) -> void:
	var node: ResourceNode = null if index == 0 else resource_nodes[index - 1]
	assignment_requested.emit(survivor, node)


func _make_bar(key: String) -> Control:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(150, 18)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := UIStyle.box(UIStyle.BAR_BG, UIStyle.BAR_BG, 5, 0, 0)
	var fill := UIStyle.box(UIStyle.BAR_COLORS[key], UIStyle.BAR_COLORS[key], 5, 0, 0)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	var value := UIStyle.label("", 11)
	value.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	value.add_theme_constant_override("outline_size", 3)
	bar.add_child(value)
	_bars[key] = bar
	_values[key] = value
	return bar


func refresh() -> void:
	if not is_instance_valid(survivor):
		return
	var s := survivor
	_name.text = s.full_name() + ("  ★" if s.is_hero else "")
	var lvl := "Niveau %d" % s.level
	if s.stat_points > 0:
		lvl += "  —  %d point%s à attribuer" % [s.stat_points, "s" if s.stat_points > 1 else ""]
		_level.add_theme_color_override("font_color", UIStyle.ACCENT)
	else:
		_level.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	_level.text = lvl
	_set_bar("pv", s.hp, s.max_hp, "%d / %d" % [s.hp, s.max_hp])
	_set_bar("vitesse", s.speed_stat, Survivor.STAT_MAX, str(s.speed_stat))
	_set_bar("precision", s.accuracy, Survivor.STAT_MAX, str(s.accuracy))
	_set_bar("force", s.strength, Survivor.STAT_MAX, str(s.strength))
	_set_bar("xp", s.xp_in_level(), Survivor.XP_PER_LEVEL, "%d / %d" % [s.xp_in_level(), Survivor.XP_PER_LEVEL])
	for key in _plus:
		# On masque sans retirer du GridContainer (sinon les colonnes se décalent).
		var b: Button = _plus[key]
		var on := s.stat_points > 0
		b.modulate.a = 1.0 if on else 0.0
		b.disabled = not on
		b.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_weapon.text = "Arme : %s" % (s.weapon.weapon_name if s.weapon else "—")
	var wanted := 0 if s.task_node == null else resource_nodes.find(s.task_node) + 1
	if _task.selected != wanted:
		_task.select(wanted)
	_activity.text = "→ " + s.activity_text()
	var squad_count := get_tree().get_nodes_in_group("squad").size()
	if s.squad_member:
		_squad_btn.text = "✓ Escouade n°%d  (retirer)" % (s.squad_index + 1)
		_squad_btn.disabled = false
		_squad_btn.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	else:
		var full := squad_count >= SQUAD_MAX
		_squad_btn.text = "Escouade complète (4/4)" if full else "+ Ajouter à l'escouade (%d/4)" % squad_count
		_squad_btn.disabled = full
		_squad_btn.add_theme_color_override("font_color", UIStyle.TEXT)
	var style := _style_selected if s.selected else (_style_hover if _hover else _style_normal)
	add_theme_stylebox_override("panel", style)


func _set_bar(key: String, value: float, max_value: float, text: String) -> void:
	var bar: ProgressBar = _bars[key]
	bar.max_value = max_value
	bar.value = value
	(_values[key] as Label).text = text


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_requested.emit(survivor)
		accept_event()
