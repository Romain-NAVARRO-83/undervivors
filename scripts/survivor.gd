class_name Survivor
extends CharacterBody2D
## Un survivant (voir GDD, section 5).
## - Sélectionné : déplacement au clavier, visée à la souris, tir au clic (maintenu).
## - Non sélectionné : erre autour du centre du village et tire en autonome.

signal died(survivor: Survivor)

const WANDER_SPEED := 60.0
const XP_PER_LEVEL := 100
## Valeur maximale affichée pour les stats (barres du panneau).
const STAT_MAX := 20
const HP_PER_POINT := 10
## Récolte (GDD 9) : quantité portée par trajet = CARRY_BASE + CARRY_PER_LEVEL × niveau
## (4 au niveau 1, 8 au niveau 3), et vitesse pendant les trajets de récolte
## (× la vitesse normale : plus rapide que la marche ordinaire).
const CARRY_BASE := 2
const CARRY_PER_LEVEL := 2
const WORK_SPEED_MULT := 1.2

## Statistiques (GDD 5.1). Vitesse, précision et force vont de 1 à STAT_MAX.
@export var max_hp: int = 100
var hp: int = 100
var xp: int = 0
var level: int = 1
var speed_stat: int = 5
var accuracy: int = 5
var strength: int = 5
## Points gagnés en montant de niveau, à attribuer dans le panneau de gestion.
var stat_points: int = 0

var first_name: String = ""
var last_name: String = ""
var is_hero: bool = false
var appearance: SurvivorAppearance
var weapon: WeaponData
## Sac individuel (GDD 8 bis) : objets ramassés, rentrés au feu de camp.
var inventory: Array[Resource] = []
const SLINGSHOT_PATH := "res://data/weapons/slingshot.tres"
var _full_bag_cooldown := 0.0
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

## Monde (nœud trié en Y) où ajouter les projectiles.
var world: Node2D
var village_center: Vector2 = Vector2.ZERO
var wander_radius: float = 140.0
var aim_dir: Vector2 = Vector2.RIGHT

## Récolte (GDD 9) : point de récolte assigné (null = aucun) et chargement porté.
enum WorkState { TO_SOURCE, GATHERING, TO_VILLAGE }
var stock: VillageStock
var task_node: ResourceNode = null
var carrying: int = 0
var carrying_type: String = ""
var work_state: WorkState = WorkState.TO_SOURCE
## Récolte suspendue parce que le stock est plein (reprise automatique sous 50 %).
var work_paused := false
## Poste de tourelle assigné, et vrai quand le servant est en place.
var post: Turret = null
var manning := false
## Alerte générale : les survivants libres rentrent défendre le camp (GDD 10).
static var alert := false
## Cible commune de l'escouade : quand le leader tire sur un coffre, les
## suiveurs tirent dessus aussi jusqu'à ce qu'il casse (sauf monstre au contact).
static var squad_focus: Node2D = null
const FOCUS_DEFEND_RANGE := 120.0
var _alert_offset := Vector2.ZERO
## Escouade (GDD 6) : membre de l'escouade enregistrée, et suivi du leader.
## `following` est vrai pour les suiveurs quand le mode escouade est actif ;
## `follow_point` est la place en formation, calculée par la scène principale.
var squad_member: bool = false:
	set(value):
		squad_member = value
		if value:
			add_to_group("squad")
		elif is_in_group("squad"):
			remove_from_group("squad")
var squad_index: int = 0
var following: bool = false
var follow_point: Vector2 = Vector2.ZERO
var follow_speed: float = 0.0

## Besoins (GDD 9) : jauges d'eau et de nourriture, de 0 (manque) à 100 (rassasié).
const NEED_MAX := 100.0
const THIRST_DECAY := 100.0 / 240.0   # jauge d'eau vide en 4 minutes
const HUNGER_DECAY := 100.0 / 360.0   # jauge de nourriture vide en 6 minutes
const NEED_LOW := 30.0                # en dessous : il réclame et va au stock
const NEED_REFILLED := 80.0           # au-dessus : il cesse d'aller au stock
const REFILL_PER_UNIT := 25.0         # une unité du stock rend 25 points
const EMPTY_SLOWDOWN := 0.6           # jauge vide : vitesse × 0,6
const NEED_RESOURCE := {"eau": "thirst", "nourriture": "hunger"}

