class_name EnemyProjectile
extends Area2D
## Crachat d'un monstre à distance. Lent pour pouvoir être esquivé ; touche les
## survivants, s'écrase sur les obstacles et abîme les constructions.

var velocity: Vector2 = Vector2.ZERO
var damage: float = 6.0
var building_damage: float = 4.0
var max_distance: float = 300.0
var color: Color = Color(0.65, 0.9, 0.25)

var _travelled := 0.0
var _t := 0.0


func _ready() -> void:
	add_to_group("enemy_projectiles")
	collision_layer = 0
	collision_mask = 1 | 4 | Building.LAYER  # survivants, obstacles, constructions
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_t += delta
	var step := velocity * delta
	position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		_splash()
	queue_redraw()


func _on_body_entered(body: Node) -> void:
	if body is Survivor:
		if not Mob.harmless:
			body.take_damage(damage)
	elif body is Building:
		if not body.is_destroyed:
			body.take_damage(building_damage)
	_splash()


func _splash() -> void:
	set_physics_process(false)
	set_deferred("monitoring", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(2.2, 1.1), 0.12)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)


func _draw() -> void:
	# Ombre au sol, boule de crachat un peu au-dessus
	draw_set_transform(Vector2(0, 10), 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 3.5, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var wob := 1.0 + sin(_t * 30.0) * 0.12
	draw_circle(Vector2.ZERO, 4.5 * wob, color.darkened(0.25))
	draw_circle(Vector2(-1, -1), 3.0 * wob, color)
	draw_circle(Vector2(-1.5, -1.5), 1.0, Color(1, 1, 1, 0.7))
