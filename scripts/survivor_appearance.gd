class_name SurvivorAppearance
extends RefCounted
## Apparence aléatoire d'un survivant (GDD 5.2 bis) : un assemblage de pièces
## tirées au hasard, comme les noms. Placeholder dessiné en code ; chaque pièce
## pourra être remplacée par un sprite (forme du visage, coiffure, bouche…).

const SKIN_TONES := [
	Color("f6d5b8"), Color("e8b48f"), Color("c98e62"),
	Color("a0673f"), Color("6e4527"), Color("4a2e1b"),
]
const HAIR_COLORS := [
	Color("1c1712"), Color("3b2a1e"), Color("6b4423"), Color("b5813f"),
	Color("e3c27a"), Color("a8a8a8"), Color("b8402c"), Color("4b5d8a"),
]
const EYE_COLORS := [Color("2b1d14"), Color("3d6b8f"), Color("4f7a3a"), Color("6b5a3a")]
const SHIRT_COLORS := [
	Color("8c3b3b"), Color("3b5f8c"), Color("4f7a4a"), Color("7a6a3a"),
	Color("5a4a7a"), Color("3a6e6e"), Color("8a5a2b"), Color("555a60"),
]

enum FaceShape { ROND, OVALE, CARRE }
enum HairStyle { CHAUVE, COURT, HERISSE, LONG, CHIGNON }
enum Mouth { SOURIRE, NEUTRE, GRIMACE, RICTUS }
enum Accessory { AUCUN, CICATRICE, CACHE_OEIL, PANSEMENT }

var skin: Color = SKIN_TONES[0]
var hair_color: Color = HAIR_COLORS[0]
var eye_color: Color = EYE_COLORS[0]
var shirt_color: Color = SHIRT_COLORS[0]
var face_shape: FaceShape = FaceShape.ROND
var hair_style: HairStyle = HairStyle.COURT
var mouth: Mouth = Mouth.SOURIRE
var accessory: Accessory = Accessory.AUCUN


static func random(rng: RandomNumberGenerator) -> SurvivorAppearance:
	var a := SurvivorAppearance.new()
	a.skin = SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)]
	a.hair_color = HAIR_COLORS[rng.randi_range(0, HAIR_COLORS.size() - 1)]
	a.eye_color = EYE_COLORS[rng.randi_range(0, EYE_COLORS.size() - 1)]
	a.shirt_color = SHIRT_COLORS[rng.randi_range(0, SHIRT_COLORS.size() - 1)]
	a.face_shape = rng.randi_range(0, FaceShape.size() - 1) as FaceShape
	a.hair_style = rng.randi_range(0, HairStyle.size() - 1) as HairStyle
	a.mouth = rng.randi_range(0, Mouth.size() - 1) as Mouth
	# Accessoires plus rares : 60 % sans.
	var roll := rng.randf()
	if roll < 0.6:
		a.accessory = Accessory.AUCUN
	else:
		a.accessory = rng.randi_range(1, Accessory.size() - 1) as Accessory
	return a