## Blessures (GDD 5.5) : les monstres mordent ; mort définitive à 0 PV.
## Soin lent sur la place du camp, si on n'a pas été touché depuis un moment
## et qu'on n'a ni faim ni soif au point d'avoir une jauge vide.
const REGEN_DELAY := 5.0        # secondes sans être touché avant de se soigner
const REGEN_PER_SEC := 3.0      # PV rendus par seconde au camp
const HP_LOW := 0.3             # sous 30 % : un survivant libre rentre se soigner
const HP_HEALED := 0.8          # il repart au-dessus de 80 %
var _dead := false
var _since_hit := 99.0
var _regen_acc := 0.0
var _hurt_flash := 0.0
var _hurt_bubble_cd := 0.0
var _healing := false

## Mode histoire : faim/soif et soin au camp peuvent être coupés (prologue).
var needs_enabled := true
var camp_regen := true
## Mode histoire : commence sans arme (pas de lance-pierre par défaut).
var unarmed_start := false
## Mode histoire : PV minimum (> 0 = ne peut pas mourir, ex. l'ami du prologue).
var hp_floor := 0

var thirst: float = NEED_MAX
var hunger: float = NEED_MAX
var bubble: SpeechBubble
var _bubble_cooldown := 0.0
var _refill_cooldown := 0.0
var _consume_cooldown := 0.0
var _refilling := false

var _gather_timer := 0.0
var _gather_angle := 0.0
var _deposit_offset := Vector2.ZERO

var _rng := RandomNumberGenerator.new()
var _wander_target: Vector2
var _wander_wait := 0.0
var _cooldown := 0.0
var _body_color := Color(0.3, 0.6, 0.9)


func _ready() -> void:
	_rng.randomize()
	add_to_group("survivors")
	collision_layer = 1   # survivants
	collision_mask = 2 | 4 | Building.LAYER  # ennemis, obstacles, constructions (les survivants se traversent entre eux)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 9.0
	shape.shape = circle
	add_child(shape)
	if first_name.is_empty():
		first_name = NameGenerator.generate_part(_rng)["text"]
		last_name = NameGenerator.generate_part(_rng)["text"]
	if weapon == null and not unarmed_start:
		weapon = load("res://data/weapons/slingshot.tres")
	if appearance == null:
		appearance = SurvivorAppearance.random(_rng)
	speed_stat = _rng.randi_range(3, 8)
	accuracy = _rng.randi_range(3, 8)
	strength = _rng.randi_range(3, 8)
	if is_hero:
		speed_stat += 2
		accuracy += 2
		strength += 2
	hp = max_hp
	_body_color = appearance.shirt_color
	thirst = _rng.randf_range(60.0, NEED_MAX)
	hunger = _rng.randf_range(60.0, NEED_MAX)
	_bubble_cooldown = _rng.randf_range(0.0, 3.0)
	bubble = SpeechBubble.new()
	add_child(bubble)
	_pick_wander_target()


## Vitesse de déplacement en px/s : 150 pour une stat de 5.
func move_speed() -> float:
	var base := 110.0 + speed_stat * 8.0
	# Jauge d'eau ou de nourriture vide : ralenti (GDD 9).
	if thirst <= 0.0 or hunger <= 0.0:
		base *= EMPTY_SLOWDOWN
	return base


## Multiplicateur de dispersion : 1 pour une précision de 5, plus serré au-delà.
func spread_factor() -> float:
	return clampf(1.3 - accuracy * 0.06, 0.2, 1.5)


## Quantité rapportée par trajet : liée au niveau (GDD 9).
func carry_capacity() -> int:
	return CARRY_BASE + CARRY_PER_LEVEL * level


## Taille du sac : 4 objets au niveau 1, +2 par niveau (l'arme équipée ne compte pas).
func bag_capacity() -> int:
	return 4 + 2 * (level - 1)


func has_only_slingshot() -> bool:
	return weapon == null or weapon.resource_path == SLINGSHOT_PATH


