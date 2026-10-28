class_name DayNight
extends Node
## Cycle jour/nuit du mode histoire (GDD 1, « Cycle jour/nuit »).
## Une journée de 24 h dure DAY_SECONDS + NIGHT_SECONDS secondes réelles :
## le jour (6 h → 21 h) passe plus lentement que la nuit (21 h → 6 h).
## La teinte du monde suit l'heure (CanvasModulate) ; les lumières créées
## avec make_light() s'allument au crépuscule.
## À la nuit tombée, les survivants libres rentrent à l'abri (voir Survivor).

signal night_started
signal day_started

const DAWN := 6.0          # le jour se lève
const DUSK := 21.0         # la nuit tombe
const DAY_SECONDS := 330.0     # 6 h → 21 h : 5 min 30
const NIGHT_SECONDS := 150.0   # 21 h → 6 h : 2 min 30

## Heure courante (0 → 24).
var hour := 8.0
var day := 1
## Accélérateur (debug, tests). 0 fige l'heure.
var speed := 1.0
var _modulate: CanvasModulate
var _was_night := false
var _lights: Array = []       # [PointLight2D, énergie de base]


func _ready() -> void:
	_modulate = CanvasModulate.new()
	get_parent().add_child.call_deferred(_modulate)
	_was_night = is_night()
	Survivor.night = _was_night
	_apply()


func _exit_tree() -> void:
	# Les autres scènes (mode test, champ de tir) n'ont pas de nuit.
	Survivor.night = false


func is_night() -> bool:
	return hour >= DUSK or hour < DAWN


## Obscurité de 0 (plein jour) à 1 (pleine nuit), avec une transition d'une
## heure de jeu au crépuscule et à l'aube.
func darkness() -> float:
	if hour >= DUSK - 1.0 and hour < DUSK + 1.0:
		return smoothstep(DUSK - 1.0, DUSK + 1.0, hour)
	if hour >= DAWN - 1.0 and hour < DAWN + 1.0:
		return 1.0 - smoothstep(DAWN - 1.0, DAWN + 1.0, hour)
	return 1.0 if is_night() else 0.0


func set_hour(h: float) -> void:
	hour = fposmod(h, 24.0)
	_apply()


## Texte d'horloge : « Jour 1 · 14 h 30 ».
func clock_text() -> String:
	var h := int(hour)
	var m := int((hour - h) * 60.0) / 10 * 10
	return "%s Jour %d · %d h %02d" % ["☾" if is_night() else "☀", day, h, m]


func _process(delta: float) -> void:
	if speed <= 0.0:
		return
	var hours_per_sec := (DUSK - DAWN) / DAY_SECONDS if not is_night() else (24.0 - DUSK + DAWN) / NIGHT_SECONDS
	var before := hour
	hour += delta * speed * hours_per_sec
	if hour >= 24.0:
		hour -= 24.0
	if before < DAWN and hour >= DAWN:
		day += 1
	_apply()


func _apply() -> void:
	var night := is_night()
	if night != _was_night:
		_was_night = night
		Survivor.night = night
		if night:
			night_started.emit()
		else:
			day_started.emit()
	var d := darkness()
	if _modulate:
		var dusk_tint := Color(1.0, 0.78, 0.62)
		var night_tint := Color(0.24, 0.28, 0.48)
		var c := Color.WHITE
		if d < 0.5:
			c = Color.WHITE.lerp(dusk_tint, d * 2.0)
		else:
			c = dusk_tint.lerp(night_tint, (d - 0.5) * 2.0)
		_modulate.color = c
	for l in _lights:
		if is_instance_valid(l[0]):
			l[0].energy = l[1] * d


## Lumière ronde (feu, fenêtre, lampe) qui s'allume avec la nuit.
func make_light(radius: float, color: Color, energy := 1.0) -> PointLight2D:
	var light := PointLight2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	light.texture = tex
	light.texture_scale = radius * 2.0 / 256.0
	light.color = color
	light.blend_mode = Light2D.BLEND_MODE_ADD
	light.energy = energy * darkness()
	_lights.append([light, energy])
	return light
