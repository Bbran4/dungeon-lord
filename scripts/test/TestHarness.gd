extends Node2D
class_name TestHarness

## A playable test scene that exercises the full Milestone 1 loop:
## build the grid, spend gold placing a room, run a combat test,
## and advance waves — all logged on screen.
##
## Assumes these are autoload singletons (Project Settings -> Autoload):
## GameManager, EconomyManager, DungeonManager, WaveManager, CombatManager

@onready var dungeon_grid: DungeonGrid = $DungeonGrid
@onready var gold_label: Label = $CanvasLayer/UI/VBox/GoldLabel
@onready var wave_label: Label = $CanvasLayer/UI/VBox/WaveLabel
@onready var log_text: RichTextLabel = $CanvasLayer/UI/VBox/LogText

const GRID_SIZE: int = 6
const COMBAT_WIN_REWARD: int = 25

var skeleton_monster_data: MonsterData
var skeleton_room_data: RoomData
var test_hero_data: HeroData


func _ready() -> void:
	_build_test_data()
	_connect_signals()
	_reset_test()


func _build_test_data() -> void:

	skeleton_monster_data = MonsterData.new()
	skeleton_monster_data.monster_name = "Skeleton"
	skeleton_monster_data.max_health = 12
	skeleton_monster_data.damage = 3
	skeleton_monster_data.armor = 0
	skeleton_monster_data.attack_speed = 1.0

	skeleton_room_data = RoomData.new()
	skeleton_room_data.room_name = "Skeleton Den"
	skeleton_room_data.cost = 50
	skeleton_room_data.room_type = "Monster"
	skeleton_room_data.monster = skeleton_monster_data
	skeleton_room_data.health = 100

	test_hero_data = HeroData.new()
	test_hero_data.hero_name = "Test Adventurer"
	test_hero_data.max_health = 20
	test_hero_data.damage = 4
	test_hero_data.armor = 1
	test_hero_data.class_type = "Tank"


func _connect_signals() -> void:
	EconomyManager.gold_changed.connect(_on_gold_changed)
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_completed.connect(_on_wave_completed)
	CombatManager.combat_finished.connect(_on_combat_finished)

	GameManager.building_phase_started.connect(func() -> void: _log("Building phase started."))
	GameManager.combat_phase_started.connect(func() -> void: _log("Combat phase started."))
	GameManager.reward_phase_started.connect(func() -> void: _log("Reward phase started."))
	GameManager.game_over.connect(func() -> void: _log("Game over."))


func _reset_test() -> void:
	log_text.clear()
	EconomyManager.reset()
	WaveManager.reset()
	dungeon_grid.build_grid(GRID_SIZE)
	_on_gold_changed(EconomyManager.gold)
	wave_label.text = "Wave: %d" % WaveManager.current_wave
	_log("Test harness reset. Grid size: %d" % GRID_SIZE)


func _find_first_empty_index() -> int:

	for i: int in DungeonManager.rooms.size():
		if DungeonManager.rooms[i] == null:
			return i

	return -1


func _find_first_occupied_index() -> int:

	for i: int in DungeonManager.rooms.size():
		if DungeonManager.rooms[i] != null:
			return i

	return -1


func _on_build_pressed() -> void:

	var index: int = _find_first_empty_index()

	if index == -1:
		_log("No empty room slots available.")
		return

	var placed: bool = dungeon_grid.place_room_at(index, skeleton_room_data)

	if placed:
		_log("Placed '%s' at slot %d for %d gold." % [skeleton_room_data.room_name, index, skeleton_room_data.cost])
	else:
		_log("Could not place room (insufficient gold or invalid slot).")


func _on_remove_pressed() -> void:

	var index: int = _find_first_occupied_index()

	if index == -1:
		_log("No rooms to remove.")
		return

	dungeon_grid.remove_room_at(index)
	_log("Removed room at slot %d." % index)


func _on_fight_pressed() -> void:

	var hero_entity: CombatEntity = CombatEntity.new()
	hero_entity.name = "TestHero"
	hero_entity.max_health = test_hero_data.max_health
	hero_entity.damage = test_hero_data.damage
	hero_entity.armor = test_hero_data.armor

	var monster_entity: CombatEntity = CombatEntity.new()
	monster_entity.name = "TestMonster"
	monster_entity.max_health = skeleton_monster_data.max_health
	monster_entity.damage = skeleton_monster_data.damage
	monster_entity.armor = skeleton_monster_data.armor

	add_child(hero_entity)
	add_child(monster_entity)

	hero_entity.died.connect(_on_combatant_died)
	monster_entity.died.connect(_on_combatant_died)

	_log("Combat started: %s (hp %d) vs %s (hp %d)" % [
		hero_entity.name, hero_entity.max_health,
		monster_entity.name, monster_entity.max_health
	])

	CombatManager.begin_combat(hero_entity, monster_entity)


func _on_next_wave_pressed() -> void:
	WaveManager.start_next_wave()


func _on_reset_pressed() -> void:
	_reset_test()


func _on_combatant_died(entity: CombatEntity) -> void:
	_log("%s died." % entity.name)


func _on_combat_finished(winner: CombatEntity, loser: CombatEntity) -> void:

	if is_instance_valid(winner):

		if winner.name == "TestHero":
			_log("%s wins! Rewarding %d gold." % [winner.name, COMBAT_WIN_REWARD])
			EconomyManager.add_gold(COMBAT_WIN_REWARD)
		else:
			_log("%s wins." % winner.name)

		winner.queue_free()


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Gold: %d" % new_gold


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave: %d" % wave_number
	_log("Wave %d started." % wave_number)


func _on_wave_completed(wave_number: int) -> void:
	_log("Wave %d completed." % wave_number)


func _log(message: String) -> void:
	log_text.append_text(message + "\n")
	print(message)
