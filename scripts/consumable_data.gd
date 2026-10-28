class_name ConsumableData
extends Resource
## Unité de ressource à ramasser (GDD 9) : une bouteille d'eau, une ration…
## Contrairement aux sources continues (mare, cocotiers), on la trouve en
## explorant et en lootant. Elle va dans le sac du survivant ; au feu de camp
## elle rejoint le stock du village. Un survivant qui a soif (ou faim) et qui
## en transporte une la consomme lui-même.

@export var item_name: String = "Bouteille d'eau"
## Ressource du stock : "eau" ou "nourriture".
@export var resource_type: String = "eau"
## Portions : une bouteille désaltère plusieurs fois, une conserve nourrit
## plusieurs fois. Chaque portion vaut une unité du stock (25 points de jauge).
@export var amount: int = 1
## Portions déjà consommées ou déposées (propre à chaque objet ramassé : voir
## instance()).
var used := 0
@export var color: Color = Color(0.45, 0.75, 0.95)


## Portions restantes.
func remaining() -> int:
	return amount - used


## Copie propre à un survivant : la ressource chargée est partagée par tous
## les objets au sol, on ne doit pas entamer celle-là.
func instance() -> ConsumableData:
	var c: ConsumableData = duplicate()
	c.used = 0
	return c


## Nom avec les portions restantes : « Bouteille d'eau (2/3) ».
func label() -> String:
	return item_name if amount <= 1 else "%s (%d/%d)" % [item_name, remaining(), amount]
