class_name TargetDummy
extends StaticBody2D
## Cible d'entraînement (placeholder d'ennemi) : encaisse, se casse, réapparaît.

@export var max_hp: float = 50.0
@export var respawn_time: float = 4.0
var xp_reward: int = 25
var hp: float = 50.0

var _alive := true
var _flash := 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 2
	collision_mask = 0
	_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	_shape.shape = circle
	add_child(_shape)
	hp = max_hp


func is_alive() -> bool:
	return _alive


## Retourne true si le coup a détruit la cible.
func take_damage(amount: float, _element := 0) -> bool:
	if not _alive:
		return false
	hp -= amount
	_flash = 0.12
	_spawn_damage_number(amount)
	if hp <= 0.0:
		_alive = false
		_shape.set_deferred("disabled", true)
		get_tree().create_timer(respawn_time).timeout.connect(_respawn)
		queue_redraw()
		return true
	return false


func _respawn() -> void:
	hp = max_hp
	_alive = true
	_shape.set_deferred("disabled", false)
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash -= delta
		queue_redraw()


func _spawn_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = str(int(round(amount)))
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	label.add_theme_font_size_override("font_size", 12)
	label.position = Vector2(randf_range(-10, 4), -48)
	label.z_index = 10
	add_child(label)
	var tw := create_tween()
	tw.tween_property(label, "position:y", label.position.y - 20, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(label.queue_free)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _alive:
		draw_rect(Rect2(-8, -6, 16, 6), Color(0.4, 0.3, 0.2))
		return
	var c := Color(1, 1, 1) if _flash > 0.0 else Color(0.75, 0.55, 0.35)
	draw_rect(Rect2(-3, -30, 6, 30), Color(0.45, 0.3, 0.2))
	draw_circle(Vector2(0, -32), 9.0, c)
	draw_rect(Rect2(-12, -22, 24, 4), Color(0.45, 0.3, 0.2))
	var w := 22.0
	draw_rect(Rect2(-w / 2, -48, w, 3), Color(0.2, 0, 0))
	draw_rect(Rect2(-w / 2, -48, w * hp / max_hp, 3), Color(0.9, 0.3, 0.3))
