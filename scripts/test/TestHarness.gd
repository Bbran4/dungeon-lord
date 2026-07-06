extends Node2D
class_name TestHarness

## Exercises the full loop: drag a card to build a room, drag a matching
## card onto a room to upgrade it, click a room to sell it, and send a
## multi-hero party through the dungeon.
##
## Content is authored as .tres Resources (see resources/) and wired in
## below via @export - TestHarness no longer constructs test data in
## code. Swap these exports in the Inspector to test different content
## without touching this script.
##
## GameManager gates the loop: building actions (insert/upgrade/sell,
## enforced in DungeonGrid) only succeed during BUILDING. Pressing
## "Send Wave" transitions to COMBAT; Dungeon.wave_cleared transitions
## to REWARD, which - with no card draft system yet - immediately loops
## back to a fresh BUILDING phase.
##
## Assumes these are autoload singletons (Project Settings -> Autoload):
## GameManager, EconomyManager, DungeonManager, WaveManager, CombatManager

@onready var dungeon: Dungeon = $Dungeon
@onready var dungeon_grid: DungeonGrid = $Dungeon/DungeonGrid
@onready var gold_label: Label = $CanvasLayer/UI/VBox/GoldLabel
@onready var wave_label: Label = $CanvasLayer/UI/VBox/WaveLabel
@onready var phase_label: Label = $CanvasLayer/UI/VBox/PhaseLabel
@onready var log_text: RichTextLabel = $CanvasLayer/UI/VBox/LogText
@onready var skeleton_card: RoomCard = $CanvasLayer/UI/VBox/Palette/SkeletonCard
@onready var skeleton_upgraded_card: RoomCard = $CanvasLayer/UI/VBox/Palette/SkeletonUpgradedCard
@onready var skeleton_elite_card: RoomCard = $CanvasLayer/UI/VBox/Palette/SkeletonEliteCard
@onready var spike_card: RoomCard = $CanvasLayer/UI/VBox/Palette/SpikeCorridorCard
@onready var send_wave_button: Button = $CanvasLayer/UI/VBox/Buttons/SendWaveButton
@onready var next_wave_button: Button = $CanvasLayer/UI/VBox/Buttons2/NextWaveButton

## Authored content - assign these in the Inspector (or via the scene
## file) to point at .tres resources under res://resources/.
@export var skeleton_room_data: RoomData
@export var skeleton_room_upgraded_data: RoomData
@export var skeleton_room_elite_data: RoomData
@export var spike_corridor_room_data: RoomData
@export var test_hero_data: HeroData

@export var tank_hero_data: HeroData
@export var healer_hero_data: HeroData
@export var ranger_hero_data: HeroData
@export var mage_hero_data: HeroData
@export var rogue_hero_data: HeroData


func _ready() -> void:
	_connect_signals()
	_reset_test()


func _connect_signals() -> void:
	EconomyManager.gold_changed.connect(_on_gold_changed)
	WaveManager.wave_started.connect(_on_wave_started)
	WaveManager.wave_completed.connect(_on_wave_completed)
	CombatManager.group_combat_finished.connect(_on_group_combat_finished)
	dungeon.hero_escaped.connect(_on_hero_escaped)
	dungeon.wave_cleared.connect(_on_wave_cleared)
	dungeon.trap_triggered.connect(_on_trap_triggered)

	GameManager.building_phase_started.connect(_on_building_phase_started)
	GameManager.combat_phase_started.connect(_on_combat_phase_started)
	GameManager.reward_phase_started.connect(_on_reward_phase_started)

	skeleton_card.drag_started.connect(_on_card_drag_started)
	skeleton_card.drag_ended.connect(_on_card_drag_ended)
	skeleton_upgraded_card.drag_started.connect(_on_card_drag_started)
	skeleton_upgraded_card.drag_ended.connect(_on_card_drag_ended)
	skeleton_elite_card.drag_started.connect(_on_card_drag_started)
	skeleton_elite_card.drag_ended.connect(_on_card_drag_ended)
	spike_card.drag_started.connect(_on_card_drag_started)
	spike_card.drag_ended.connect(_on_card_drag_ended)


func _reset_test() -> void:
	log_text.clear()
	EconomyManager.reset()
	WaveManager.reset()
	DungeonManager.generate_dungeon()

	skeleton_card.set_room_data(skeleton_room_data)
	skeleton_upgraded_card.set_room_data(skeleton_room_upgraded_data)
	skeleton_elite_card.set_room_data(skeleton_room_elite_data)
	spike_card.set_room_data(spike_corridor_room_data)

	_on_gold_changed(EconomyManager.gold)
	wave_label.text = "Wave: %d" % WaveManager.current_wave
	_log("Test harness reset. Drag a room card into a highlighted gap to build.")
	GameManager.start_game()


