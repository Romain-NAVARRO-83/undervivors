extends Control
## Menu titre : mode histoire (prologue) ou mode test (bac à sable de
## développement, la scène de prototypage de toutes les mécaniques).

const STORY_SCENE := "res://scenes/story.tscn"
const TEST_SCENE := "res://scenes/main.tscn"

var _t := 0.0


func _ready() -> void:
	InputSetup.register()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title := UIStyle.label("UNDERVIVORS", 56, UIStyle.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	box.add_child(title)
	var sub := UIStyle.label("Personne ne se souvient de rien. C'est peut-être mieux comme ça.", 15, UIStyle.TEXT_DIM)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	box.add_child(spacer)
	_add_button(box, "Histoire", func(): _start_story(0))
	_add_button(box, "Chapitre 1 — L'abri", func(): _start_story(1))
	_add_button(box, "Mode test", func(): get_tree().change_scene_to_file(TEST_SCENE))
	_add_button(box, "Quitter", func(): get_tree().quit())
	var hint := UIStyle.label("Mode test : la carte de prototypage, toutes les mécaniques et le panneau debug (F1).", 12, UIStyle.TEXT_DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)


func _start_story(chapter: int) -> void:
	StoryPrologue.start_chapter = chapter
	get_tree().change_scene_to_file(STORY_SCENE)


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var b := UIStyle.button(text, 20)
	b.custom_minimum_size = Vector2(280, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(action)
	parent.add_child(b)
