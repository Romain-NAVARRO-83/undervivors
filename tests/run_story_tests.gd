extends SceneTree
## Tests automatisés du mode histoire (prologue), sans fenêtre :
##   godot --headless --fixed-fps 60 --path . -s tests/run_story_tests.gd

var _failures := 0
var _checks := 0
var _f := 0
var _p: Node
var _s: Survivor
var _a: Survivor
var _y0 := 0.0
var _hp_mark := 0
var _done_frame := -1


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
		_a = _p.friend
		check(_p.controlled == _s and _s.selected, "on contrôle le premier survivant")
		check(_s.weapon == null and _a.weapon == null, "les survivants commencent sans arme")
		check(not _s.needs_enabled, "pas de faim ni de soif dans le prologue")
		check(_p.step == _p.Step.WAKE, "on commence au réveil")
		var beach_mobs := 0
		for m in _p.get_tree().get_nodes_in_group("mobs"):
			if BeachMap.in_butte_span(m.global_position.x) and m.global_position.y > BeachMap.butte_y(m.global_position.x):
				beach_mobs += 1
		check(beach_mobs == 0, "aucun monstre sur la plage")
		check(_p.get_tree().get_nodes_in_group("chests").is_empty(), "pas de coffre sur la plage")
	if _f == 420:
		check(_p.step == _p.Step.MOVE, "après le réveil : apprendre à se déplacer")
		Input.action_press("move_right")
	if _f == 470:
		Input.action_release("move_right")
		check(_p.step == _p.Step.FOLLOW_BUTTE, "en bougeant : longer la butte")
		check(_p._arrow.target == _p.FRIEND_POS, "la flèche montre la direction")
		# Butte, mer et falaise bloquent
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
		# Au bout de la butte, on la contourne à pied et on rencontre l'ami.
		_s.global_position = Vector2(BeachMap.BUTTE_END - 120, BeachMap.butte_y(BeachMap.BUTTE_END) + 70)
		Input.action_press("move_right")
	if _f == 860:
		Input.action_release("move_right")
		Input.action_press("move_up")
	if _f == 960:
		Input.action_release("move_up")
		check(BeachMap.past_butte(_s.global_position), "au bout de la butte, on passe de l'autre côté (%s)" % _s.global_position)
		check(_p.step == _p.Step.MEET, "rencontre du second survivant")
	if _f == 960 + 480:
		check(_p.step == _p.Step.TO_REFUGE and _a.following, "il se joint à nous et nous suit")
		check(_p.controlled == _s, "pas de changement de survivant pour l'instant")
		Input.action_press("move_left")
	if _f == 960 + 540:
		Input.action_release("move_left")
	if _f == 960 + 620:
		check(_a.global_position.distance_to(_s.global_position) < 70.0, "l'ami suit de près (%.0f px)" % _a.global_position.distance_to(_s.global_position))
		# Embuscade en entrant dans la zone des monstres
		_s.global_position = Vector2(880, -380)
		_a.global_position = Vector2(900, -340)
	if _f == 960 + 700:
		check(_p._ambushed, "embuscade déclenchée")
		check(_a.hp < _a.max_hp and _p._ambush_bitten, "l'ami est blessé (%d PV)" % _a.hp)
		_a.take_damage(999.0)
		check(_a.is_alive() and _a.hp == _a.hp_floor, "l'ami ne peut pas mourir pendant le prologue (%d PV)" % _a.hp)
		# Arrivée au refuge
		_s.global_position = _p.REFUGE_POS + Vector2(60, 40)
		_a.global_position = _p.REFUGE_POS + Vector2(90, 50)
	if _f == 960 + 705:
		check(_p.step == _p.Step.REFUGE, "arrivée au refuge")
		check(not _a.following and _p.refuge.lit, "l'ami reste au refuge, le feu est rallumé")
		_hp_mark = _a.hp
	if _f == 960 + 1300:
		check(_p.step == _p.Step.FIND_WATER, "objectif : trouver de l'eau")
		check(_a.in_camp() and _a.hp > _hp_mark, "l'ami se soigne au refuge (%d → %d PV)" % [_hp_mark, _a.hp])
		check(_a.thirst < Survivor.NEED_LOW, "l'ami a soif")
		check(_p.get_tree().get_nodes_in_group("resource_nodes").is_empty(), "pas de source d'eau continue : des unités à trouver")
		# On ramasse les deux bouteilles en passant dessus
		_s.global_position = _p.WATER_POS[0]
	if _f == 960 + 1350:
		check(_p.water_found() == 1, "première bouteille ramassée (%d)" % _p.water_found())
		_s.global_position = _p.WATER_POS[1]
	if _f == 960 + 1400:
		check(_p.water_found() == 2 and _p.step == _p.Step.BRING_WATER, "deux unités d'eau : les rapporter")
		check(_s.inventory.size() == 2, "elles sont dans le sac")
		_s.global_position = _p.REFUGE_POS + Vector2(10, 5)
	if _f == 960 + 1410:
		check(_p.stock.get_amount("eau") >= 1 or _p.stock.total_added.get("eau", 0) == 2, "déposées au stock du refuge")
		check(_s.inventory.is_empty(), "sac vidé au feu de camp")
	if _f == 960 + 1900:
		check(_a.thirst >= Survivor.NEED_LOW, "l'ami est venu boire (soif %.0f)" % _a.thirst)
		check(_p.step == _p.Step.SWITCH, "étape : premier changement de survivant")
		_p.switch_survivor()
		check(_p.controlled == _a and _a.selected and not _s.selected, "on dirige maintenant l'ami")
	if _f > 960 + 1900 and _done_frame < 0 and _p.step == _p.Step.DONE:
		_done_frame = _f
	if _f == 960 + 3000:
		check(_done_frame > 0, "la première eau termine le prologue")
		check(_p._overlay.visible and _p._overlay_title.text == "Fin du prologue", "écran de fin du prologue")
		print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
	return false