func _on_card_drag_started(room_data: RoomData) -> void:
	dungeon_grid.show_upgrade_prompts_for(room_data)


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
	monster_entity.configure(skeleton_room_data.monster.max_health, skeleton_room_data.monster.damage, skeleton_room_data.monster.armor)

	hero_entity.died.connect(_on_combatant_died)
	monster_entity.died.connect(_on_combatant_died)

	_log("Sandbox combat: %s vs %s" % [hero_entity.name, monster_entity.name])

	await CombatManager.begin_group_combat([hero_entity], [monster_entity])

	EconomyManager.award_hero_damage_gold(hero_entity, test_hero_data)

	if is_instance_valid(hero_entity):
		hero_entity.queue_free()
	if is_instance_valid(monster_entity):
		monster_entity.queue_free()


## Builds a randomized test party: a guaranteed Tank, Healer, and one DPS
## (Mage or Ranger, chosen at random), plus a 4th member of a random
## class drawn from the full roster. Exists to exercise
## Dungeon.send_wave() with a real multi-hero group.
func _build_test_party() -> Array[HeroData]:

	var dps_pool: Array[HeroData] = [ranger_hero_data, mage_hero_data]
	var dps: HeroData = dps_pool[randi() % dps_pool.size()]

	var party: Array[HeroData] = [tank_hero_data, healer_hero_data, dps]

	var full_roster: Array[HeroData] = [
		tank_hero_data, healer_hero_data, ranger_hero_data, mage_hero_data, rogue_hero_data
	]
	party.append(full_roster[randi() % full_roster.size()])

	return party


func _on_send_wave_pressed() -> void:

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		_log("Can't send a wave right now.")
		return

	GameManager.start_combat_phase()

	var party: Array[HeroData] = _build_test_party()
	var names: Array[String] = []

	for hero_data: HeroData in party:
		names.append("%s (%s)" % [hero_data.hero_name, hero_data.class_type])

	_log("Sending party: %s" % ", ".join(names))
	dungeon.send_wave(party)


func _on_hero_escaped(hero: CombatEntity) -> void:
	_log("%s reached the exit alive!" % hero.name)


func _on_wave_cleared() -> void:
	_log("Wave cleared (all heroes dealt with).")
	GameManager.start_reward_phase()


func _on_next_wave_pressed() -> void:

	if GameManager.current_state != GameEnums.GameState.BUILDING:
		return

	WaveManager.start_next_wave()


func _on_reset_pressed() -> void:
	_reset_test()


func _on_combatant_died(entity: CombatEntity) -> void:
	_log("%s died." % entity.name)


func _on_group_combat_finished(heroes_won: bool) -> void:
	if heroes_won:
		_log("The party defeated the room's monsters.")
	else:
		_log("The party was wiped out by the room's monsters.")


func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Gold: %d" % new_gold


func _on_wave_started(wave_number: int) -> void:
	wave_label.text = "Wave: %d" % wave_number
	_log("Wave %d started." % wave_number)


func _on_wave_completed(wave_number: int) -> void:
	_log("Wave %d completed." % wave_number)


func _on_building_phase_started() -> void:
	phase_label.text = "Phase: Building"
	send_wave_button.disabled = false
	next_wave_button.disabled = false
	for card: RoomCard in [skeleton_card, skeleton_upgraded_card, skeleton_elite_card, spike_card]:
		card.disabled = false
		card.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_combat_phase_started() -> void:
	phase_label.text = "Phase: Combat"
	send_wave_button.disabled = true
	next_wave_button.disabled = true
	for card: RoomCard in [skeleton_card, skeleton_upgraded_card, skeleton_elite_card, spike_card]:
		card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_reward_phase_started() -> void:
	phase_label.text = "Phase: Reward"
	_log("Reward phase. (No card draft yet - looping back to building.)")
	WaveManager.complete_wave()
	GameManager.start_building_phase()


func _on_trap_triggered(hero: CombatEntity, trap_data: TrapData) -> void:
	_log("%s triggered %s!" % [hero.name, trap_data.trap_name])


func _log(message: String) -> void:
	log_text.append_text(message + "\n")
	print(message)
