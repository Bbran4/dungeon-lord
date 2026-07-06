extends Node2D
class_name TestHarness

## Exercises the full loop: drag a card to build a room, drag a matching
## card onto a room to upgrade it, click a room to sell it, and send a
## hero through the dungeon.
##
## Assumes these are autoload singletons (Project Settings -> Autoload):
## GameManager, EconomyManager, DungeonManager, WaveManager, CombatManager

@onready var dungeon: Dungeon = $Dungeon
@onready var dungeon_grid: DungeonGrid = $Dungeon/DungeonGrid
@onready var gold_label: Label = $CanvasLayer/UI/VBox/GoldLabel
@onready var wave_label: Label = $CanvasLayer/UI/VBox/WaveLabel
@onready var log_text: RichTextLabel = $CanvasLayer/UI/VBox/LogText
@onready var skeleton_card: RoomCard = $CanvasLayer/UI/VBox/Palette/SkeletonCard
@onready var skeleton_upgraded_card: RoomCard = $CanvasLayer/UI/VBox/Palette/SkeletonUpgradedCard

var skeleton_monster_data: MonsterData
var skeleton_room_data: RoomData
var skeleton_room_upgraded_data: RoomData
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

	var elite_skeleton_monster: MonsterData = MonsterData.new()
	elite_skeleton_monster.monster_name = "Elite Skeleton"
	elite_skeleton_monster.max_health = 24
	elite_skeleton_monster.damage = 5
	elite_skeleton_monster.armor = 1

	skeleton_room_upgraded_data = RoomData.new()
	skeleton_room_upgraded_data.room_name = "Skeleton Den"
	skeleton_room_upgraded_data.cost = 90
	skeleton_room_upgraded_data.room_type = "Monster"
	skeleton_room_upgraded_data.monster = elite_skeleton_monster

	skeleton_room_data = RoomData.new()
	skeleton_room_data.room_name = "Skeleton Den"
	skeleton_room_data.cost = 50
	skeleton_room_data.room_type = "Monster"
	skeleton_room_data.monster = skeleton_monster_data
	skeleton_room_data.upgrade_path = skeleton_room_upgraded_data

	test_hero_data = HeroData.new()
	test_hero_data.hero_name = "Test Adventurer"
	test_hero_data.max_health = 20
	test_hero_data.damage = 4
	test_hero_data.armor = 1
	test_hero_data.class_type = "Tank"

	skeleton_card.set_room_data(skeleton_room_data)
	skeleton_upgraded_card.set_room_data(skeleton_room_upgraded_data)


func _connect_signals() -> void:
	EconomyManager.gold_changed.connect(_on_gold_changed)
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_completed.connect(_on_wave_completed)
	CombatManager.combat_finished.connect(_on_combat_finished)
	dungeon.hero_escaped.connect(_on_hero_escaped)
	dungeon.wave_cleared.connect(_on_wave_cleared)

	skeleton_card.drag_started.connect(_on_card_drag_started)
	skeleton_card.drag_ended.connect(_on_card_drag_ended)
	skeleton_upgraded_card.drag_started.connect(_on_card_drag_started)
	skeleton_upgraded_card.drag_ended.connect(_on_card_drag_ended)


func _reset_test() -> void:
	log_text.clear()
	EconomyManager.reset()
	WaveManager.reset()
	DungeonManager.generate_dungeon()
	_on_gold_changed(EconomyManager.gold)
	wave_label.text = "Wave: %d" % WaveManager.current_wave
	_log("Test harness reset. Drag a room card into a highlighted gap to build.")


func _on_card_drag_started(room_data: RoomData) -> void:
	dungeon_grid.show_upgrade_prompts_for(room_data.room_name)


func _on_card_drag_ended() -> void:
	dungeon_grid.hide_upgrade_prompts()


func _on_fight_pressed() -> void:

	var hero_entity: CombatEntity = CombatEntity.new()
	hero_entity.name = "Hero_Sandbox"
	add_child(hero_entity)
	hero_entity.configure(test_hero_data.max_health, test_hero_data.damage, test_hero_data.armor)

	var monster_entity: CombatEntity = CombatEntity.new()
	monster_entity.name = "Monster_Sandbox"
	add_child(monster_entity)
	monster_entity.configure(skeleton_monster_data.max_health, skeleton_monster_data.damage, skeleton_monster_data.armor)

	hero_entity.died.connect(_on_combatant_died)
	monster_entity.died.connect(_on_combatant_died)

	_log("Sandbox combat: %s vs %s" % [hero_entity.name, monster_entity.name])

	CombatManager.begin_combat(hero_entity, monster_entity)

	EconomyManager.award_hero_damage_gold(hero_entity, test_hero_data)

	if is_instance_valid(hero_entity):
		hero_entity.queue_free()
	if is_instance_valid(monster_entity):
		monster_entity.queue_free()


func _on_send_wave_pressed() -> void:
	_log("Sending test hero into the dungeon...")
	dungeon.send_wave([test_hero_data])


func _on_hero_escaped(hero: CombatEntity) -> void:
	_log("%s reached the exit alive! Heroes escaped." % hero.name)


func _on_wave_cleared() -> void:
	_log("Wave cleared (all heroes dealt with).")


func _on_next_wave_pressed() -> void:
	WaveManager.start_next_wave()


func _on_reset_pressed() -> void:
	_reset_test()


func _on_combatant_died(entity: CombatEntity) -> void:
	_log("%s died." % entity.name)


# _on_combat_finished loses its gold-granting branch, logging only:
func _on_combat_finished(winner: CombatEntity, loser: CombatEntity) -> void:

	if not is_instance_valid(winner):
		return

	var loser_name: String = loser.name if is_instance_valid(loser) else "???"
	_log("%s defeated %s." % [winner.name, loser_name])


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
