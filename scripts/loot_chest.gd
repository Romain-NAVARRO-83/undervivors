class_name LootChest
extends StaticBody2D
## Coffre de loot (GDD 8 bis) : on tire dessus pour le casser ; il libère
## 1 à 3 objets qui retombent autour de lui. Ce n'est pas un ennemi : le tir
## autonome des survivants ne le vise pas.

signal broken(chest: LootChest)

@export var max_hp: float = 30.0
@export var min_items: int = 1
@export var max_items: int = 3
## Contenu imposé (sinon tiré dans la LootTable à l'ouverture).
var contents: Array[Resource] = []
var world: Node2D
var hp: float = 30.0
var is_broken := false
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	add_to_group("chests")
	collision_layer = 2   # touché par les projectiles (couche « ennemis »)
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 16)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)
	hp = max_hp


## Appelé par les projectiles. Retourne false : un coffre ne rapporte pas d'XP.
func take_damage(amount: float, _element := 0) -> bool:
	if is_broken:
		return false
	hp -= amount
	_shake = 0.15
	if hp <= 0.0:
		_break()
	queue_redraw()
	return false


func _break() -> void:
	is_broken = true
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	var items := contents if not contents.is_empty() else LootTable.roll(_rng, min_items, max_items)
	var parent := world if world else get_parent()
	for i in items.size():
		var p := ItemPickup.new()
		p.item = items[i]
		var angle := TAU * i / items.size() + _rng.randf_range(-0.4, 0.4)
		p.position = position + Vector2(cos(angle), sin(angle) * 0.5) * _rng.randf_range(34.0, 48.0)
		parent.add_child.call_deferred(p)
		p.ready.connect(p.pop_from.bind(position), CONNECT_ONE_SHOT)
	broken.emit(self)


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake -= delta
		queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 17.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var wood := Color(0.55, 0.36, 0.2)
	var dark := Color(0.35, 0.22, 0.12)
	var metal := Color(0.62, 0.6, 0.55)
	if is_broken:
		# Planches éparpillées
		for p in [[Vector2(-14, -2), 0.3], [Vector2(6, 2), -0.5], [Vector2(-2, -8), 1.2], [Vector2(12, -6), 0.1]]:
			draw_set_transform(p[0], p[1], Vector2.ONE)
			draw_rect(Rect2(-8, -2, 16, 4), wood)
			draw_rect(Rect2(-8, -2, 16, 4), dark, false, 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var off := Vector2(randf_range(-2, 2), 0) if _shake > 0.0 else Vector2.ZERO
	# Caisse
	draw_rect(Rect2(Vector2(-15, -18) + off, Vector2(30, 18)), wood)
	draw_rect(Rect2(Vector2(-15, -18) + off, Vector2(30, 18)), dark, false, 2.0)
	# Couvercle bombé
	draw_rect(Rect2(Vector2(-16, -25) + off, Vector2(32, 8)), wood.lightened(0.1))
	draw_rect(Rect2(Vector2(-16, -25) + off, Vector2(32, 8)), dark, false, 2.0)
	# Ferrures et serrure
	for x in [-10, 8]:
		draw_rect(Rect2(Vector2(x, -25) + off, Vector2(3, 25)), metal)
	draw_rect(Rect2(Vector2(-3, -20) + off, Vector2(6, 7)), Color(0.85, 0.7, 0.3))
	# Fissures selon les dégâts
	var dmg := 1.0 - hp / max_hp
	if dmg > 0.3:
		draw_line(Vector2(-12, -14) + off, Vector2(-5, -6) + off, dark, 1.5)
	if dmg > 0.6:
		draw_line(Vector2(4, -16) + off, Vector2(12, -4) + off, dark, 1.5)
