class_name WeaponPickup
extends Area2D
## Arme posée au sol : le survivant contrôlé qui passe dessus l'équipe.

@export var weapon: WeaponData
var _t := 0.0
var _label: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1  # survivants
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	_label = Label.new()
	_label.text = weapon.weapon_name if weapon else "?"
	_label.add_theme_font_size_override("font_size", 11)
	_label.position = Vector2(-60, -40)
	_label.size = Vector2(120, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Survivor and body.selected:
		var old: WeaponData = body.weapon
		body.equip(weapon)
		# On laisse l'ancienne arme au sol (sauf le lance-pierre de base).
		if old and old.resource_path != "res://data/weapons/slingshot.tres":
			weapon = old
			_label.text = weapon.weapon_name
		else:
			queue_free()


func _draw() -> void:
	var bob := sin(_t * 3.0) * 3.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var col := weapon.projectile_color if weapon else Color.WHITE
	draw_rect(Rect2(-12, -16 + bob, 24, 6), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(-12, -16 + bob, 6, 10), col)
