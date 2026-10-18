class_name LootPanel
extends PanelContainer
## Gestion du loot commun (GDD 12) : les armes rapportées au village, à gauche ;
## les survivants, à droite. On choisit une arme puis « Équiper » sur un
## survivant ; son ancienne arme retourne au stock. « Ranger » rend l'arme au
## stock et redonne le lance-pierre. Le jeu continue derrière (pas de pause).

signal message(text: String)

var stock: VillageStock
var survivors: Array = []

var _items_box: VBoxContainer
var _surv_box: VBoxContainer
var _title: Label
var _detail: Label
var _selected: Resource = null
var _dirty := true
var _last_survivor_count := -1


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
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	var header := HBoxContainer.new()
	root.add_child(header)
	_title = UIStyle.label("Stock d'objets", 22, UIStyle.ACCENT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var hint := UIStyle.label("Choisis une arme, puis « Équiper » sur un survivant   ·   I : fermer", 12, UIStyle.TEXT_DIM)
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(hint)
	var close := UIStyle.button("✕", 14)
	close.custom_minimum_size = Vector2(32, 28)
	close.pressed.connect(func(): visible = false)
	header.add_child(close)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)

	# Colonne gauche : armes en stock
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	left.add_theme_constant_override("separation", 6)
	cols.add_child(left)
	left.add_child(UIStyle.label("Armes au village", 15, UIStyle.TEXT))
	var lscroll := ScrollContainer.new()
	lscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(lscroll)
	_items_box = VBoxContainer.new()
	_items_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_box.add_theme_constant_override("separation", 6)
	lscroll.add_child(_items_box)
	_detail = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(_detail)

	# Colonne droite : survivants
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	cols.add_child(right)
	right.add_child(UIStyle.label("Survivants", 15, UIStyle.TEXT))
	var rscroll := ScrollContainer.new()
	rscroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(rscroll)
	_surv_box = VBoxContainer.new()
	_surv_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surv_box.add_theme_constant_override("separation", 6)
	rscroll.add_child(_surv_box)


func setup(village_stock: VillageStock) -> void:
	stock = village_stock
	stock.items_changed.connect(func(): _dirty = true)


func toggle() -> void:
	visible = not visible
	_dirty = true


func _process(_delta: float) -> void:
	if not visible:
		return
	if survivors.size() != _last_survivor_count:
		_dirty = true
	if _dirty:
		_rebuild()


## Sélectionne une arme du stock (null pour désélectionner).
func select_item(item: Resource) -> void:
	_selected = item
	_dirty = true


func equip(s: Survivor) -> void:
	if _selected == null or not is_instance_valid(s):
		return
	var item := _selected
	if s.equip_from_stock(item):
		message.emit("%s s'équipe : %s" % [s.first_name, LootTable.item_name(item)])
	if stock.count_item(item) == 0:
		_selected = null
	_dirty = true


func unequip(s: Survivor) -> void:
	var name := LootTable.item_name(s.weapon)
	if s.unequip_to_stock():
		message.emit("%s range : %s" % [s.first_name, name])
	_dirty = true


func _rebuild() -> void:
	_dirty = false
	_last_survivor_count = survivors.size()
	for c in _items_box.get_children():
		c.queue_free()
	for c in _surv_box.get_children():
		c.queue_free()
	if stock == null:
		return
	_title.text = "Stock d'objets (%d)" % stock.items.size()

	var distinct := stock.distinct_items()
	if _selected != null and not distinct.has(_selected):
		_selected = null
	if distinct.is_empty():
		var empty := UIStyle.label("Rien pour l'instant. Casse des coffres et rapporte le butin au feu de camp.", 13, UIStyle.TEXT_DIM)
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_items_box.add_child(empty)
	for item in distinct:
		_items_box.add_child(_item_card(item))

	if _selected is WeaponData:
		var w: WeaponData = _selected
		_detail.text = "Sélection : %s — %s" % [w.weapon_name, _weapon_stats(w)]
	else:
		_detail.text = "Aucune arme sélectionnée."

	for s in survivors:
		if is_instance_valid(s):
			_surv_box.add_child(_survivor_row(s))


func _item_card(item: Resource) -> Control:
	var btn := UIStyle.button("", 13)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 46)
	var is_sel := item == _selected
	btn.add_theme_stylebox_override("normal", UIStyle.box(UIStyle.TILE_HOVER if is_sel else UIStyle.TILE, UIStyle.ACCENT if is_sel else UIStyle.BORDER, 8, 2, 8))
	var n := stock.count_item(item)
	var txt := LootTable.item_name(item) + ("  ×%d" % n if n > 1 else "")
	if item is WeaponData:
		txt += "\n" + _weapon_stats(item)
	btn.text = txt
	btn.pressed.connect(func(): select_item(null if is_sel else item))
	return btn


func _survivor_row(s: Survivor) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIStyle.box(UIStyle.TILE, UIStyle.BORDER, 8, 2, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var portrait := SurvivorPortrait.new()
	portrait.custom_minimum_size = Vector2(44, 44)
	portrait.appearance = s.appearance
	portrait.is_hero = s.is_hero
	h.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UIStyle.label(s.full_name() + ("  ★" if s.is_hero else ""), 13))
	var current := s.weapon
	var line := "%s  (%.0f dégâts/s)" % [LootTable.item_name(current), current.dps()]
	var cmp := UIStyle.label(line, 12, UIStyle.TEXT_DIM)
	info.add_child(cmp)
	if _selected is WeaponData:
		var delta: float = (_selected as WeaponData).dps() - current.dps()
		var d := UIStyle.label("Avec la sélection : %+.0f dégâts/s" % delta, 12,
			Color(0.5, 0.85, 0.4) if delta > 0.0 else (Color(0.9, 0.45, 0.4) if delta < 0.0 else UIStyle.TEXT_DIM))
		info.add_child(d)
	var buttons := VBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(buttons)
	var eq := UIStyle.button("Équiper", 12)
	eq.disabled = _selected == null or _selected == current
	eq.pressed.connect(equip.bind(s))
	buttons.add_child(eq)
	var un := UIStyle.button("Ranger", 12)
	un.disabled = s.has_only_slingshot()
	un.tooltip_text = "Rendre l'arme au stock et reprendre le lance-pierre"
	un.pressed.connect(unequip.bind(s))
	buttons.add_child(un)
	return row


func _weapon_stats(w: WeaponData) -> String:
	var t := "%.0f × %d dégâts · %.1f tirs/s · dispersion %.0f° · portée %.0f" % [
		w.damage, w.bullets_per_shot, w.fire_rate, w.spread_deg, w.max_range]
	if w.element != WeaponData.Element.AUCUN:
		t += " · %s +%.0f" % [WeaponData.element_name(w.element), w.element_damage]
	return t + "  ·  ≈ %.0f dégâts/s" % w.dps()
