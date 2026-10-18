class_name WeaponData
extends Resource
## Statistiques d'une arme (voir GDD, section 7).

enum Element { AUCUN, FEU, GLACE, ELECTRIQUE, POISON }

@export var weapon_name: String = "Lance-pierre"
## Dégâts par projectile.
@export var damage: float = 10.0
## Tirs par seconde.
@export var fire_rate: float = 2.0
## Nombre de projectiles par tir (fusil à pompe > 1).
@export var bullets_per_shot: int = 1
## Dispersion totale en degrés.
@export var spread_deg: float = 4.0
@export var projectile_speed: float = 520.0
## Portée maximale en pixels.
@export var max_range: float = 360.0
@export var element: Element = Element.AUCUN
## Dégâts élémentaires ajoutés à chaque projectile.
@export var element_damage: float = 0.0
@export var projectile_color: Color = Color(0.85, 0.8, 0.7)


func cooldown() -> float:
	return 1.0 / max(fire_rate, 0.01)


static func element_name(e: Element) -> String:
	return ["Aucun", "Feu", "Glace", "Électrique", "Poison"][e]
