class_name HitEffect
extends Node2D
## Animation d'impact d'un tir (placeholder dessiné en code) : un éclair
## blanc, une onde qui s'élargit et des éclats projetés en étoile, aux couleurs
## du projectile. Dure une fraction de seconde puis disparaît.
##   CREATURE : touche un monstre (gros éclat, éclats colorés)
##   WOOD     : touche un coffre ou une construction (échardes brunes)
##   DUST     : s'écrase sur un obstacle (poussière grise)

enum Kind { CREATURE, WOOD, DUST }

const DURATION := 0.32

var color := Color.WHITE
var kind: Kind = Kind.CREATURE
## Direction du tir : les éclats partent surtout vers l'avant.
var direction := Vector2.RIGHT
var _t := 0.0
var _sparks: Array = []   # [direction, vitesse, taille]


static func spawn(parent: Node, pos: Vector2, col: Color, k: Kind, dir: Vector2) -> HitEffect:
	var fx := HitEffect.new()
	fx.global_position = pos
	fx.color = col
	fx.kind = k
	fx.direction = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	parent.add_child(fx)
	return fx


func _ready() -> void:
	z_index = 30
	z_as_relative = false
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var n := 7 if kind == Kind.CREATURE else 5
	for i in n:
		# Éventail vers l'avant du tir, quelques éclats vers l'arrière
		var spread := rng.randf_range(-1.3, 1.3) if i < n - 2 else rng.randf_range(2.2, 4.1)
		var d := direction.rotated(spread)
		_sparks.append([Vector2(d.x, d.y * 0.6), rng.randf_range(60.0, 130.0), rng.randf_range(1.5, 3.0)])


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION           # 0 → 1
	var fade := 1.0 - k
	var main := color
	match kind:
		Kind.WOOD:
			main = Color(0.7, 0.5, 0.3)
		Kind.DUST:
			main = Color(0.75, 0.73, 0.68)
	# Éclair blanc au point d'impact (très court)
	if k < 0.35:
		var flash := 1.0 - k / 0.35
		draw_circle(Vector2.ZERO, 9.0 + 6.0 * flash, Color(1, 1, 1, 0.9 * flash))
		draw_circle(Vector2.ZERO, 6.0, Color(main.lightened(0.5), flash))
	# Onde qui s'élargit (ellipse « au sol » en vue iso)
	var r := 8.0 + 22.0 * ease(k, 0.4)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.65))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 20, Color(main, 0.85 * fade), 3.0 * fade + 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Éclats
	for s in _sparks:
		var p: Vector2 = s[0] * s[1] * ease(k, 0.5) * 0.3
		var tail: Vector2 = p - s[0] * 9.0 * fade
		if kind == Kind.DUST:
			draw_circle(p, s[2] * (1.0 + k), Color(main, 0.6 * fade))
		else:
			draw_line(tail, p, Color(0, 0, 0, 0.35 * fade), s[2] + 1.5, true)
			draw_line(tail, p, Color(main.lightened(0.3), fade), s[2], true)
