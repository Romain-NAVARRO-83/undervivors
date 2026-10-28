extends SceneTree
## Tests automatisés du panneau développeur du mode histoire, sans fenêtre :
##   godot --headless --fixed-fps 60 --path . -s tests/run_story_dev_tests.gd

const Story := preload("res://scripts/story/prologue.gd")

var _failures := 0
var _checks := 0
var _f := 0
var _p: Node
var _panel: StoryDevPanel
var _presses := 0


func _init() -> void:
	Story.start_chapter = 0
	_p = load("res://scenes/story.tscn").instantiate()
	root.add_child(_p)


func check(cond: bool, msg: String) -> void:
	_checks += 1
	if not cond:
		_failures += 1
		print("ÉCHEC : " + msg)


func _btn(text: String) -> Button:
	for b in _panel.find_children("*", "Button", true, false):
		if b.text == text:
			return b
	return null


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_panel = _p.dev_panel
		check(_panel != null and not _panel.visible, "panneau développeur présent, fermé")
		var ev := InputEventAction.new()
		ev.action = "toggle_debug"
		ev.pressed = true
		Input.parse_input_event(ev)
	if _f == 4:
		check(_panel.visible, "F1 ouvre le panneau")
		_btn("Midi").pressed.emit()
		check(is_equal_approx(_p.day_night.hour, 12.0), "temps : midi")
		_btn("Pause").pressed.emit()
		check(_p.day_night.speed == 0.0, "temps : pause")
		_btn("×1").pressed.emit()
		_btn("+3 eau").pressed.emit()
		check(_p.stock.get_amount("eau") == 3, "stock : +3 eau")
		_btn("Blesser (−30 PV)").pressed.emit()
		var hurt: int = _p.controlled.hp
		_btn("Soigner").pressed.emit()
		check(_p.controlled.hp == _p.controlled.max_hp and hurt < _p.controlled.max_hp, "blesser puis soigner")
		_btn("Assoiffé et affamé").pressed.emit()
		check(_p.controlled.thirst < 20.0, "assoiffer")
		_btn("Eau et faim pleines").pressed.emit()
		check(_p.controlled.thirst == Survivor.NEED_MAX, "désaltérer")
		_btn("Équiper").pressed.emit()
		check(_p.controlled.weapon != null, "équiper une arme")
		_p.controlled.weapon = null
		_panel._invincible.button_pressed = true
		_p.controlled.take_damage(9999.0)
		check(_p.controlled.is_alive(), "invincible")
		_panel._invincible.button_pressed = false
		_panel._harmless.button_pressed = true
		check(Mob.harmless, "monstres inoffensifs")
	# « Étape suivante » jusqu'au bout du prologue, puis du chapitre 1
	if _f > 10 and _f % 40 == 0 and _presses < 40:
		if _p.chapter != null and _p.chapter.step == Chapter1.Step.DONE:
			_presses = 99
		else:
			_btn("Étape suivante").pressed.emit()
			_presses += 1
	if _f == 2400:
		check(_p.chapter != null, "le prologue se passe jusqu'au chapitre 1")
		check(_p.chapter != null and _p.chapter.step == Chapter1.Step.DONE, "puis tout le chapitre 1 (%s)" % (Chapter1.Step.keys()[_p.chapter.step] if _p.chapter else "-"))
		_btn("Tuer tous les monstres").pressed.emit()
	if _f == 2410:
		var alive := 0
		for m in _p.get_tree().get_nodes_in_group("mobs"):
			if m.is_alive():
				alive += 1
		check(alive == 0, "tuer tous les monstres (%d)" % alive)
		Mob.harmless = false
		print("\n%d vérifications, %d échec(s)" % [_checks, _failures])
		quit(1 if _failures > 0 else 0)
	return false
