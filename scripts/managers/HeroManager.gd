extends Node

signal hero_spawned(hero: Node)
signal hero_died(hero: Node)

var active_heroes: Array[Node] = []


func spawn_hero(hero_scene: PackedScene, parent: Node) -> Node:

	var hero: Node = hero_scene.instantiate()

	parent.add_child(hero)

	active_heroes.append(hero)

	hero_spawned.emit(hero)

	return hero


func remove_hero(hero: Node) -> void:

	if not active_heroes.has(hero):
		return

	active_heroes.erase(hero)

	hero_died.emit(hero)

	# Note: intentionally does NOT call hero.queue_free() here.
	# If the hero is a CombatEntity, take_damage() -> die() already
	# frees the node. Calling queue_free() again here caused a
	# double-free / double-signal risk. This function only updates
	# tracking state and notifies listeners.


func clear_heroes() -> void:

	for hero: Node in active_heroes:
		if is_instance_valid(hero):
			hero.queue_free()

	active_heroes.clear()
