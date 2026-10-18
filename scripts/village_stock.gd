class_name VillageStock
extends Node
## Stock commun du village (GDD 9) : les ressources rapportées au centre.

signal changed(resource_type: String, amount: int)

const LABELS := {"eau": "Eau", "nourriture": "Nourriture"}

var amounts := {"eau": 0, "nourriture": 0}


func add(resource_type: String, amount: int) -> void:
	amounts[resource_type] = amounts.get(resource_type, 0) + amount
	changed.emit(resource_type, amounts[resource_type])


## Retire jusqu'à `amount` unités ; retourne la quantité réellement prise.
func take(resource_type: String, amount: int) -> int:
	var available: int = amounts.get(resource_type, 0)
	var taken := mini(available, amount)
	amounts[resource_type] = available - taken
	if taken > 0:
		changed.emit(resource_type, amounts[resource_type])
	return taken


func get_amount(resource_type: String) -> int:
	return amounts.get(resource_type, 0)
