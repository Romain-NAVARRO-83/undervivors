class_name SurvivorCard
extends PanelContainer
## Vignette du survivant dirigé, en bas à gauche (mode histoire) : portrait,
## nom, niveau, arme, jauges de PV, d'eau, de nourriture et d'XP, et le
## contenu de son sac (une case par place, portions restantes affichées).
## Sans survivant dirigé, elle le dit (et rappelle comment en reprendre un).

var survivor: Survivor
var _portrait: SurvivorPortrait
var _name: Label
var _info: Label
var _bars: Bars
var _bag: Bag
var _empty: Label
var _row: HBoxContainer


func _ready() -> void:
	add_theme_stylebox_override("panel", UIStyle.box(UIStyle.BG, UIStyle.BORDER, 10, 2, 10))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stack := VBoxContainer.new()
	add_child(stack)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 10)
	stack.add_child(_row)
	_portrait = SurvivorPortrait.new()
	_portrait.custom_minimum_size = Vector2(72, 72)
	_row.add_child(_portrait)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	_row.add_child(v)
	_name = UIStyle.label("", 16, UIStyle.ACCENT)
	v.add_child(_name)
	_info = UIStyle.label("", 12, UIStyle.TEXT_DIM)
	v.add_child(_info)
	_bars = Bars.new()
	_bars.custom_minimum_size = Vector2(220, 52)
	v.add_child(_bars)
	_bag = Bag.new()
	_bag.custom_minimum_size = Vector2(220, 30)
	v.add_child(_bag)
	_empty = UIStyle.label("", 13, UIStyle.TEXT_DIM)
	_empty.custom_minimum_size = Vector2(300, 0)
	_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(_empty)


func _process(_d: float) -> void:
	var s := survivor if is_instance_valid(survivor) else null
	_row.visible = s != null
	_empty.visible = s == null
	if s == null:
		_empty.text = "Aucun survivant dirigé : le temps passe plus vite jusqu'à l'aube.\nTab (ou clic droit sur un survivant) pour en reprendre un."
		return
	if _portrait.appearance != s.appearance:
		_portrait.show_survivor(s)
	_name.text = s.full_name()
	var arme: String = s.weapon.weapon_name if s.weapon else "sans arme"
	_info.text = "Niveau %d · %s" % [s.level, arme]
	_bars.survivor = s
	_bars.queue_redraw()
	_bag.survivor = s
	_bag.queue_redraw()


## Jauges dessinées : PV, eau, nourriture, XP du niveau.
class Bars:
	extends Control
	var survivor: Survivor

	func _draw() -> void:
		if not is_instance_valid(survivor):
			return
		var s := survivor
		var rows := [
			["PV", float(s.hp) / s.max_hp, UIStyle.BAR_COLORS["pv"], "%d/%d" % [s.hp, s.max_hp]],
			["Eau", s.thirst / Survivor.NEED_MAX, UIStyle.BAR_COLORS["eau"], "%d %%" % roundi(s.thirst)],
			["Faim", s.hunger / Survivor.NEED_MAX, UIStyle.BAR_COLORS["nourriture"], "%d %%" % roundi(s.hunger)],
			["XP", float(s.xp_in_level()) / Survivor.XP_PER_LEVEL, UIStyle.BAR_COLORS["xp"], "%d/%d" % [s.xp_in_level(), Survivor.XP_PER_LEVEL]],
		]
		var font := get_theme_default_font()
		var w := size.x - 40.0
		for i in rows.size():
			var y := i * 13.0
			var r: Array = rows[i]
			draw_string(font, Vector2(0, y + 10), r[0], HORIZONTAL_ALIGNMENT_LEFT, 36, 10, UIStyle.TEXT_DIM)
			draw_rect(Rect2(36, y + 2, w, 8), UIStyle.BAR_BG)
			draw_rect(Rect2(36, y + 2, w * clampf(r[1], 0.0, 1.0), 8), r[2])
			draw_string(font, Vector2(36, y + 10), r[3], HORIZONTAL_ALIGNMENT_RIGHT, w - 2, 9, Color(1, 1, 1, 0.85))


## Sac : une case par place (4 au niveau 1), icône de l'objet et portions
## restantes pour l'eau et la nourriture.
class Bag:
	extends Control
	var survivor: Survivor
	const CELL := 26.0
	const GAP := 3.0

	func _draw() -> void:
		if not is_instance_valid(survivor):
			return
		var font := get_theme_default_font()
		var cap := survivor.bag_capacity()
		var x := 0.0
		draw_string(font, Vector2(0, 18), "Sac", HORIZONTAL_ALIGNMENT_LEFT, 36, 10, UIStyle.TEXT_DIM)
		x = 36.0
		for i in cap:
			var r := Rect2(Vector2(x, 2), Vector2(CELL, CELL))
			if r.end.x > size.x + 60.0:
				break
			draw_rect(r, UIStyle.BAR_BG)
			draw_rect(r, UIStyle.BORDER, false, 1.0)
			if i < survivor.inventory.size():
				var it: Resource = survivor.inventory[i]
				ItemIcon.draw_item(self, it, r.get_center(), 1.0)
				if it is ConsumableData and it.amount > 1:
					draw_string(font, r.end - Vector2(9, 2), str(it.remaining()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 1, 1, 0.9))
			x += CELL + GAP
