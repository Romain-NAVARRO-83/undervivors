class_name WeaponGenerator
extends RefCounted
## Armes aléatoires, à la Borderlands : une arme de base (les .tres de
## data/weapons) + un niveau + une rareté + un fabricant + des effets
## bizarres + parfois un élément. Le nom se compose tout seul :
##   « Fusil d'assaut rouillé à ricochets de feu » (Bricol'Tout, Rare)
## Les légendaires reçoivent en plus un nom propre.
##
## Plus le niveau est haut, plus les bases sont puissantes, plus les stats
## montent et plus les raretés élevées sont probables. Nombre d'effets
## spéciaux = rareté (0 pour une commune, 3 pour une épique ou légendaire).

## Bases possibles : [fichier, niveau à partir duquel elle apparaît].
const BASES := [
	["slingshot", 1], ["nailgun", 1], ["blowpipe", 1],
	["pistol", 2], ["taser", 2], ["shotgun", 2], ["crossbow", 2], ["beach_boomerang", 2],
	["assault_rifle", 3], ["harpoon", 3], ["catapult", 3],
	["sniper", 4], ["military_rifle", 4],
	["mortar", 5], ["heavy_mg", 5],
]

## Fabricants : multiplicateurs de stats et leur « signature ».
const BRANDS := {
	"Rouille & Fils": {"damage": 1.2, "fire_rate": 0.85},
	"Bricol'Tout": {"fire_rate": 1.25, "spread_deg": 1.4},
	"Précis-Mouette": {"spread_deg": 0.5, "max_range": 1.2, "projectile_speed": 1.15},
	"Boum SARL": {"damage": 1.1, "recoil": 1.5, "aoe": 1.3},
	"Coco Arms": {"projectile_speed": 1.25, "damage": 0.95, "fire_rate": 1.1},
	"Épave & Cie": {"damage": 1.05, "max_range": 0.9, "recoil": 0.7},
}

## Effets bizarres : [id, morceau de nom (invariable)].
const TRAITS := [
	["ricochet", "à ricochets"],
	["pierce", "perce-tout"],
	["homing", "à tête chercheuse"],
	["wave", "ondulatoire"],
	["split", "à fragmentation"],
	["vampire", "vampirique"],
	["chaos", "chaotique"],
	["boomerang", "boomerang"],
	["explosive", "à charge explosive"],
	["giant", "XXL"],
	["fish", "à poissons"],
	["burst", "en rafale"],
]

const ELEMENT_SUFFIX := ["", " de feu", " de givre", " électrique", " toxique"]

const LEGENDARY_NAMES := [
	"Le Dernier Mot", "La Mouette Folle", "Tonton Boum", "Le Grand Pardon", "Mémoire Courte",
	"Personne n'est venu", "La Bouteille à la mer", "Ultime Recours", "Le Bricoleur", "Dame Rouille",
]

## Probabilité de rareté (commune → légendaire) au niveau 1 et au niveau 5.
const RARITY_W_LOW := [60.0, 26.0, 10.0, 3.5, 0.5]
const RARITY_W_HIGH := [25.0, 30.0, 25.0, 14.0, 6.0]


