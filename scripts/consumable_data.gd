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
## Unités de stock que représente l'objet.
@export var amount: int = 1
@export var color: Color = Color(0.45, 0.75, 0.95)
