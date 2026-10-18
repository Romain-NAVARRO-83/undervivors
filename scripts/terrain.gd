class_name Terrain
extends RefCounted
## Relief de la carte et contournement simple.
## Une crête rocheuse coupe la carte en deux (ligne verticale à l'écran,
## x = RIDGE_X) ; un seul passage, centré sur GAP_Y.
## route() renvoie le prochain point de passage pour aller d'un point à un
## autre : si les deux sont de part et d'autre de la crête, on passe d'abord
## par l'entrée du passage. (À remplacer par la navigation de Godot quand la
## carte aura plus d'obstacles.)

const RIDGE_X := 400.0
const GAP_Y := 0.0
const GAP_HALF := 42.0          # demi-largeur du passage
const RIDGE_THICKNESS := 26.0
## Losange de la carte (bords du sol isométrique), sommets haut / droite / bas / gauche.
const MAP_HALF := Vector2(1440, 720)

static var enabled := true


static func side(p: Vector2) -> int:
	return -1 if p.x < RIDGE_X else 1


## Prochain point vers lequel se diriger pour rejoindre `to` depuis `from`.
static func route(from: Vector2, to: Vector2) -> Vector2:
	if not enabled or side(from) == side(to):
		return to
	var s := side(from)
	# Déjà dans l'axe du passage : on traverse vers l'autre côté.
	if absf(from.y - GAP_Y) < GAP_HALF - 10.0 and absf(from.x - RIDGE_X) < 60.0:
		return Vector2(RIDGE_X - s * 60.0, GAP_Y)
	return Vector2(RIDGE_X + s * 50.0, GAP_Y)


## Vrai si le point est dans les limites du sol.
static func inside_map(p: Vector2) -> bool:
	return absf(p.x) / MAP_HALF.x + absf(p.y) / MAP_HALF.y <= 1.0
