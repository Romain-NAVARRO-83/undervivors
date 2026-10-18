class_name ItemPickup
extends Area2D
## Objet au sol (GDD 8 bis) : le premier survivant qui passe dessus le ramasse.
## - S'il n'a que le lance-pierre et que c'est une arme : il l'équipe aussitôt.
## - Sinon l'objet va dans son sac, s'il reste de la place.
## - Sac plein : l'objet reste au sol pour un autre survivant.

## Délai avant de pouvoir ramasser (le temps de voir l'objet jaillir du coffre).
const PICKUP_DELAY := 0.6

var item: Resource
var _t := 0.0
var _label: Label


func _ready() -> void:
	add_to_group("item_pickups")
	collision_layer = 0
	collision_mask = 1  # survivants
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	_label = Label.new()
	_label.text = LootTable.item_name(item)
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 3)
	_label.position = Vector2(-70, -38)
	_label.size = Vector2(140, 14)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)


## Fait jaillir l'objet de `from` jusqu'à sa position finale.
func pop_from(from: Vector2) -> void:
	var target := position
	position = from
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", target, 0.45)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t < PICKUP_DELAY:
		return
	for body in get_overlapping_bodies():
		if body is Survivor and body.try_pick_up(item):
			queue_free()
			return


func _draw() -> void:
	var bob := sin(_t * 3.0) * 3.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Halo pour bien repérer le loot
	var glow := 0.35 + 0.2 * sin(_t * 4.0)
	draw_circle(Vector2(0, -12 + bob), 13.0, Color(1, 0.85, 0.4, glow * 0.35))
	var col := Color.WHITE
	if item is WeaponData:
		col = item.projectile_color
	draw_rect(Rect2(-12, -16 + bob, 24, 6), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(-12, -16 + bob, 6, 10), col)