## Essaie de ramasser un objet. Retourne false si le sac est plein
## (l'objet reste alors au sol).
func try_pick_up(item: Resource) -> bool:
	if item is WeaponData and has_only_slingshot():
		equip(item)
		_say("%s, à moi !" % LootTable.item_name(item), 2.0)
		return true
	if inventory.size() >= bag_capacity():
		if _full_bag_cooldown <= 0.0:
			_say("Mon sac est plein !", 2.0)
			_full_bag_cooldown = 4.0
		return false
	inventory.append(item)
	return true


## Équipe une arme prise dans le stock commun ; l'arme actuelle y retourne
## (sauf le lance-pierre, toujours disponible). Retourne false si l'arme n'est plus en stock.
func equip_from_stock(item: WeaponData) -> bool:
	if stock == null or not stock.remove_item(item):
		return false
	if not has_only_slingshot():
		stock.add_item(weapon)
	equip(item)
	return true


## Range l'arme équipée dans le stock commun et reprend le lance-pierre.
func unequip_to_stock() -> bool:
	if stock == null or has_only_slingshot():
		return false
	stock.add_item(weapon)
	equip(load(SLINGSHOT_PATH))
	return true


## Au feu de camp : le contenu du sac rejoint le stock d'objets commun.
func _deposit_inventory() -> void:
	if inventory.is_empty() or stock == null:
		return
	var n := 0
	var kept: Array[Resource] = []
	for item in inventory:
		if item is ConsumableData:
			# Eau, nourriture : dans le stock du village (s'il reste de la place).
			if stock.add(item.resource_type, item.amount) > 0:
				n += 1
			else:
				kept.append(item)
		else:
			stock.add_item(item)
			n += 1
	inventory = kept
	if n > 0:
		_say("Butin rapporté : %d objet%s" % [n, "s" if n > 1 else ""], 2.5)


func _say(text: String, duration := 3.0) -> void:
	if bubble:
		bubble.say(text, duration)


## Assigne le survivant à un point de récolte, ou le libère avec null.
## S'il porte quelque chose, il va d'abord le déposer au village.
func assign(node: ResourceNode) -> void:
	if node != null and post != null:
		assign_post(null)
	task_node = node
	work_paused = false
	if node:
		_gather_angle = _rng.randf() * TAU
		_deposit_offset = Vector2(cos(_gather_angle), sin(_gather_angle) * 0.5) * 22.0
	work_state = WorkState.TO_VILLAGE if carrying > 0 else WorkState.TO_SOURCE


## Assigne le survivant au poste d'une tourelle (null = le libérer).
func assign_post(t: Turret) -> void:
	_set_manning(false)
	if post != null and is_instance_valid(post) and post.gunner == self:
		post.gunner = null
	post = t
	if t != null:
		task_node = null
		work_paused = false
		if is_instance_valid(t.gunner) and t.gunner != self:
			t.gunner.assign_post(null)  # un seul servant par tourelle
		t.gunner = self


## Texte court décrivant l'activité, pour l'interface.
func activity_text() -> String:
	if selected:
		var role := "Leader de l'escouade" if squad_member and _is_squad_mode() else "Contrôlé"
		return role + (" · porte %d %s" % [carrying, carrying_type] if carrying > 0 else "")
	if following:
		return "Suit le leader en formation"
	if _healing and post == null and not alert:
		return "Se soigne au camp" if in_camp() else "Blessé : rentre se soigner"
	if _refilling:
		return "Va boire et manger au village"
	if post != null:
		return ("Sert la %s" if manning else "Rejoint la %s") % post.display_name.to_lower()
	if alert:
		return "Alerte : défend le camp"
	if task_node == null:
		return "Dépose %d %s" % [carrying, carrying_type] if carrying > 0 else "Erre au village"
	if work_paused:
		return "En pause : stock de %s plein" % task_node.resource_type
	match work_state:
		WorkState.TO_SOURCE:
			return "Va à : %s" % task_node.display_name
		WorkState.GATHERING:
			return "Récolte à : %s" % task_node.display_name
		_:
			return "Rapporte %d %s" % [carrying, carrying_type]


## XP accumulée depuis le dernier niveau, et XP nécessaire pour le suivant.
func xp_in_level() -> int:
	return xp - (level - 1) * XP_PER_LEVEL


