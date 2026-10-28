extends SceneTree
## Tests automatisés du cycle jour/nuit (mode histoire, chapitre 1), sans fenêtre :
##   godot --headless --fixed-fps 60 --path . -s tests/run_daynight_tests.gd

const Story := preload("res://scripts/story/prologue.gd")

var _failures := 0
var _checks := 0
var _f := 0
var _p: Node
var _dn: DayNight
var _q: Array = []
var _o: Survivor        # le survivant qu'on ne dirige pas


func _init() -> void:
	Story.start_chapter = 1
	_p = load("res://scenes/story.tscn").instantiate()
	root.add_child(_p)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("ÉCHEC : " + msg)


func at(frame: int, fn: Callable) -> void:
	_q.append([frame, fn])


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_plan()
	for a in _q.duplicate():
		if a[0] == _f:
			a[1].call()
			_q.erase(a)
	if _q.is_empty() and _f > 2:
		print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
	return false


func _modulate() -> CanvasModulate:
	for c in _p.get_children():
		if c is CanvasModulate:
			return c
	return null


func _plan() -> void:
	_dn = _p.day_night
	check(_dn != null, "le mode histoire a un cycle jour/nuit")
	check(not _dn.is_night() and not Survivor.night, "on commence de jour")
	check(_p._dial != null and _p._dial.day_night == _dn and _p._dial.is_inside_tree(), "cadran du temps en haut de l'écran")
	check(_p._top_bar != null and _p._dial.get_parent().get_parent() == _p._top_bar, "le cadran est dans la barre du haut, avec les stocks")
	_p.stock.add("bois", 3)
	_p.controlled.inventory.append(load("res://data/items/eau.tres").instance())
	_q.append([5, func():
		check(_p._top_bar._slots["bois"].text == "3/20", "barre du haut : bois 3/20 (%s)" % _p._top_bar._slots["bois"].text)
		check(_p._card._bag.survivor == _p.controlled, "la vignette montre le sac du survivant")
		_p.controlled.inventory.clear()
		_p.stock.take("bois", 3)])
	check(absf(DayDial.hour_angle(12.0) + PI / 2.0) < 0.001, "cadran : midi en haut")
	check(_p._card != null and _p._card.survivor == _p.controlled, "vignette du survivant dirigé")
	Mob.harmless = true
	_o = _p.other_of(_p.controlled)
	var f := 10
	# --- Nuit sans cabane : on se serre autour du feu
	at(f, func():
		check(_modulate() != null and _modulate().color == Color.WHITE, "plein jour : pas de teinte")
		_o.global_position = _p.REFUGE_POS + Vector2(260, 60)
		_dn.set_hour(DayNight.DUSK + 0.5))
	f += 5
	at(f, func():
		check(_dn.is_night() and Survivor.night, "21 h 30 : c'est la nuit")
		check(_modulate().color.v < 0.6, "le monde s'assombrit (%.2f)" % _modulate().color.v)
		check(_p.refuge.light.energy > 0.5, "le feu éclaire la nuit"))
	f += 6 * 60
	at(f, func():
		check(not _o.sheltered, "pas encore d'abri : il ne disparaît pas")
		check(_o.global_position.distance_to(_p.REFUGE_POS) < 100.0, "sans abri, il se serre autour du feu (%.0f px)" % _o.global_position.distance_to(_p.REFUGE_POS))
		_dn.set_hour(DayNight.DAWN - 0.005))
	f += 30
	at(f, func():
		check(not _dn.is_night() and _dn.day == 2, "le jour se lève : jour 2 (%d)" % _dn.day)
		# --- La cabane
		var ch: Chapter1 = _p.chapter
		_p.stock.add("bois", Chapter1.WOOD_NEEDED)
		ch._advance(Chapter1.Step.BUILD)
		_p.controlled.global_position = ch.plot_position() + Vector2(60, 40)
		check(ch.try_build(), "chantier lancé")
		ch.cabin.finish())
	f += 5
	at(f, func():
		check(Survivor.shelter == _p.chapter.cabin and Survivor._shelter_ready(), "la cabane devient l'abri"))
	f += 9 * 60
	at(f, func():
		check(_dn.is_night(), "la cabane finie, la nuit tombe (%.1f h)" % _dn.hour))
	f += 8 * 60
	at(f, func():
		check(_o.sheltered and not _o.visible, "le survivant non dirigé est rentré dans la cabane")
		check(not _o.is_in_group("survivors"), "à l'abri, les monstres ne le voient plus")
		check(not _p.controlled.sheltered and _p.controlled.visible, "celui qu'on dirige reste dehors")
		check(_p.get_tree().get_nodes_in_group("mobs").size() > 0, "(il reste des monstres sur l'île)")
		# Tab : on reprend celui qui dort, il ressort
		check(_p.switch_survivor(), "Tab vers le survivant à l'abri"))
	f += 3
	at(f, func():
		var c: Survivor = _p.controlled
		check(c == _o and not c.sheltered and c.visible, "repris en main, il ressort de la cabane")
		check(c.global_position.distance_to(Survivor.shelter.door_position()) < 10.0, "il ressort par la porte")
		_o = _p.other_of(c))
	f += 8 * 60
	at(f, func():
		check(_o.sheltered, "l'autre, à son tour libre, va se coucher")
		# F : l'autre nous suit, même de nuit
		check(_p.toggle_follow(), "F"))
	f += 3
	at(f, func():
		check(not _o.sheltered and _o.following, "un survivant qui nous suit sort et reste avec nous")
		_p.toggle_follow())
	f += 6 * 60
	at(f, func():
		check(_o.sheltered, "renvoyé, il retourne dormir")
		_dn.set_hour(DayNight.DAWN + 0.1))
	f += 3
	at(f, func():
		check(not _o.sheltered and _o.visible and _o.is_in_group("survivors"), "au lever du jour, tout le monde ressort"))
	f += 6 * 60
	at(f, func():
		check(_p._overlay.visible and _p._continue_btn.visible, "fin du chapitre : bouton « Continuer »")
		_p._continue_free_play())
	f += 5
	at(f, func():
		check(not _p._overlay.visible, "« Continuer » : on reste sur l'île")
		# Espace : plus personne n'est dirigé, le temps file jusqu'à l'aube
		_dn.set_hour(14.0)
		var was: Survivor = _p.controlled
		check(_p.release_control(), "Espace : on lâche le survivant")
		check(_p.controlled == null and not was.selected, "aucun survivant dirigé")
		check(_p._card.survivor == null, "la vignette le signale")
		check(_dn.speed > 1.0, "le temps passe plus vite (×%.0f)" % _dn.speed))
	f += 60
	at(f, func():
		check(_dn.hour > 14.2, "une seconde accélérée fait plus d'une demi-heure de jeu (%.2f h)" % _dn.hour)
		var cam: Vector2 = _p.camera.position
		Input.action_press("move_right")
		_q.append([_f + 20, func():
			Input.action_release("move_right")
			check(_p.camera.position.x > cam.x + 50.0, "caméra libre au clavier")]))
	f += 60 * 60
	at(f, func():
		check(_dn.day == 3 and not _dn.is_night(), "l'aube est arrivée (jour %d, %.1f h)" % [_dn.day, _dn.hour])
		check(_dn.speed == 1.0, "à l'aube, le temps reprend son cours normal")
		check(_p.switch_survivor() and _p.controlled != null, "Tab : on reprend un survivant")
		check(_p._card.survivor == _p.controlled, "la vignette le montre")
		Mob.harmless = false)
