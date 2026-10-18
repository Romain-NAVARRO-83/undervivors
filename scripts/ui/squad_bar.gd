class_name SquadBar
extends PanelContainer
## Barre d'escouade en bas de l'écran : vignettes numérotées des membres,
## leader mis en évidence, clic pour changer de leader.

signal member_clicked(survivor: Survivor)

var _row: HBoxContainer
var _status: Label
var _slots: Array = []  # [{button, portrait, survivor}]


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 12, 2, 8))
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_top = -150
	offset_bottom = -60
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	add_child(col)
	_status = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_status)
	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 8)
	col.add_child(_row)


func refresh(squad: Array, leader: Survivor, active: bool, formation_name: String) -> void:
	visible = not squad.is_empty()
	if not visible:
		return
	if active:
		_status.text = "ESCOUADE ACTIVE  ·  Formation : %s [V]  ·  F : quitter le mode  ·  Tab / 1-4 : changer de leader" % formation_name
		_status.add_theme_color_override("font_color", UIStyle.ACCENT)
	else:
		_status.text = "Escouade prête (%d/4)  ·  F : passer en mode escouade" % squad.size()
		_status.add_theme_color_override("font_color", UIStyle.TEXT_DIM)
	# Recrée les emplacements si la composition a changé
	var same := _slots.size() == squad.size()
	if same:
		for i in squad.size():
			if _slots[i]["survivor"] != squad[i]:
				same = false
				break
	if not same:
		for slot in _slots:
			slot["button"].queue_free()
		_slots.clear()
		for i in squad.size():
			_slots.append(_make_slot(squad[i], i))
	for slot in _slots:
		var s: Survivor = slot["survivor"]
		var is_leader: bool = active and s == leader
		var btn: Button = slot["button"]
		var border := UIStyle.ACCENT if is_leader else UIStyle.BORDER
		btn.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.TILE, border, 10, 3 if is_leader else 2, 4))
		btn.modulate.a = 1.0 if active else 0.75
		if is_instance_valid(s):
			(slot["portrait"] as SurvivorPortrait).show_survivor(s)
		(slot["hp"] as ProgressBar).value = float(s.hp) / s.max_hp * 100.0 if is_instance_valid(s) else 0.0


func _make_slot(s: Survivor, index: int) -> Dictionary:
	var btn := UIStyle.button("", 12)
	btn.custom_minimum_size = Vector2(64, 70)
	btn.tooltip_text = s.full_name()
	btn.pressed.connect(func(): member_clicked.emit(s))
	_row.add_child(btn)
	var portrait := SurvivorPortrait.new()
	portrait.appearance = s.appearance
	portrait.is_hero = s.is_hero
	portrait.position = Vector2(8, 4)
	portrait.size = Vector2(48, 48)
	btn.add_child(portrait)
	var num := UIStyle.label(str(index + 1), 12, UIStyle.TEXT)
	num.position = Vector2(4, 0)
	btn.add_child(num)
	var hp := ProgressBar.new()
	hp.show_percentage = false
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.position = Vector2(8, 56)
	hp.size = Vector2(48, 6)
	hp.add_theme_stylebox_override("background", UIStyle.box(UIStyle.BAR_BG, UIStyle.BAR_BG, 3, 0, 0))
	hp.add_theme_stylebox_override("fill", UIStyle.box(UIStyle.BAR_COLORS["pv"], UIStyle.BAR_COLORS["pv"], 3, 0, 0))
	btn.add_child(hp)
	return {"button": btn, "portrait": portrait, "survivor": s, "hp": hp}
