extends SceneTree
## Tests automatisés du champ de tir, sans fenêtre :
##   godot --headless --fixed-fps 60 --path . -s tests/run_range_tests.gd

var _failures := 0
var _checks := 0
var _f := 0
var _r: Node
var _s: Survivor
var _mob: Mob
var _hp0 := 0.0
var _menu: Node


func _init() -> void:
	_menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(_menu)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("ÉCHEC : " + msg)


func _aim_at(target: Node2D) -> Vector2:
	# Les tirs partent 10 px au-dessus des pieds : on vise le même plan.
	return (target.global_position - _s.global_position).normalized()


func _process(_d: float) -> bool:
	_f += 1
	if _f == 1:
		var found := false
		for b in _menu.find_children("*", "Button", true, false):
			if b.text == "Champ de tir":
				found = true
		check(found, "le menu titre a un bouton « Champ de tir »")
		_menu.queue_free()
		_r = load("res://scenes/range.tscn").instantiate()
		root.add_child(_r)
		return false
	if _f == 2:
		_s = _r.survivor
		var n := DirAccess.get_files_at("res://data/weapons/").size()
		check(_r.weapons.size() >= 6 and _r.weapons.size() <= n, "toutes les armes sont proposées (%d)" % _r.weapons.size())
		check(_r.weapons[0].resource_path == Survivor.SLINGSHOT_PATH, "le lance-pierre en premier")
		check(_s.weapon == _r.weapons[0], "on commence au lance-pierre")
		check(_r.dummies.size() == 5, "quatre mannequins en rang et un mobile")
		check(Mob.harmless, "monstres inoffensifs par défaut")
	# Tir au lance-pierre sur le mannequin à 100 px
	if _f >= 10 and _f < 70:
		_s.try_shoot(_aim_at(_r.dummies[0]))
	if _f == 100:
		check(_r.shots == 2, "tirs comptés : 2 en 1 s au lance-pierre (%d)" % _r.shots)
		check(_r.hits == _r.shots, "le mannequin à 100 px est touché (%d/%d)" % [_r.hits, _r.shots])
		check(_r.total_damage > 0.0 and _r.dps() > 0.0, "dégâts et dégâts/s comptés (%.0f, %.1f/s)" % [_r.total_damage, _r.dps()])
		check(_r.dummies[0].dps() > 0.0, "le mannequin affiche ses dégâts/s")
		check(_s.hp > 0, "on ne meurt pas au champ de tir")
		# Touche 3 : on change d'arme, les compteurs repartent à zéro
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_3
		ev.pressed = true
		Input.parse_input_event(ev)
	if _f == 104:
		check(_s.weapon == _r.weapons[2], "touche 3 : troisième arme")
		check(_r.shots == 0 and _r.total_damage == 0.0, "compteurs remis à zéro au changement d'arme")
		_mob = _r.spawn_mob("cogneur")
		_mob.set_physics_process(false)
	if _f == 110:
		_hp0 = _mob.hp
		_s.global_position = _mob.global_position + Vector2(-90, 0)
	if _f >= 112 and _f < 160:
		if is_instance_valid(_mob):
			_s.try_shoot(_aim_at(_mob))
	if _f == 200:
		check(not is_instance_valid(_mob) or _mob.hp < _hp0, "un monstre apparu se fait toucher")
		check(_r.hits > 0 and _r.total_damage > 0.0, "les touches sur monstre comptent (%d, %.0f)" % [_r.hits, _r.total_damage])
		_r.clear_mobs()
	if _f == 205:
		var alive := 0
		for m in _r.get_tree().get_nodes_in_group("mobs"):
			if not m.is_queued_for_deletion():
				alive += 1
		check(alive == 0, "« Retirer les monstres »")
		print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
	return false
