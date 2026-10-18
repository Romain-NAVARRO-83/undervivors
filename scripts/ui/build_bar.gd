class_name BuildBar
extends PanelContainer
## Barre de construction (B) : choix de l'outil, coût, bois disponible.

signal tool_selected(tool: String)

var stock: VillageStock
var _buttons := {}
var _info: Label
var _current := ""


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.ACCENT, 12, 2, 10))
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -232
	offset_right = -12
	offset_top = -330
	offset_bottom = -150
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	add_child(col)
	col.add_child(UIStyle.label("CONSTRUIRE  ·  B pour fermer", 13, UIStyle.ACCENT))
	_info = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	col.add_child(_info)
	for key in BuildManager.TOOLS:
		var t: Dictionary = BuildManager.TOOLS[key]
		var b := UIStyle.button("%s  —  %d bois" % [t["name"], t["cost"]], 13)
		b.pressed.connect(func(): tool_selected.emit("" if _current == key else key))
		col.add_child(b)
		_buttons[key] = b
	var hint := UIStyle.label("Clic : poser · maintenir (mur) : ligne\nClic droit / Échap : annuler", 11, UIStyle.TEXT_DIM)
	col.add_child(hint)


func show_tool(tool: String) -> void:
	_current = tool
	for key in _buttons:
		var b: Button = _buttons[key]
		var on: bool = key == tool
		b.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.TILE_HOVER if on else UIStyle.TILE, UIStyle.ACCENT if on else UIStyle.BORDER, 8, 2, 6))


func _process(_delta: float) -> void:
	if visible and stock:
		_info.text = "Bois disponible : %d" % stock.get_amount("bois")
