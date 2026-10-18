class_name Projectile
extends Area2D
## Projectile tiré par un survivant. Touche les corps de la couche « ennemis ».

var velocity: Vector2 = Vector2.ZERO
var damage: float = 10.0
var element: WeaponData.Element = WeaponData.Element.AUCUN
var element_damage: float = 0.0
var max_distance: float = 360.0
var color: Color = Color.WHITE
var shooter: Node = null

var _travelled := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # ennemis
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		var killed: bool = body.take_damage(damage + element_damage, element)
		if killed and is_instance_valid(shooter) and shooter.has_method("add_xp"):
			shooter.add_xp(body.get("xp_reward") if body.get("xp_reward") != null else 10)
	queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, color)
