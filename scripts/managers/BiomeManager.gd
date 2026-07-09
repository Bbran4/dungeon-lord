extends Node

## Minimal biome layer. Holds which BiomeData is active for the current
## run and exposes its boss room/pools. This is intentionally NOT the
## full Milestone 8 biome system - room/hero pools per biome aren't
## wired into ShopManager or wave spawning yet.
##
## Autoloads can't have their @export fields set via the editor
## Inspector the way a scene node can, so current_biome is set at
## runtime - see TestHarness.starting_biome / _ready().

signal biome_changed(biome: BiomeData)

var current_biome : BiomeData


func set_biome(biome_data: BiomeData) -> void:
	current_biome = biome_data
	biome_changed.emit(biome_data)


func get_current_boss_room() -> RoomData:
	if current_biome == null:
		return null
	return current_biome.boss_room


func get_current_room_pool() -> Array[RoomData]:
	if current_biome == null:
		return []
	return current_biome.room_pool


func get_current_hero_pool() -> Array[HeroData]:
	if current_biome == null:
		return []
	return current_biome.hero_pool
