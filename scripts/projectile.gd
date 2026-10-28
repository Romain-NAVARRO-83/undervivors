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

## Rayon de la zone de touche (plus large que la balle dessinée, pour
## pardonner une visée approximative).
const HIT_RADIUS := 8.0
## La balle vole à hauteur de buste (10 px au-dessus du sol) mais les
## monstres ont leur zone de touche aux pieds : on recale la zone vers le bas.
const HIT_DROP := 8.0

var _travelled := 0.0
var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 | 4  # ennemis + obstacles (les rochers arrêtent les tirs)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = HIT_RADIUS
	shape.shape = circle
	shape.position = Vector2(0, HIT_DROP)
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if _done:
		return   # deux corps touchés dans la même image : un seul impact
	_done = true
	_impact(body)
	if body is Mob:
		# Les monstres gèrent la part élémentaire (résistances, effets).
		var killed_mob: bool = body.take_hit(damage, element, element_damage, shooter)
		if killed_mob and is_instance_valid(shooter) and shooter.has_method("add_xp"):
			shooter.add_xp(body.xp_reward)
	elif body is LootChest:
		# Le leader d'escouade tire sur un coffre : toute l'escouade s'y met.
		if shooter is Survivor and shooter.selected and shooter.squad_member:
			Survivor.squad_focus = body
		body.take_damage(damage + element_damage, element)
	elif body.has_method("take_damage"):
		var killed: bool = body.take_damage(damage + element_damage, element)
		if killed and is_instance_valid(shooter) and shooter.has_method("add_xp"):
			shooter.add_xp(body.get("xp_reward") if body.get("xp_reward") != null else 10)
	queue_free()


## Animation d'impact au point de contact.
func _impact(body: Node) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var kind := HitEffect.Kind.DUST
	if body is Mob:
		kind = HitEffect.Kind.CREATURE
	elif body is LootChest or body is Building:
		kind = HitEffect.Kind.WOOD
	HitEffect.spawn(parent, global_position, color, kind, velocity)


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, color)
