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
## Recul : distance (px) dont le tireur est repoussé à chaque tir, en arrière
## de sa visée ; secoue aussi la caméra du survivant dirigé. 0 = aucun recul
## (lance-pierre, sarbacane).
@export_range(0.0, 60.0, 0.5) var recoil: float = 0.0

@export_group("Niveau et rareté")
## Niveau de l'arme (1 à 5) : où on la trouve dans l'aventure.
@export_range(1, 5) var tier: int = 1
## Rareté (0 commune → 4 légendaire) : plus elle est rare, plus elle a d'effets.
@export_range(0, 4) var rarity: int = 0
## Fabricant (armes générées) : biais de stats et petit nom.
@export var brand: String = ""

@export_group("Tir en cloche et zone")
## Tir en cloche (catapulte, mortier) : le projectile vole jusqu'au point visé
## par-dessus les obstacles et explose en touchant le sol.
@export var lob: bool = false
## Rayon d'explosion (px, 0 = pas d'explosion). Dégâts dégressifs au bord.
@export var aoe_radius: float = 0.0

@export_group("Effets spéciaux")
## Ennemis traversés avant de s'arrêter.
@export var pierce: int = 0
## Rebonds sur les obstacles (rochers, arbres, bords).
@export var ricochet: int = 0
## Tête chercheuse : vitesse de virage vers l'ennemi le plus proche (rad/s).
@export var homing: float = 0.0
## Trajectoire ondulante : amplitude (px).
@export var wave: float = 0.0
## À l'impact, se divise en N éclats.
@export var split: int = 0
## Part des dégâts rendue en PV au tireur.
@export var vampire: float = 0.0
## Élément tiré au hasard à chaque tir.
@export var chaos: bool = false
## Revient vers le tireur au bout de sa course (et touche au retour).
@export var boomerang: bool = false
## Taille du projectile (1 = normale).
@export var projectile_size: float = 1.0
## Le projectile est un poisson. Personne ne sait pourquoi.
@export var fish: bool = false
## Effets lisibles (« Rebondit 2 fois »…), remplis par le générateur.
@export var traits: PackedStringArray = []


## Dégâts par seconde théoriques (tous les projectiles touchent), pour comparer.
func dps() -> float:
	return (damage + element_damage) * bullets_per_shot * fire_rate


func cooldown() -> float:
	return 1.0 / max(fire_rate, 0.01)


const RARITY_NAMES := ["Commune", "Peu commune", "Rare", "Épique", "Légendaire"]
const RARITY_COLORS := [Color(0.85, 0.85, 0.82), Color(0.45, 0.85, 0.4), Color(0.35, 0.6, 1.0), Color(0.7, 0.4, 0.95), Color(1.0, 0.65, 0.15)]


func rarity_name() -> String:
	return RARITY_NAMES[clampi(rarity, 0, 4)]


func rarity_color() -> Color:
	return RARITY_COLORS[clampi(rarity, 0, 4)]


## Effets spéciaux en clair (ceux des armes faites à la main sont déduits des
## stats ; ceux des armes générées sont dans `traits`).
func effect_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if lob:
		out.append("Tir en cloche, par-dessus les obstacles")
	if aoe_radius > 0.0:
		out.append("Explose (rayon %d px)" % int(aoe_radius))
	if pierce > 0:
		out.append("Traverse %d ennemi%s" % [pierce, "s" if pierce > 1 else ""])
	if ricochet > 0:
		out.append("Rebondit %d fois" % ricochet)
	if homing > 0.0:
		out.append("Tête chercheuse")
	if wave > 0.0:
		out.append("Trajectoire ondulante")
	if split > 0:
		out.append("Se divise en %d éclats" % split)
	if vampire > 0.0:
		out.append("Vampire : rend %d %% des dégâts en PV" % roundi(vampire * 100.0))
	if chaos:
		out.append("Élément au hasard à chaque tir")
	if boomerang:
		out.append("Revient comme un boomerang")
	if projectile_size > 1.2:
		out.append("Projectiles géants")
	if fish:
		out.append("Tire des poissons")
	for t in traits:
		if not out.has(t):
			out.append(t)
	return out


static func element_color(e: int) -> Color:
	return [Color(0.85, 0.8, 0.7), Color(1.0, 0.5, 0.15), Color(0.55, 0.85, 1.0), Color(0.95, 0.95, 0.35), Color(0.55, 0.85, 0.3)][e]


static func element_name(e: Element) -> String:
	return ["Aucun", "Feu", "Glace", "Électrique", "Poison"][e]
