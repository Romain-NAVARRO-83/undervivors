extends SceneTree
## Tests automatisés du mode histoire (prologue « La plage »), sans fenêtre :
##   godot --headless --fixed-fps 60 --path . -s tests/run_story_tests.gd

var _failures := 0
var _checks := 0
var _f := 0
var _p: Node
var _s: Survivor
var _y0 := 0.0
var _x0 := 0.0


func _init() -> void:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	check(menu != null, "le menu titre se charge")
	menu.free()
	_p = load("res://scenes/story.tscn").instantiate()
	root.add_child(_p)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("ÉCHEC : " + msg)


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_s = _p.survivor
		check(_p.get_tree().get_nodes_in_group("survivors").size() == 1, "un seul survivant")
		check(_s.selected, "il est contrôlé directement")
		check(not _s.needs_enabled, "pas de faim ni de soif dans le prologue")
		check(_p.step == _p.Step.WAKE, "on commence au réveil")
	if _f == 420:
		check(_p.step == _p.Step.MOVE, "après le réveil : apprendre à se déplacer")
		check(_s.bubble.is_showing() or _p._wake_line == 3, "monologue du réveil")
		Input.action_press("move_right")
	if _f == 470:
		Input.action_release("move_right")
		check(_p.step == _p.Step.FOLLOW, "en bougeant : longer la butte")
		# La butte bloque vers le nord
		_s.global_position = Vector2(0, BeachMap.butte_y(0) + 70)
		_y0 = BeachMap.butte_y(0)
		Input.action_press("move_up")
	if _f == 560:
		Input.action_release("move_up")
		check(_s.global_position.y > _y0 - 10.0, "la butte est infranchissable (y = %.0f, butte à %.0f)" % [_s.global_position.y, _y0])
		Input.action_press("move_down")
	if _f == 680:
		Input.action_release("move_down")
		check(_s.global_position.y < BeachMap.shore_y(_s.global_position.x) + 30.0, "on ne nage pas : la mer arrête")
		_s.global_position = Vector2(BeachMap.BUTTE_START + 80, 40)
		Input.action_press("move_left")
	if _f == 760:
		Input.action_release("move_left")
		check(_s.global_position.x > BeachMap.BUTTE_START - 40.0, "falaise à l'ouest")
		# Coffre
		_s.global_position = Vector2(-400, 40)
	if _f == 765:
		check(_p.step == _p.Step.CHEST, "objectif : le coffre")
		_p.chest.take_damage(999.0)
	if _f == 770:
		check(_p.step == _p.Step.PICKUP, "coffre cassé : ramasser")
	if _f == 820:
		var pickups: Array = _p.get_tree().get_nodes_in_group("item_pickups")
		check(pickups.size() == 1, "le coffre contient un objet")
		if pickups.size() == 1:
			_s.global_position = pickups[0].global_position
	if _f == 830:
		check(_s.weapon.weapon_name == "Pistolet rouillé", "le pistolet est équipé (%s)" % _s.weapon.weapon_name)
		check(_p.step == _p.Step.FIRST_MOB, "étape suivante : premier monstre")
		# Le premier monstre mord : PV en baisse au contact
		_s.global_position = _p.first_mob.global_position + Vector2(-14, 0)
	if _f == 950:
		check(_s.hp < _s.max_hp, "le monstre du prologue mord (%d PV)" % _s.hp)
		_p.first_mob.take_damage(999.0)
		_s.hp = _s.max_hp
	if _f == 955:
		check(_p.step == _p.Step.DUO, "premier monstre abattu")
		for m in _p.duo:
			m.take_damage(999.0)
	if _f == 960:
		check(_p.step == _p.Step.ROUND_BUTTE, "les deux suivants abattus : contourner la butte")
		# On contourne vraiment la butte à pied : vers l'est, puis le nord.
		_s.global_position = Vector2(BeachMap.BUTTE_END - 120, BeachMap.butte_y(BeachMap.BUTTE_END) + 70)
		Input.action_press("move_right")
	if _f == 1060:
		Input.action_release("move_right")
		Input.action_press("move_up")
	if _f == 1180:
		Input.action_release("move_up")
		check(BeachMap.past_butte(_s.global_position), "au bout de la butte, on passe de l'autre côté (%s)" % _s.global_position)
	if _f == 1185:
		check(_p.step == _p.Step.DONE, "prologue terminé")
	if _f == 1500:
		check(_p._overlay.visible and _p._overlay_title.text == "Fin du prologue", "écran de fin du prologue")
		print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
	return false