## Dépense un point de stat. `stat` : "pv_max", "vitesse", "precision" ou "force".
func spend_point(stat: String) -> bool:
	if stat_points <= 0:
		return false
	match stat:
		"pv_max":
			max_hp += HP_PER_POINT
			hp += HP_PER_POINT
		"vitesse":
			if speed_stat >= STAT_MAX: return false
			speed_stat += 1
		"precision":
			if accuracy >= STAT_MAX: return false
			accuracy += 1
		"force":
			if strength >= STAT_MAX: return false
			strength += 1
		_:
			return false
	stat_points -= 1
	return true


func full_name() -> String:
	return "%s %s" % [first_name, last_name]


func _physics_process(delta: float) -> void:
	_cooldown = max(_cooldown - delta, 0.0)
	_update_needs(delta)
	_update_health(delta)
	if manning and (selected or following):
		_set_manning(false)  # repris en main : il descend de la tourelle
	if selected:
		_process_controlled()
	elif following:
		_process_follow()
	else:
		_process_autonomous(delta)
	move_and_slide()
	queue_redraw()


func _process_controlled() -> void:
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = input * move_speed()
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 1.0:
		aim_dir = to_mouse.normalized()
	# Pas de tir quand la souris survole l'interface (panneau, boutons).
	if Input.is_action_pressed("shoot") and get_viewport().gui_get_hovered_control() == null and not BuildManager.placing:
		try_shoot(aim_dir)



# --- Besoins : faim et soif -------------------------------------------------

func _update_needs(delta: float) -> void:
	# needs_enabled coupe seulement la baisse des jauges (prologue) ; boire,
	# manger et déposer au feu restent possibles.
	if needs_enabled:
		thirst = maxf(thirst - THIRST_DECAY * delta, 0.0)
		hunger = maxf(hunger - HUNGER_DECAY * delta, 0.0)
	_refill_cooldown -= delta
	_full_bag_cooldown -= delta
	_consume_cooldown -= delta
	# Il a soif (ou faim) et transporte de l'eau (ou à manger) : il se sert.
	if _consume_cooldown <= 0.0:
		_consume_cooldown = 1.0
		_consume_from_bag("eau")
		_consume_from_bag("nourriture")
	# En passant au centre du village : on dépose, puis on boit et mange au stock.
	if global_position.distance_to(village_center) < 40.0:
		if carrying > 0:
			_deposit()
		_deposit_inventory()
		if _refill_cooldown <= 0.0:
			_refill_cooldown = 1.0
			_refill("eau")
			_refill("nourriture")
	_update_complaints(delta)


## Consomme une unité du sac (bouteille d'eau, ration) si la jauge est basse.
func _consume_from_bag(resource_type: String) -> bool:
	var prop: String = NEED_RESOURCE[resource_type]
	var level: float = get(prop)
	if level >= NEED_LOW:
		return false
	for i in inventory.size():
		var it = inventory[i]
		if it is ConsumableData and it.resource_type == resource_type:
			inventory.remove_at(i)
			set(prop, minf(level + it.amount * REFILL_PER_UNIT, NEED_MAX))
			_say("Slurp !" if resource_type == "eau" else "Miam !", 1.4)
			return true
	return false


## Prend au stock ce qu'il faut pour remonter la jauge (s'il y en a).
func _refill(resource_type: String) -> void:
	if stock == null:
		return
	var prop: String = NEED_RESOURCE[resource_type]
	var level: float = get(prop)
	if level >= NEED_REFILLED:
		return
	var units := ceili((NEED_MAX - level) / REFILL_PER_UNIT)
	var taken := stock.take(resource_type, units)
	if taken > 0:
		set(prop, minf(level + taken * REFILL_PER_UNIT, NEED_MAX))
		_say("Slurp !" if resource_type == "eau" else "Miam !", 1.4)


## Vrai si le survivant doit aller au stock pour boire ou manger
## (seulement s'il y a de quoi : un stock vide ne change rien, GDD 9).
func needs_refill() -> bool:
	if stock == null:
		return false
	return (thirst < NEED_LOW and stock.get_amount("eau") > 0) \
		or (hunger < NEED_LOW and stock.get_amount("nourriture") > 0)


