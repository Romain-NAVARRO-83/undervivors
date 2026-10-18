class_name WaveManager
extends Node
## Vagues de monstres : apparition groupée sur un bord de la carte.
## Déclenchées depuis le panneau debug, ou automatiquement à intervalle.

signal wave_started(number: int, count: int, direction: String)
signal wave_cleared(number: int)

const DIRECTIONS := {
	"Nord": Vector2(0, -1),
	"Est": Vector2(1, 0),
	"Sud": Vector2(0, 1),
	"Ouest": Vector2(-1, 0),
}
## Distance d'apparition depuis le centre du village (écran iso : moins haut que large).
const SPAWN_DISTANCE := Vector2(620, 340)

var world: Node2D
var village_center := Vector2.ZERO
var wave_number := 0
var auto_waves := false
var auto_interval := 30.0
var _auto_timer := 30.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func alive_count() -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.is_alive():
			n += 1
	return n


## Lance une vague de `count` monstres depuis `direction` ("Aléatoire" ou une clé de DIRECTIONS).
func spawn_wave(count := 5, direction := "Aléatoire") -> Array[Mob]:
	if direction == "Aléatoire" or not DIRECTIONS.has(direction):
		direction = DIRECTIONS.keys()[_rng.randi_range(0, DIRECTIONS.size() - 1)]
	wave_number += 1
	var dir: Vector2 = DIRECTIONS[direction]
	var center := village_center + dir * SPAWN_DISTANCE
	var perp := Vector2(-dir.y, dir.x)
	var mobs: Array[Mob] = []
	for i in count:
		var m := Mob.new()
		m.village_center = village_center
		m.position = center + perp * (i - (count - 1) / 2.0) * 26.0 + dir * _rng.randf_range(-20, 20)
		m.died.connect(_on_mob_died)
		world.add_child(m)
		mobs.append(m)
	wave_started.emit(wave_number, count, direction)
	return mobs


func kill_all() -> void:
	for m in get_tree().get_nodes_in_group("mobs"):
		if m.is_alive():
			m.take_damage(9999.0)


func _on_mob_died(_m: Mob) -> void:
	# Le monstre est encore compté vivant pendant le signal : on vérifie après.
	if alive_count() == 0:
		wave_cleared.emit(wave_number)


func _process(delta: float) -> void:
	if not auto_waves:
		return
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		_auto_timer = auto_interval
		spawn_wave(_rng.randi_range(3, 6))


func time_to_next_auto_wave() -> float:
	return _auto_timer if auto_waves else -1.0


func set_auto(on: bool) -> void:
	auto_waves = on
	_auto_timer = auto_interval
