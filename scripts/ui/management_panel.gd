class_name ManagementPanel
extends PanelContainer
## Panneau de gestion des survivants (GDD 12) : une tuile par survivant.
## Le jeu continue pendant qu'il est ouvert (pas de pause, GDD 4.2).

signal survivor_selected(survivor: Survivor)
signal assignment_requested(survivor: Survivor, node: ResourceNode)
signal squad_toggle_requested(survivor: Survivor)

## Points de récolte proposés dans le menu « Tâche » des tuiles.
var resource_nodes: Array = []

var _grid: GridContainer
var _title: Label
var _tiles := {}  # Survivor -> SurvivorTile


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 14, 2, 16))
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -480
	offset_right = 480
	offset_top = -250
	offset_bottom = 300

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title = UIStyle.label("Survivants", 22, UIStyle.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var hint := UIStyle.label("Clic sur une tuile : contrôler   ·   G : fermer", 12, UIStyle.TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(hint)
	var close := UIStyle.button("✕", 14)
	close.custom_minimum_size = Vector2(32, 28)
	close.pressed.connect(func(): visible = false)
	header.add_child(close)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)


func toggle() -> void:
	visible = not visible


## Ajoute les tuiles des nouveaux survivants et retire celles des morts.
func sync(survivors: Array) -> void:
	for s in _tiles.keys():
		if not is_instance_valid(s) or not survivors.has(s):
			_tiles[s].queue_free()
			_tiles.erase(s)
	for s in survivors:
		if not _tiles.has(s) and is_instance_valid(s) and s.is_inside_tree():
			var tile := SurvivorTile.new().setup(s, resource_nodes)
			tile.select_requested.connect(func(sv): survivor_selected.emit(sv))
			tile.assignment_requested.connect(func(sv, node): assignment_requested.emit(sv, node))
			tile.squad_toggle_requested.connect(func(sv): squad_toggle_requested.emit(sv))
			_grid.add_child(tile)
			_tiles[s] = tile
	_title.text = "Survivants (%d)" % survivors.size()


func _process(_delta: float) -> void:
	if not visible:
		return
	for tile in _tiles.values():
		tile.refresh()
