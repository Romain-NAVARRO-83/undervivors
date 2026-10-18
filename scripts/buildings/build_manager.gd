class_name BuildManager
extends Node2D
## Mode construction (GDD 10) : on choisit une construction, un aperçu suit la
## souris sur la grille isométrique, un clic la pose (si l'emplacement est
## valide et qu'il y a assez de bois). Maintenir le clic avec le mur pose une
## ligne. Clic droit ou Échap : annuler.

signal tool_changed(tool: String)
signal placed(building: Building)
signal message(text: String)

const TOOLS := {
	"mur": {"name": "Mur", "cost": Wall.COST},
	"tourelle": {"name": "Tourelle", "cost": Turret.COST},
}

## Vrai quand un outil de construction est actif (bloque le tir à la souris).
static var placing := false

var world: Node2D
var stock: VillageStock
var tool := ""
var instant := false        # debug : chantiers terminés immédiatement
var free_build := false     # debug : constructions gratuites
var occupied := {}          # Vector2i -> Building
var _hover_tile := Vector2i.ZERO
var _hover_valid := false
var _hover_reason := ""


func _ready() -> void:
	z_index = 40
	z_as_relative = false


func set_tool(t: String) -> void:
	tool = t
	placing = t != ""
	tool_changed.emit(t)
	queue_redraw()


# --- Grille isométrique -----------------------------------------------------

static func world_to_tile(p: Vector2) -> Vector2i:
	var a := p.x / (IsoGround.TILE_W / 2.0)
	var b := p.y / (IsoGround.TILE_H / 2.0)
	return Vector2i(roundi((a + b) / 2.0), roundi((b - a) / 2.0))


static func tile_center(t: Vector2i) -> Vector2:
	return IsoGround.tile_to_world(t.x, t.y)


## Vérifie si on peut construire sur la case ; renvoie "" ou la raison du refus.
func check_tile(t: Vector2i, kind: String) -> String:
	var c := tile_center(t)
	if not Terrain.inside_map(c * 1.04):
		return "Hors de la carte"
	if occupied.has(t) and is_instance_valid(occupied[t]):
		return "Emplacement occupé"
	if absf(c.x - Terrain.RIDGE_X) < 36.0 and absf(c.y - Terrain.GAP_Y) > Terrain.GAP_HALF:
		return "Sur la crête"
	for n in get_tree().get_nodes_in_group("resource_nodes"):
		if n.contains(c):
			return "Sur un point de récolte"
	for other in get_tree().get_nodes_in_group("chests") + get_tree().get_nodes_in_group("spawners"):
		if other.global_position.distance_to(c) < 34.0:
			return "Trop près d'un objet"
	if c.distance_to(Vector2.ZERO) < 40.0:
		return "Sur le feu de camp"
	var cost: int = TOOLS[kind]["cost"]
	if not free_build and stock.get_amount("bois") < cost:
		return "Pas assez de bois (%d requis)" % cost
	return ""


## Pose une construction sur la case (vérifications comprises). Renvoie null si refusé.
func place(kind: String, t: Vector2i) -> Building:
	var reason := check_tile(t, kind)
	if reason != "":
		message.emit(reason)
		return null
	var b: Building = Wall.new() if kind == "mur" else Turret.new()
	if b is Turret:
		b.world = world
	b.tile = t
	b.position = tile_center(t)
	if not free_build:
		stock.take("bois", b.cost)
	world.add_child(b)
	occupied[t] = b
	b.destroyed.connect(func(x): if occupied.get(x.tile) == x: occupied.erase(x.tile))
	if instant:
		b.finish()
	placed.emit(b)
	return b


# --- Entrées ----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if tool == "":
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			place(tool, world_to_tile(get_global_mouse_position()))
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			set_tool("")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and tool == "mur" and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Glisser : pose une ligne de murs, une case à la fois
		var t := world_to_tile(get_global_mouse_position())
		if not occupied.has(t) and check_tile(t, tool) == "":
			place(tool, t)
	elif event.is_action_pressed("deselect"):
		set_tool("")
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if tool == "":
		return
	_hover_tile = world_to_tile(get_global_mouse_position())
	_hover_reason = check_tile(_hover_tile, tool)
	_hover_valid = _hover_reason == ""
	queue_redraw()


func _draw() -> void:
	if tool == "":
		return
	var c := tile_center(_hover_tile)
	var col := Color(0.4, 0.95, 0.45, 0.45) if _hover_valid else Color(0.95, 0.35, 0.3, 0.45)
	var pts := PackedVector2Array([c + Vector2(0, -16), c + Vector2(32, 0), c + Vector2(0, 16), c + Vector2(-32, 0)])
	draw_colored_polygon(pts, col)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(col, 0.9), 2.0)
	var label: String = "%s (%d bois)" % [TOOLS[tool]["name"], TOOLS[tool]["cost"]]
	if not _hover_valid:
		label = _hover_reason
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string_outline(font, c + Vector2(-w / 2.0, -24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
	draw_string(font, c + Vector2(-w / 2.0, -24), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color.WHITE)