func _going_to_refill() -> bool:
	# Une fois parti, il y va jusqu'à être servi ou que le stock soit vide.
	if needs_refill():
		_refilling = true
	elif _refilling:
		var still := (thirst < NEED_REFILLED and stock.get_amount("eau") > 0) \
			or (hunger < NEED_REFILLED and stock.get_amount("nourriture") > 0)
		_refilling = still
	return _refilling


const LINES_THIRST := [
	"J'ai soif…", "De l'eau, vite !", "Ma langue colle au palais.",
	"Je boirais même l'eau de la mare.", "Quelqu'un a pensé à l'eau ?",
]
const LINES_HUNGER := [
	"J'ai faim…", "Je mangerais un crabe cru.", "Mon ventre fait des bruits de raid.",
	"Le prochain qui parle de nourriture, je le mange.", "On mange quand, au juste ?",
]
const LINES_BOTH := ["J'ai faim ET soif. Super séjour.", "Ni à boire ni à manger… charmant."]
const LINES_EMPTY := ["Je… n'avance plus…", "Je vais m'écrouler, là.", "C'est la fin, je le sens."]
const LINES_STOCK_EMPTY := ["Le stock est vide ?!", "Il n'y a plus rien au village…"]


## Bulle de dialogue quand l'eau ou la nourriture manque.
func _update_complaints(delta: float) -> void:
	_bubble_cooldown -= delta
	if _bubble_cooldown > 0.0 or bubble == null:
		return
	var thirsty := thirst < NEED_LOW
	var hungry := hunger < NEED_LOW
	if not thirsty and not hungry:
		return
	var lines: Array
	if thirst <= 0.0 or hunger <= 0.0:
		lines = LINES_EMPTY
	elif thirsty and hungry:
		lines = LINES_BOTH
	elif thirsty:
		lines = LINES_THIRST if stock == null or stock.get_amount("eau") > 0 or _rng.randf() < 0.6 else LINES_STOCK_EMPTY
	else:
		lines = LINES_HUNGER if stock == null or stock.get_amount("nourriture") > 0 or _rng.randf() < 0.6 else LINES_STOCK_EMPTY
	bubble.say(lines[_rng.randi_range(0, lines.size() - 1)], 3.0)
	_bubble_cooldown = _rng.randf_range(7.0, 12.0)


## Suiveur d'escouade : rejoint sa place en formation, tire seul (GDD 6).
## Sa tâche de récolte est en pause et reprend à la sortie du mode escouade.
func _process_follow() -> void:
	var to_slot := follow_point - global_position
	var dist := to_slot.length()
	if dist < 4.0:
		velocity = Vector2.ZERO
	else:
		# Rattrape plus vite quand il est loin, ralentit en approchant.
		var speed := maxf(move_speed(), follow_speed * 1.15)
		var waypoint := Nav.route(global_position, follow_point)
		velocity = (waypoint - global_position).normalized() * minf(speed, maxf(dist, 30.0) * 6.0)
	_autonomous_shooting()


func _is_squad_mode() -> bool:
	var main := get_tree().current_scene
	return main != null and main.get("squad_mode") == true


func _process_autonomous(delta: float) -> void:
	if post != null and not is_instance_valid(post):
		post = null
		_set_manning(false)
	if post != null:
		_process_post(delta)
		return
	if alert:
		_process_alert()
		_autonomous_shooting()
		return
	if _going_to_heal():
		# Gravement blessé : il rentre au camp se soigner, puis reprend sa tâche.
		# (Il garde son chargement et le dépose en passant au feu.)
		if in_camp():
			_process_wander(delta)
		else:
			_move_towards(village_center + _deposit_offset, move_speed())
	elif _going_to_refill():
		# Assoiffé ou affamé : il va au stock de lui-même (GDD 9), puis reprend.
		_move_towards(village_center + _deposit_offset, move_speed() * 0.8)
	elif task_node != null or carrying > 0:
		_process_work(delta)
	else:
		_process_wander(delta)
	_autonomous_shooting()


