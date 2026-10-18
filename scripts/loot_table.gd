class_name LootTable
extends RefCounted
## Tirage du contenu des coffres. Pour l'instant : des armes (les armures
## viendront ensuite). Le poids règle la rareté.

const ENTRIES := [
	# [ressource, poids]
	["res://data/weapons/pistol.tres", 5],
	["res://data/weapons/shotgun.tres", 3],
	["res://data/weapons/taser.tres", 3],
	["res://data/weapons/blowpipe.tres", 3],
	["res://data/weapons/harpoon.tres", 1],
]


## Retourne entre `min_items` et `max_items` objets tirés au hasard.
static func roll(rng: RandomNumberGenerator, min_items := 1, max_items := 3) -> Array[Resource]:
	var total := 0
	for e in ENTRIES:
		total += e[1]
	var out: Array[Resource] = []
	for i in rng.randi_range(min_items, max_items):
		var pick := rng.randi_range(1, total)
		for e in ENTRIES:
			pick -= e[1]
			if pick <= 0:
				out.append(load(e[0]))
				break
	return out


## Nom affichable d'un objet (arme aujourd'hui, armure demain).
static func item_name(item: Resource) -> String:
	if item is WeaponData:
		return item.weapon_name
	return item.resource_name if item.resource_name != "" else "Objet"
