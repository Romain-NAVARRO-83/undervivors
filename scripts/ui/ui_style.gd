class_name UIStyle
extends RefCounted
## Palette et styles partagés de l'interface (cartoon sombre).

const BG := Color(0.11, 0.10, 0.09, 0.94)
const TILE := Color(0.17, 0.15, 0.13)
const TILE_HOVER := Color(0.21, 0.18, 0.15)
const BORDER := Color(0.32, 0.27, 0.22)
const ACCENT := Color(0.95, 0.68, 0.25)
const TEXT := Color(0.93, 0.89, 0.82)
const TEXT_DIM := Color(0.66, 0.60, 0.52)
const BAR_BG := Color(0.08, 0.07, 0.06)

const BAR_COLORS := {
	"pv": Color(0.80, 0.30, 0.28),
	"vitesse": Color(0.35, 0.70, 0.85),
	"precision": Color(0.85, 0.75, 0.35),
	"force": Color(0.75, 0.48, 0.30),
	"xp": Color(0.55, 0.45, 0.85),
}


static func box(bg: Color, border := BORDER, radius := 10, border_w := 2, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


static func label(text: String, size := 14, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, size := 14) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_stylebox_override("normal", box(TILE, BORDER, 8, 2, 6))
	b.add_theme_stylebox_override("hover", box(TILE_HOVER, ACCENT, 8, 2, 6))
	b.add_theme_stylebox_override("pressed", box(BG, ACCENT, 8, 2, 6))
	return b