## Servant de tourelle : rejoint le poste et y reste ; c'est la tourelle qui tire.
## Il va quand même boire et manger s'il en a besoin, puis revient.
func _process_post(_delta: float) -> void:
	if _going_to_refill():
		_set_manning(false)
		_move_towards(village_center + _deposit_offset, move_speed() * 0.8)
		return
	if not post.is_built:
		_set_manning(false)
		_move_towards(post.mount_point() + Vector2(0, 26), move_speed())
		return
	if manning:
		# Sur la plateforme : il ne bouge plus, c'est la tourelle qui tire.
		global_position = post.top_point()
		velocity = Vector2.ZERO
		return
	if _move_towards(post.mount_point(), move_speed()):
		_set_manning(true)
	else:
		_autonomous_shooting()


## Monte sur la tourelle (on) ou en redescend devant elle (off).
## Sur la plateforme, il est dessiné au-dessus du bloc et ne heurte plus la
## construction ; les monstres au corps à corps ne peuvent pas l'atteindre.
func _set_manning(on: bool) -> void:
	if on == manning:
		return
	manning = on
	if on:
		z_index = 1
		collision_mask = 2 | 4
		global_position = post.top_point()
	else:
		z_index = 0
		collision_mask = 2 | 4 | Building.LAYER
		if post != null and is_instance_valid(post):
			global_position = post.mount_point()


## Alerte : retour au camp, on se poste autour du feu et on tire.
func _process_alert() -> void:
	if _alert_offset == Vector2.ZERO:
		var a := _rng.randf() * TAU
		_alert_offset = Vector2(cos(a), sin(a) * 0.5) * _rng.randf_range(30.0, 60.0)
	_move_towards(village_center + _alert_offset, move_speed())


## Cycle de récolte : aller au point, récolter, rapporter au centre, déposer.
func _process_work(delta: float) -> void:
	var speed := move_speed() * WORK_SPEED_MULT
	# Stock plein : on arrête la récolte ; reprise quand il repasse sous 50 %.
	if task_node != null and stock != null:
		var res := task_node.resource_type
		if work_paused:
			if stock.needs_restock(res):
				work_paused = false
				work_state = WorkState.TO_VILLAGE if carrying > 0 else WorkState.TO_SOURCE
			else:
				if carrying > 0 and global_position.distance_to(village_center) < 40.0:
					_deposit()
				_process_wander(delta)
				return
		elif stock.is_full(res) and work_state != WorkState.TO_VILLAGE:
			work_paused = true
			_say("Le stock est plein, je fais une pause.", 2.5)
			_process_wander(delta)
			return
	match work_state:
		WorkState.TO_SOURCE:
			if task_node == null:
				work_state = WorkState.TO_VILLAGE
			elif _move_towards(task_node.gather_point(_gather_angle), speed):
				work_state = WorkState.GATHERING
				_gather_timer = task_node.gather_time
		WorkState.GATHERING:
			velocity = Vector2.ZERO
			_gather_timer -= delta
			if task_node == null:
				work_state = WorkState.TO_VILLAGE
			elif _gather_timer <= 0.0:
				carrying = carry_capacity()
				carrying_type = task_node.resource_type
				work_state = WorkState.TO_VILLAGE
		WorkState.TO_VILLAGE:
			if _move_towards(village_center + _deposit_offset, speed):
				_deposit()
				work_state = WorkState.TO_SOURCE


## Dépose la charge au stock ; ce qui ne rentre pas (stock plein) reste porté.
func _deposit() -> void:
	if carrying > 0 and stock:
		carrying -= stock.add(carrying_type, carrying)
	if carrying <= 0:
		carrying = 0
		carrying_type = ""


## Fixe la vitesse vers `target` ; retourne true une fois arrivé.
func _move_towards(target: Vector2, speed: float) -> bool:
	var to_target := target - global_position
	if to_target.length() < 6.0:
		velocity = Vector2.ZERO
		return true
	# Contourne la crête par le passage si besoin.
	var waypoint := Nav.route(global_position, target)
	velocity = (waypoint - global_position).normalized() * speed
	return false


