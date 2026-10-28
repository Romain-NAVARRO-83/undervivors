class_name TopBar
extends Control
## Barre du haut (mode histoire) : le cadran du temps au centre, et de part et
## d'autre les stocks du refuge (eau, nourriture, bois) avec leur capacité.
## Un stock vide passe au rouge, un stock plein au vert.

var stock: VillageStock
var dial: DayDial
var _slots := {}   # ressource -> Label

const ORDER := ["eau", "nourriture", "bois"]


func setup(day_night: DayNight, village_stock: VillageStock) -> void:
	stock = village_stock
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -260
	offset_right = 260
	offset_top = 6
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	row.add_child(_make_slot("eau"))
	row.add_child(_make_slot("nourriture"))
	dial = DayDial.new()
	dial.day_night = day_night
	row.add_child(dial)
	row.add_child(_make_slot("bois"))


func _make_slot(kind: String) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 8, 2, 6))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	panel.add_child(h)
	var icon := Icon.new()
	icon.kind = kind
	icon.custom_minimum_size = Vector2(22, 22)
	h.add_child(icon)
	var l := UIStyle.label("", 14)
	l.custom_minimum_size = Vector2(46, 0)
	h.add_child(l)
	_slots[kind] = l
	panel.tooltip_text = VillageStock.LABELS.get(kind, kind)
	return panel


func _process(_d: float) -> void:
	if stock == null:
		return
	for kind in _slots:
		var n := stock.get_amount(kind)
		var cap := stock.get_capacity(kind)
		var l: Label = _slots[kind]
		l.text = "%d/%d" % [n, cap]
		var col := UIStyle.TEXT
		if n == 0:
			col = Color(0.95, 0.45, 0.4)
		elif n >= cap:
			col = Color(0.55, 0.9, 0.5)
		l.add_theme_color_override("font_color", col)


class Icon:
	extends Control
	var kind := ""

	func _draw() -> void:
		ItemIcon.draw_resource(self, kind, size / 2.0, 1.1)
