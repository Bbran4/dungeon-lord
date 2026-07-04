extends Node

signal hero_spawned(hero)
signal hero_died(hero)

var active_heroes: Array = []


func spawn_hero(hero_scene: PackedScene, parent: Node) -> Node:

	var hero = hero_scene.instantiate()

	parent.add_child(hero)

	active_heroes.append(hero)

	hero_spawned.emit(hero)

	return hero


func remove_hero(hero: Node) -> void:

	if not active_heroes.has(hero):
		return

	active_heroes.erase(hero)

	hero_died.emit(hero)

	hero.queue_free()


func clear_heroes() -> void:

	for hero in active_heroes:
		if is_instance_valid(hero):
			hero.queue_free()

	active_heroes.clear()