func _process_wander(delta: float) -> void:
	# Errance autour du centre du village.
	if _wander_wait > 0.0:
		_wander_wait -= delta
		velocity = Vector2.ZERO
	else:
		var to_target := _wander_target - global_position
		if to_target.length() < 6.0:
			velocity = Vector2.ZERO
			_wander_wait = _rng.randf_range(1.0, 3.0)
			_pick_wander_target()
		else:
			velocity = to_target.normalized() * WANDER_SPEED


## Tir autonome sur l'ennemi le plus proche à portée (GDD 5.4).
func _autonomous_shooting() -> void:
	var target := _nearest_enemy()
	if following and _focus_valid():
		var near_enemy := target != null and global_position.distance_to(target.global_position) < FOCUS_DEFEND_RANGE
		if weapon != null and not near_enemy and global_position.distance_to(squad_focus.global_position) <= weapon.max_range:
			target = squad_focus
	if target:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		aim_dir = dir
		try_shoot(dir)
	elif velocity.length() > 1.0:
		aim_dir = velocity.normalized()


## Vrai si la cible commune de l'escouade existe encore (coffre pas cassé).
static func _focus_valid() -> bool:
	if squad_focus == null or not is_instance_valid(squad_focus):
		squad_focus = null
		return false
	if squad_focus.get("is_broken") == true:
		squad_focus = null
		return false
	return true


func _pick_wander_target() -> void:
	var angle := _rng.randf() * TAU
	var dist := _rng.randf_range(20.0, wander_radius)
	_wander_target = village_center + Vector2(cos(angle), sin(angle) * 0.5) * dist


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	if weapon == null:
		return null  # sans arme : ne vise personne
	var best_dist := weapon.max_range
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.has_method("is_alive") and not e.is_alive():
			continue
		var d := global_position.distance_to(e.global_position)
		if d < best_dist:
			best_dist = d
			best = e
	return best


func try_shoot(dir: Vector2) -> void:
	if _cooldown > 0.0 or weapon == null or world == null:
		return
	_cooldown = weapon.cooldown()
	for i in weapon.bullets_per_shot:
		var spread := weapon.spread_deg * spread_factor()
		var offset := deg_to_rad(_rng.randf_range(-spread, spread) * 0.5)
		var p := Projectile.new()
		p.velocity = dir.rotated(offset) * weapon.projectile_speed
		p.damage = weapon.damage
		p.element = weapon.element
		p.element_damage = weapon.element_damage
		p.max_distance = weapon.max_range
		p.color = weapon.projectile_color
		p.shooter = self
		p.global_position = global_position + dir * 12.0 + Vector2(0, -10)
		world.add_child(p)


func equip(new_weapon: WeaponData) -> void:
	weapon = new_weapon


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= level * XP_PER_LEVEL:
		level += 1
		stat_points += 1  # le joueur choisit la stat (GDD 5.1)


const LINES_HURT := [
	"Aïe !", "Ça mord !", "Pas le visage !", "Lâche-moi, sale bestiole !",
	"Ouille. Ça, je m'en souviendrai.", "Qui a invité ces trucs ?",
]
const LINES_BADLY_HURT := [
	"Je pisse le sang, là.", "Dites à ma famille… ah non, je l'ai oubliée.",
	"Je crois que je vois une lumière.", "Quelqu'un a un pansement ? Un grand ?",
]


func is_alive() -> bool:
	return not _dead


## Vrai si le survivant est sur la place du camp (zone où l'on se soigne),
## autour du centre de son village.
func in_camp() -> bool:
	return IsoGround.in_village(BuildManager.world_to_tile(global_position - village_center))


func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= int(amount)
	if hp_floor > 0:
		hp = maxi(hp, hp_floor)
	_since_hit = 0.0
	_hurt_flash = 0.15
	_spawn_damage_number(amount)
	if hp <= 0:
		hp = 0
		_dead = true
		died.emit(self)
		queue_free()  # mort définitive
		return
	if _hurt_bubble_cd <= 0.0:
		var low := float(hp) / max_hp < HP_LOW
		var lines: Array = LINES_BADLY_HURT if low else LINES_HURT
		if low or _rng.randf() < 0.35:
			_say(lines[_rng.randi_range(0, lines.size() - 1)], 2.0)
			_hurt_bubble_cd = 5.0