## Dessine la tête centrée en `c`, de rayon `r`, sur n'importe quel CanvasItem.
## `detailed` = false pour les petites tailles (dans le monde).
static func draw_face(ci: CanvasItem, c: Vector2, r: float, a: SurvivorAppearance, detailed := true) -> void:
	var w := maxf(1.0, r * 0.09)
	var outline := Color(0.08, 0.06, 0.05)
	# Cheveux longs : derrière le visage.
	if a.hair_style == HairStyle.LONG:
		ci.draw_colored_polygon(_blob(c + Vector2(0, r * 0.3), r * 1.15, r * 1.25), a.hair_color)
	# Visage
	var face: PackedVector2Array
	match a.face_shape:
		FaceShape.OVALE:
			face = _blob(c, r * 0.82, r * 1.05)
		FaceShape.CARRE:
			face = _blob(c, r * 0.95, r, 3.5)
		_:
			face = _blob(c, r, r)
	ci.draw_colored_polygon(face, a.skin)
	var closed := face.duplicate()
	closed.append(face[0])
	ci.draw_polyline(closed, outline, w, true)
	# Cheveux (dessus)
	match a.hair_style:
		HairStyle.COURT, HairStyle.LONG:
			ci.draw_arc(c, r * 0.86, PI * 1.05, PI * 1.95, 20, a.hair_color, r * 0.32, true)
		HairStyle.HERISSE:
			ci.draw_arc(c, r * 0.88, PI * 1.1, PI * 1.9, 20, a.hair_color, r * 0.26, true)
			for i in 5:
				var ang := PI * (1.2 + i * 0.15)
				var base := c + Vector2(cos(ang), sin(ang)) * r * 0.85
				var tip := c + Vector2(cos(ang), sin(ang)) * r * 1.45
				var side := Vector2(-sin(ang), cos(ang)) * r * 0.18
				ci.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), a.hair_color)
		HairStyle.CHIGNON:
			ci.draw_arc(c, r * 0.86, PI * 1.05, PI * 1.95, 20, a.hair_color, r * 0.3, true)
			ci.draw_circle(c + Vector2(0, -r * 1.12), r * 0.36, a.hair_color)
		_:
			pass  # chauve
	# Yeux
	var eye_y := c.y - r * 0.05
	var eyes := [Vector2(c.x - r * 0.36, eye_y), Vector2(c.x + r * 0.36, eye_y)]
	for i in 2:
		if i == 1 and a.accessory == Accessory.CACHE_OEIL:
			continue
		ci.draw_circle(eyes[i], r * 0.2, Color(0.97, 0.95, 0.9))
		ci.draw_circle(eyes[i] + Vector2(r * 0.03, r * 0.02), r * 0.11, a.eye_color)
	if a.accessory == Accessory.CACHE_OEIL:
		ci.draw_line(c + Vector2(-r * 0.95, -r * 0.5), c + Vector2(r * 0.95, r * 0.05), outline, w)
		ci.draw_circle(eyes[1], r * 0.25, outline)
	if detailed:
		# Sourcils
		for i in 2:
			var e: Vector2 = eyes[i]
			var tilt := r * (0.06 if a.mouth == Mouth.GRIMACE else -0.03) * (1 if i == 0 else -1)
			ci.draw_line(e + Vector2(-r * 0.18, -r * 0.3 - tilt), e + Vector2(r * 0.18, -r * 0.3 + tilt), a.hair_color.darkened(0.2), w * 1.3)
		# Bouche
		var m := c + Vector2(0, r * 0.48)
		match a.mouth:
			Mouth.SOURIRE:
				ci.draw_arc(m + Vector2(0, -r * 0.18), r * 0.3, PI * 0.2, PI * 0.8, 12, outline, w)
			Mouth.NEUTRE:
				ci.draw_line(m + Vector2(-r * 0.22, 0), m + Vector2(r * 0.22, 0), outline, w)
			Mouth.GRIMACE:
				ci.draw_arc(m + Vector2(0, r * 0.2), r * 0.28, PI * 1.2, PI * 1.8, 12, outline, w)
			Mouth.RICTUS:
				ci.draw_line(m + Vector2(-r * 0.25, r * 0.05), m + Vector2(r * 0.15, -r * 0.02), outline, w)
				ci.draw_arc(m + Vector2(r * 0.1, -r * 0.12), r * 0.12, PI * 0.1, PI * 0.6, 8, outline, w)
		# Accessoires
		match a.accessory:
			Accessory.CICATRICE:
				var s := c + Vector2(-r * 0.45, r * 0.15)
				ci.draw_line(s + Vector2(-r * 0.12, -r * 0.2), s + Vector2(r * 0.12, r * 0.2), Color(0.6, 0.2, 0.2), w)
				for k in 3:
					var p := s + Vector2(-r * 0.08 + k * r * 0.08, -r * 0.12 + k * r * 0.12)
					ci.draw_line(p + Vector2(-r * 0.06, r * 0.03), p + Vector2(r * 0.06, -r * 0.03), Color(0.6, 0.2, 0.2), w * 0.7)
			Accessory.PANSEMENT:
				var b := c + Vector2(r * 0.3, -r * 0.55)
				ci.draw_set_transform(b, 0.5, Vector2.ONE)
				ci.draw_rect(Rect2(-r * 0.25, -r * 0.08, r * 0.5, r * 0.16), Color(0.93, 0.88, 0.78))
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				pass


## Contour en « super-ellipse » : n = 2 → ellipse, n grand → rectangle arrondi.
static func _blob(c: Vector2, rx: float, ry: float, n := 2.0, steps := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps:
		var t := TAU * i / steps
		var ct := cos(t)
		var st := sin(t)
		var x := pow(absf(ct), 2.0 / n) * rx * signf(ct)
		var y := pow(absf(st), 2.0 / n) * ry * signf(st)
		pts.append(c + Vector2(x, y))
	return pts
