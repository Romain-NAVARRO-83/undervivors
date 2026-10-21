class_name MobType
extends Resource
## Type de monstre (GDD 1, Ennemis) : se règle dans l'inspecteur de Godot,
## comme les armes. Les valeurs sont celles du niveau 1 ; le niveau du monstre
## les multiplie (voir Mob.level).

enum Attack { CORPS_A_CORPS, DISTANCE }
## Silhouette placeholder (en attendant les sprites).
enum Shape { RONGEUR, CRACHEUR, COGNEUR, FEU_FOLLET }

## Types disponibles (fichiers data/mobs/<id>.tres).
const TYPE_IDS := ["rongeur", "cracheur", "cogneur", "feu_follet"]
## Tirage pondéré pour les vagues « mixtes ».
const MIX_WEIGHTS := {"rongeur": 5, "feu_follet": 2, "cracheur": 2, "cogneur": 1}

@export var type_name: String = "Rongeur"
@export var attack: Attack = Attack.CORPS_A_CORPS
@export var shape: Shape = Shape.RONGEUR
@export var max_hp: float = 30.0
## Vitesse de déplacement en px/s.
@export var speed: float = 70.0
## Dégâts par attaque (morsure, coup ou crachat).
@export var damage: float = 8.0
## Secondes entre deux attaques.
@export var attack_cooldown: float = 1.2
## Portée d'attaque en px (contact pour le corps à corps).
@export var attack_range: float = 20.0
## Distance à laquelle un monstre à distance cherche à se tenir.
@export var keep_distance: float = 0.0
@export var projectile_speed: float = 230.0
@export var projectile_color: Color = Color(0.6, 0.85, 0.3)
## Dégâts infligés aux constructions par attaque.
@export var building_damage: float = 8.0
@export var xp_reward: int = 20
## Échelle de la silhouette et du corps de collision.
@export var size: float = 1.0
@export var color: Color = Color(0.45, 0.28, 0.5)

@export_group("Éléments")
## Multiplicateur des dégâts élémentaires reçus : 1 = normal,
## < 1 = résistance, > 1 = faiblesse, 0 = immunité (pas d'effet non plus).
@export var fire_mult: float = 1.0
@export var ice_mult: float = 1.0
@export var electric_mult: float = 1.0
@export var poison_mult: float = 1.0


static func by_id(id: String) -> MobType:
	return load("res://data/mobs/%s.tres" % id)


static func random_mixed(rng: RandomNumberGenerator) -> MobType:
	var total := 0
	for k in MIX_WEIGHTS:
		total += MIX_WEIGHTS[k]
	var pick := rng.randi_range(1, total)
	for k in MIX_WEIGHTS:
		pick -= MIX_WEIGHTS[k]
		if pick <= 0:
			return by_id(k)
	return by_id("rongeur")


func element_mult(e: int) -> float:
	match e:
		WeaponData.Element.FEU:
			return fire_mult
		WeaponData.Element.GLACE:
			return ice_mult
		WeaponData.Element.ELECTRIQUE:
			return electric_mult
		WeaponData.Element.POISON:
			return poison_mult
	return 1.0


## Résumé des résistances et faiblesses, pour l'interface.
func element_summary() -> String:
	var parts: Array[String] = []
	for e in [1, 2, 3, 4]:
		var m := element_mult(e)
		var n := WeaponData.element_name(e).to_lower()
		if m == 0.0:
			parts.append("immunisé : %s" % n)
		elif m < 1.0:
			parts.append("résiste : %s" % n)
		elif m > 1.0:
			parts.append("faible : %s" % n)
	return ", ".join(parts)