## Une arme aléatoire du niveau donné (1 à 5).
static func generate(rng: RandomNumberGenerator, level := 1, forced_rarity := -1) -> WeaponData:
	level = clampi(level, 1, 5)
	# Base : parmi celles disponibles à ce niveau, les plus récentes plus souvent
	var pool: Array = []
	for b in BASES:
		if b[1] <= level:
			for k in b[1]:
				pool.append(b)
	var base_entry: Array = pool[rng.randi_range(0, pool.size() - 1)]
	var base: WeaponData = load("res://data/weapons/%s.tres" % base_entry[0])
	var w: WeaponData = base.duplicate()
	w.tier = level
	w.rarity = forced_rarity if forced_rarity >= 0 else _roll_rarity(rng, level)
	# Montée en puissance avec l'écart de niveau et la rareté, plus un peu de hasard
	var up := 1.0 + 0.22 * (level - int(base_entry[1])) + 0.08 * w.rarity
	w.damage *= up * rng.randf_range(0.9, 1.15)
	w.element_damage *= up
	w.fire_rate *= rng.randf_range(0.9, 1.1)
	w.spread_deg *= rng.randf_range(0.8, 1.2)
	w.max_range *= rng.randf_range(0.95, 1.1)
	# Fabricant
	var brands := BRANDS.keys()
	w.brand = brands[rng.randi_range(0, brands.size() - 1)]
	var b: Dictionary = BRANDS[w.brand]
	for stat in ["damage", "fire_rate", "spread_deg", "max_range", "projectile_speed", "recoil"]:
		if b.has(stat):
			w.set(stat, w.get(stat) * b[stat])
	if b.has("aoe"):
		w.aoe_radius *= b["aoe"]
	# Élément (plus probable sur les armes rares)
	if w.element == WeaponData.Element.AUCUN and rng.randf() < 0.12 + 0.1 * w.rarity:
		w.element = rng.randi_range(1, 4) as WeaponData.Element
		w.element_damage = w.damage * rng.randf_range(0.3, 0.6)
	if w.element != WeaponData.Element.AUCUN:
		w.projectile_color = WeaponData.element_color(w.element)
	# Effets bizarres
	var n_traits := mini(w.rarity, 3)
	var ids := []
	for t in TRAITS:
		ids.append(t)
	var chosen: Array = []
	while chosen.size() < n_traits and not ids.is_empty():
		var t: Array = ids.pop_at(rng.randi_range(0, ids.size() - 1))
		if _compatible(w, t[0]):
			_apply_trait(w, t[0], rng)
			chosen.append(t)
	# Nom
	var name := base.weapon_name
	for i in mini(chosen.size(), 2):
		name += " " + chosen[i][1]
	name += ELEMENT_SUFFIX[w.element]
	if w.rarity >= 4:
		var proper: String = LEGENDARY_NAMES[rng.randi_range(0, LEGENDARY_NAMES.size() - 1)]
		name = "« %s » %s" % [proper, name]
	w.weapon_name = name
	w.resource_name = name
	return w


static func _roll_rarity(rng: RandomNumberGenerator, level: int) -> int:
	var k := (level - 1) / 4.0
	var weights := []
	var total := 0.0
	for i in 5:
		var v := lerpf(RARITY_W_LOW[i], RARITY_W_HIGH[i], k)
		weights.append(v)
		total += v
	var pick := rng.randf() * total
	for i in 5:
		pick -= weights[i]
		if pick <= 0.0:
			return i
	return 0


## Certains effets n'ont pas de sens sur certaines armes.
static func _compatible(w: WeaponData, id: String) -> bool:
	match id:
		"boomerang":
			return not w.lob and w.bullets_per_shot == 1
		"ricochet", "homing", "wave", "pierce", "fish":
			return not w.lob
		"explosive":
			return w.aoe_radius <= 0.0
		"chaos":
			return w.element == WeaponData.Element.AUCUN
		"burst":
			return w.bullets_per_shot == 1 and not w.lob
	return true


static func _apply_trait(w: WeaponData, id: String, rng: RandomNumberGenerator) -> void:
	match id:
		"ricochet":
			w.ricochet += rng.randi_range(1, 3)
		"pierce":
			w.pierce += rng.randi_range(1, 3)
		"homing":
			w.homing = rng.randf_range(2.0, 4.0)
		"wave":
			w.wave = rng.randf_range(10.0, 20.0)
		"split":
			w.split = rng.randi_range(2, 4)
		"vampire":
			w.vampire = rng.randf_range(0.08, 0.2)
		"chaos":
			w.chaos = true
		"boomerang":
			w.boomerang = true
			w.projectile_speed *= 0.75
		"explosive":
			w.aoe_radius = rng.randf_range(35.0, 55.0)
			w.recoil += 4.0
		"giant":
			w.projectile_size = 2.2
			w.projectile_speed *= 0.7
			w.damage *= 1.3
		"fish":
			w.fish = true
			w.damage *= 1.1
			w.traits.append("Ça sent la marée")
		"burst":
			w.bullets_per_shot = 3
			w.spread_deg += 8.0
			w.damage *= 0.6
			w.traits.append("Tire 3 projectiles à la fois")
