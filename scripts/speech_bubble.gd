class_name SpeechBubble
extends Node2D
## Phylactère au-dessus d'un personnage (GDD 5.5 : dialogues en bulles).
## say(texte, durée) l'affiche puis le fait disparaître en fondu.

const MAX_WIDTH := 150.0
const ANCHOR_Y := -58.0  # pointe de la bulle, au-dessus de la tête

var _panel: PanelContainer
var _label: Label
var _tween: Tween
var _time_left := 0.0
## Ordre d'apparition, pour empiler les bulles proches sans chevauchement.
var _started_at := 0.0
var _lift := 0.0
static var _clock := 0.0


func _ready() -> void:
	z_index = 50
	z_as_relative = false
	visible = false
	add_to_group("bubbles")
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.98, 0.96, 0.9)
	box.border_color = Color(0.12, 0.1, 0.08)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.set_content_margin_all(5)
	_panel.add_theme_stylebox_override("panel", box)
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func is_showing() -> bool:
	return visible and _time_left > 0.0


func text() -> String:
	return _label.text if _label else ""


func say(message: String, duration := 3.0) -> void:
	_label.text = message
	# Retour à la ligne seulement si le texte est trop long.
	var font := _label.get_theme_font("font")
	var w := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	if w > MAX_WIDTH:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.custom_minimum_size = Vector2(MAX_WIDTH, 0)
	else:
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_label.custom_minimum_size = Vector2.ZERO
	_panel.reset_size()
	_time_left = duration
	_clock += 1.0
	_started_at = _clock
	# Les bulles plus anciennes passent devant : elles masquent la queue des
	# bulles empilées au-dessus d'elles.
	z_index = 2000 - (int(_started_at) % 1500)
	visible = true
	modulate.a = 1.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(maxf(duration - 0.4, 0.1))
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	_tween.tween_callback(func(): visible = false)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_time_left -= delta
	var s := _panel.get_combined_minimum_size()
	_panel.size = s
	# Empilement : on monte au-dessus des bulles voisines apparues avant.
	var lift := 0.0
	for b in get_tree().get_nodes_in_group("bubbles"):
		if b == self or not b.visible or b._started_at >= _started_at:
			continue
		var d: Vector2 = b.global_position - global_position
		if absf(d.x) < (s.x + b._panel.size.x) / 2.0 + 4.0 and absf(d.y) < 50.0:
			lift = maxf(lift, b._panel.size.y + 4.0 + b._lift - d.y)
	_lift = lift
	_panel.position = Vector2(-s.x / 2.0, ANCHOR_Y - 6.0 - s.y - _lift)
	queue_redraw()


func _draw() -> void:
	# Queue de la bulle, pointant vers la tête (allongée si la bulle est empilée)
	var tip := Vector2(0, ANCHOR_Y + 4)
	var top := ANCHOR_Y - 8 - _lift
	var pts := PackedVector2Array([Vector2(-4, top), Vector2(4, top), tip])
	draw_colored_polygon(pts, Color(0.98, 0.96, 0.9))
	draw_line(pts[0], tip, Color(0.12, 0.1, 0.08), 2.0)
	draw_line(pts[1], tip, Color(0.12, 0.1, 0.08), 2.0)
