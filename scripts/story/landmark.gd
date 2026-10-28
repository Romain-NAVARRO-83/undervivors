class_name Landmark
extends Node2D
## Repères du mode histoire, pour s'orienter et retrouver les coins :
##   SIGNPOST : poteau et planches fléchées (texte dans `labels` :
##              [[texte, direction], …], direction -1 gauche, 1 droite,
##              0 haut, 2 bas)
##   CAIRN    : petit tas de pierres le long des sentiers
##   FLAG     : mât et drapeau en lambeaux, visible de loin (la crique)
##   DEAD_TREE: grand arbre mort, à l'entrée du bosquet
## Placeholders dessinés en code.

enum Kind { SIGNPOST, CAIRN, FLAG, DEAD_TREE }

var kind: Kind = Kind.CAIRN
var labels: Array = []
var _t := 0.0


func _ready() -> void:
	_t = randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	if kind == Kind.FLAG:
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 14.0 if kind != Kind.DEAD_TREE else 26.0, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match kind:
		Kind.SIGNPOST:
			_draw_signpost()
		Kind.CAIRN:
			_draw_cairn()
		Kind.FLAG:
			_draw_flag()
		Kind.DEAD_TREE:
			_draw_dead_tree()


func _draw_signpost() -> void:
	var wood := Color(0.5, 0.34, 0.2)
	var dark := Color(0.25, 0.16, 0.08)
	draw_rect(Rect2(-3, -64, 6, 64), wood)
	draw_rect(Rect2(-3, -64, 6, 64), dark, false, 1.5)
	var font := ThemeDB.fallback_font
	for i in labels.size():
		var text: String = labels[i][0]
		var dir: int = labels[i][1]
		var y := -60.0 + i * 17.0
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 16.0
		var x0 := -w * 0.5 if dir == 0 or dir == 2 else (4.0 if dir > 0 else -4.0 - w)
		var tip := 8.0
		var board: PackedVector2Array
		if dir > 0:
			board = PackedVector2Array([Vector2(x0, y), Vector2(x0 + w, y), Vector2(x0 + w + tip, y + 7), Vector2(x0 + w, y + 14), Vector2(x0, y + 14)])
		elif dir < 0:
			board = PackedVector2Array([Vector2(x0, y), Vector2(x0 + w, y), Vector2(x0 + w, y + 14), Vector2(x0, y + 14), Vector2(x0 - tip, y + 7)])
		elif dir == 0:
			board = PackedVector2Array([Vector2(x0, y + 3), Vector2(0, y - 5), Vector2(x0 + w, y + 3), Vector2(x0 + w, y + 14), Vector2(x0, y + 14)])
		else:
			board = PackedVector2Array([Vector2(x0, y), Vector2(x0 + w, y), Vector2(x0 + w, y + 11), Vector2(0, y + 19), Vector2(x0, y + 11)])
		draw_colored_polygon(board, Color(0.72, 0.56, 0.36))
		draw_polyline(board + PackedVector2Array([board[0]]), dark, 1.5)
		draw_string(font, Vector2(x0 + 8, y + 11), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.2, 0.12, 0.05))


func _draw_cairn() -> void:
	var stones := [[Vector2(0, -3), 9.0], [Vector2(-1, -12), 7.0], [Vector2(1, -19), 5.5], [Vector2(0, -25), 4.0]]
	for st in stones:
		draw_circle(st[0], st[1], Color(0.5, 0.48, 0.45))
		draw_arc(st[0], st[1], 0.0, TAU, 14, Color(0.25, 0.24, 0.22), 1.2)
		draw_circle(st[0] + Vector2(-st[1] * 0.3, -st[1] * 0.3), st[1] * 0.35, Color(0.62, 0.6, 0.56))


func _draw_flag() -> void:
	draw_line(Vector2(0, 0), Vector2(0, -110), Color(0.55, 0.55, 0.58), 3.0)
	draw_circle(Vector2(0, -112), 3.0, Color(0.7, 0.7, 0.72))
	var pts := PackedVector2Array()
	var pts2 := PackedVector2Array()
	for i in 9:
		var x := i * 6.0
		var wave := sin(_t * 4.0 + i * 0.7) * (1.0 + i * 0.6)
		pts.append(Vector2(x, -108 + wave))
		pts2.append(Vector2(x, -84 + wave - (i % 3) * 2.0))   # bord déchiré
	pts2.reverse()
	draw_colored_polygon(pts + pts2, Color(0.85, 0.3, 0.2))
	draw_polyline(pts, Color(0.5, 0.15, 0.1), 1.5)


func _draw_dead_tree() -> void:
	var bark := Color(0.38, 0.32, 0.27)
	var dark := Color(0.2, 0.16, 0.13)
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(5, -70), Vector2(-4, -72)]), bark)
	for b in [[Vector2(2, -60), Vector2(30, -96), 4.0], [Vector2(0, -48), Vector2(-28, -80), 4.0], [Vector2(18, -84), Vector2(36, -86), 2.0],
			[Vector2(-18, -70), Vector2(-24, -100), 2.0], [Vector2(1, -70), Vector2(4, -110), 3.0]]:
		draw_line(b[0], b[1], bark, b[2], true)
	draw_line(Vector2(-9, 0), Vector2(-4, -72), dark, 1.5)
	draw_line(Vector2(9, 0), Vector2(5, -70), dark, 1.5)