## Soin lent au camp, minuteries des blessures.
func _update_health(delta: float) -> void:
	_since_hit += delta
	_hurt_flash = maxf(_hurt_flash - delta, 0.0)
	_hurt_bubble_cd -= delta
	if hp >= max_hp or _since_hit < REGEN_DELAY or thirst <= 0.0 or hunger <= 0.0:
		_regen_acc = 0.0
		return
	if not camp_regen or not in_camp():
		return
	_regen_acc += REGEN_PER_SEC * delta
	if _regen_acc >= 1.0:
		var gain := int(_regen_acc)
		_regen_acc -= gain
		hp = mini(hp + gain, max_hp)


## Un survivant libre gravement blessé rentre se soigner jusqu'à 80 % des PV.
func _going_to_heal() -> bool:
	var ratio := float(hp) / max_hp
	if ratio < HP_LOW and not _healing:
		_healing = true
		_say("Je rentre me soigner !", 2.0)
	elif ratio >= HP_HEALED:
		_healing = false
	return _healing


func _spawn_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = "-%d" % int(round(amount))
	label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 11)
	label.position = Vector2(_rng.randf_range(2, 12), -44)
	label.z_index = 10
	add_child(label)
	var tw := label.create_tween()
	tw.tween_property(label, "position:y", label.position.y - 18, 0.6)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tw.tween_callback(label.queue_free)


func _draw() -> void:
	# Ombre
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, 11.0, Color(0, 0, 0, 0.3))
	if selected:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 2.0)
	elif squad_member:
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, Color(0.4, 0.75, 1.0, 0.75), 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Numéro de membre d'escouade au-dessus de la tête
	if squad_member:
		var p := Vector2(-15, -40)
		draw_circle(p, 5.5, Color(0.15, 0.3, 0.45))
		draw_string(ThemeDB.fallback_font, p + Vector2(-3, 4), str(squad_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	# Corps (placeholder) : vêtement + tête issue de l'apparence
	draw_circle(Vector2(0, -12), 9.0, Color(1, 0.3, 0.25) if _hurt_flash > 0.0 else _body_color)
	if is_hero:
		draw_arc(Vector2(0, -12), 9.0, 0.0, TAU, 20, Color(0.95, 0.75, 0.2), 2.0)
	SurvivorAppearance.draw_face(self, Vector2(0, -26), 7.0, appearance, false)
	# Chargement porté : seau (eau), panier (nourriture), fagot de bûches (bois)
	if carrying > 0:
		if carrying_type == "bois":
			for k in 3:
				var y := -22.0 + k * 3.5
				draw_rect(Rect2(-12, y, 16, 3.5), Color(0.5, 0.33, 0.18) if k % 2 == 0 else Color(0.42, 0.27, 0.14))
				draw_circle(Vector2(-12, y + 1.75), 1.75, Color(0.78, 0.62, 0.4))
			draw_line(Vector2(-6, -23), Vector2(-6, -11), Color(0.3, 0.22, 0.15), 1.0)
		else:
			var col := Color(0.35, 0.65, 0.9) if carrying_type == "eau" else Color(0.75, 0.55, 0.3)
			draw_rect(Rect2(7, -18, 9, 9), Color(0.45, 0.32, 0.2))
			draw_rect(Rect2(8, -17, 7, 3), col)
			draw_arc(Vector2(11.5, -18), 4.5, PI, TAU, 8, Color(0.3, 0.25, 0.2), 1.2)
	# Visée (seulement avec une arme)
	if weapon != null:
		draw_line(Vector2(0, -12), Vector2(0, -12) + aim_dir * 18.0, Color(0.2, 0.15, 0.1), 3.0)
	# Barre de PV
	var w := 24.0
	draw_rect(Rect2(-w / 2, -38, w, 3), Color(0.2, 0, 0))
	var ratio := float(hp) / max_hp
	var bar := Color(0.3, 0.9, 0.3) if ratio >= 0.6 else (Color(0.95, 0.8, 0.2) if ratio >= HP_LOW else Color(0.95, 0.3, 0.25))
	draw_rect(Rect2(-w / 2, -38, w * ratio, 3), bar)
