class_name VillageStock
extends Node
## Stock commun du village (GDD 9) : les ressources rapportées au centre.

signal changed(resource_type: String, amount: int)

const LABELS := {"eau": "Eau", "nourriture": "Nourriture"}

var amounts := {"eau": 0, "nourriture": 0}
## Stock d'objets commun (armes, armures…), alimenté au feu de camp.
var items: Array[Resource] = []
signal items_changed

## Totaux cumulés depuis le début (statistiques, tests).
var total_added := {}
var total_taken := {}


func add(resource_type: String, amount: int) -> void:
	amounts[resource_type] = amounts.get(resource_type, 0) + amount
	total_added[resource_type] = total_added.get(resource_type, 0) + amount
	changed.emit(resource_type, amounts[resource_type])


## Retire jusqu'à `amount` unités ; retourne la quantité réellement prise.
func take(resource_type: String, amount: int) -> int:
	var available: int = amounts.get(resource_type, 0)
	var taken := mini(available, amount)
	amounts[resource_type] = available - taken
	total_taken[resource_type] = total_taken.get(resource_type, 0) + taken
	if taken > 0:
		changed.emit(resource_type, amounts[resource_type])
	return taken


func add_item(item: Resource) -> void:
	items.append(item)
	items_changed.emit()


## Retire un exemplaire de l'objet ; false s'il n'est pas en stock.
func remove_item(item: Resource) -> bool:
	var i := items.find(item)
	if i < 0:
		return false
	items.remove_at(i)
	items_changed.emit()
	return true


func count_item(item: Resource) -> int:
	return items.count(item)


## Objets distincts du stock, dans l'ordre d'arrivée.
func distinct_items() -> Array[Resource]:
	var out: Array[Resource] = []
	for it in items:
		if not out.has(it):
			out.append(it)
	return out


func get_amount(resource_type: String) -> int:
	return amounts.get(resource_type, 0)
