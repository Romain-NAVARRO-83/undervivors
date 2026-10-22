class_name SurvivorSprite
extends Sprite2D
## Affichage d'un survivant à partir des planches pré-rendues en 3D
## (assets/survivors, voir tools/bake_survivor_sprites.gd) :
## 8 directions × (repos + 6 images de marche), teintées par le shader selon
## l'apparence (peau, cheveux, vêtement).

const DIR := "res://assets/survivors/"
const COLS := 7
const DIRS := 8
const FEET := Vector2(64, 150)
## Échelle d'affichage (les images font 128 × 160).
const SCALE := 0.36
const WALK_FPS := 10.0          # à 150 px/s ; proportionnel à la vitesse
const STYLE_FILES := {
	SurvivorAppearance.HairStyle.CHAUVE: "chauve",
	SurvivorAppearance.HairStyle.COURT: "court",
	SurvivorAppearance.HairStyle.HERISSE: "herisse",
	SurvivorAppearance.HairStyle.LONG: "long",
	SurvivorAppearance.HairStyle.CHIGNON: "chignon",
}

static var _shader: Shader
static var _cache := {}

var direction := 2               # 0 = est, sens horaire à l'écran ; 2 = face
var _walk_t := 0.0


## Vrai si les planches de cette coiffure existent (sinon : ancien dessin 2D).
static func available(style: int) -> bool:
	return ResourceLoader.exists(DIR + STYLE_FILES.get(style, "court") + "_shade.png")


func setup(a: SurvivorAppearance) -> void:
	var name: String = STYLE_FILES.get(a.hair_style, "court")
	texture = _load(DIR + name + "_shade.png")
	hframes = COLS
	vframes = DIRS
	centered = false
	scale = Vector2(SCALE, SCALE)
	offset = -FEET
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _shader == null:
		_shader = load("res://shaders/survivor_tint.gdshader")
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	var mask_path := DIR + name + "_mask.png"
	if ResourceLoader.exists(mask_path):
		mat.set_shader_parameter("mask_tex", _load(mask_path))
	mat.set_shader_parameter("skin_color", a.skin)
	mat.set_shader_parameter("hair_color", a.hair_color)
	mat.set_shader_parameter("shirt_color", a.shirt_color)
	material = mat
	_update_frame(false)


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]


## Direction (0-7) d'un vecteur de l'écran : on « déplie » l'axe y (sol iso
## écrasé de moitié) pour retrouver l'angle au sol.
static func dir_index(v: Vector2) -> int:
	var a := atan2(v.y * 2.0, v.x)
	return posmod(roundi(a / (PI / 4.0)), DIRS)


## À appeler à chaque image : `facing` = où il regarde, `velocity` = déplacement.
func animate(facing: Vector2, velocity: Vector2, delta: float, hurt: float) -> void:
	if facing.length() > 0.01:
		direction = dir_index(facing)
	var moving := velocity.length() > 8.0
	if moving:
		_walk_t += delta * WALK_FPS * clampf(velocity.length() / 150.0, 0.5, 1.6)
	else:
		_walk_t = 0.0
	_update_frame(moving)
	(material as ShaderMaterial).set_shader_parameter("flash", clampf(hurt / 0.15, 0.0, 1.0))


func _update_frame(moving: bool) -> void:
	var col := 1 + int(_walk_t) % 6 if moving else 0
	frame = direction * COLS + col
