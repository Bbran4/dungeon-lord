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
## to REWARD on a full wipe (opening the shop) or back to BUILDING on
## an escape (retry the same wave, no shop).
##
## WAVE SCALING: the wave "tier" (WaveManager.current_wave) only
## advances when the Dungeon Lord fully wipes the incoming party (see
## _on_wave_cleared). Escaping heroes send the same-strength party
## again next time. The Next Wave button no longer drives this - it's
## kept as an inert placeholder since tier progression is now entirely
## outcome-driven.
##
## SHOP-BOUGHT ROOMS are placed via dynamically-created cards, not a
## single reusable slot - see _on_room_purchased/_on_room_placed_free/
## _pending_room_cards. Buying (or pack-winning) multiple rooms adds
## multiple cards side by side; nothing overwrites anything.
##
## Assumes these are autoload singletons (Project Settings -> Autoload):
## GameManager, EconomyManager, DungeonManager, WaveManager, CombatManager,
## HeroManager, PassiveManager, ShopManager

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
@onready var poison_arrow_card: RoomCard = $CanvasLayer/UI/VBox/Palette/PoisonArrowCard
@onready var sanctuary_card: RoomCard = $CanvasLayer/UI/VBox/Palette/SanctuaryCard
@onready var shop_panel: Panel = $CanvasLayer/UI/ShopPanel
@onready var shop_room_buttons: Array[Button] = [
	$CanvasLayer/UI/ShopPanel/VBox/RoomButtons/RoomButton0,
	$CanvasLayer/UI/ShopPanel/VBox/RoomButtons/RoomButton1,
	$CanvasLayer/UI/ShopPanel/VBox/RoomButtons/RoomButton2,
]
@onready var shop_passive_buttons: Array[Button] = [
	$CanvasLayer/UI/ShopPanel/VBox/PassiveButtons/PassiveButton0,
	$CanvasLayer/UI/ShopPanel/VBox/PassiveButtons/PassiveButton1,
	$CanvasLayer/UI/ShopPanel/VBox/PassiveButtons/PassiveButton2,
]
@onready var shop_pack_button: Button = $CanvasLayer/UI/ShopPanel/VBox/ExtrasButtons/PackButton
@onready var shop_reroll_button: Button = $CanvasLayer/UI/ShopPanel/VBox/ExtrasButtons/RerollButton
@onready var shop_continue_button: Button = $CanvasLayer/UI/ShopPanel/VBox/ContinueButton
@onready var palette: HBoxContainer = $CanvasLayer/UI/VBox/Palette

## Authored content - assign these in the Inspector (or via the scene
## file) to point at .tres resources under res://resources/.
@export var skeleton_room_data: RoomData
@export var skeleton_room_upgraded_data: RoomData
@export var skeleton_room_elite_data: RoomData
@export var spike_corridor_room_data: RoomData
@export var test_hero_data: HeroData
@export var poison_arrow_room_data: RoomData
@export var sanctuary_room_data: RoomData

@export var tank_hero_data: HeroData
@export var healer_hero_data: HeroData
@export var ranger_hero_data: HeroData
@export var mage_hero_data: HeroData
@export var rogue_hero_data: HeroData

const ROOM_CARD_SCRIPT: Script = preload("res://scripts/rooms/RoomCard.gd")

## Dynamically-created cards for shop-bought / pack-won rooms - see
## _on_room_purchased / _on_room_placed_free.
var _pending_room_cards: Array[RoomCard] = []


func _ready() -> void:
	_connect_signals()
	_reset_test()


func _connect_signals() -> void:
	EconomyManager.gold_changed.connect(_on_gold_changed)
	WaveManager.wave_completed.connect(_on_wave_completed)
	CombatManager.group_combat_finished.connect(_on_group_combat_finished)
	CombatManager.ability_used.connect(_on_ability_used)
	dungeon.hero_escaped.connect(_on_hero_escaped)
	dungeon.wave_cleared.connect(_on_wave_cleared)
	dungeon.trap_triggered.connect(_on_trap_triggered)
	dungeon_grid.room_placed_free.connect(_on_room_placed_free)

	GameManager.building_phase_started.connect(_on_building_phase_started)
	GameManager.combat_phase_started.connect(_on_combat_phase_started)
	GameManager.reward_phase_started.connect(_on_reward_phase_started)
	GameManager.victory_started.connect(_on_victory_started)

	skeleton_card.drag_started.connect(_on_card_drag_started)
	skeleton_card.drag_ended.connect(_on_card_drag_ended)
	skeleton_upgraded_card.drag_started.connect(_on_card_drag_started)
	skeleton_upgraded_card.drag_ended.connect(_on_card_drag_ended)
	skeleton_elite_card.drag_started.connect(_on_card_drag_started)
	skeleton_elite_card.drag_ended.connect(_on_card_drag_ended)
	spike_card.drag_started.connect(_on_card_drag_started)
	spike_card.drag_ended.connect(_on_card_drag_ended)
	poison_arrow_card.drag_started.connect(_on_card_drag_started)
	poison_arrow_card.drag_ended.connect(_on_card_drag_ended)
	sanctuary_card.drag_started.connect(_on_card_drag_started)
	sanctuary_card.drag_ended.connect(_on_card_drag_ended)

	ShopManager.shop_opened.connect(_on_shop_opened)
	ShopManager.shop_closed.connect(_on_shop_closed)
	ShopManager.offers_refreshed.connect(_refresh_shop_ui)
	ShopManager.room_purchased.connect(_on_room_purchased)
	ShopManager.passive_purchased.connect(_on_passive_purchased)
	ShopManager.pack_opened.connect(_on_pack_opened)

	for i: int in shop_room_buttons.size():
		shop_room_buttons[i].pressed.connect(_on_buy_room_pressed.bind(i))
	for i: int in shop_passive_buttons.size():
		shop_passive_buttons[i].pressed.connect(_on_buy_passive_pressed.bind(i))

	shop_pack_button.pressed.connect(_on_buy_pack_pressed)
	shop_reroll_button.pressed.connect(_on_reroll_pressed)
	shop_continue_button.pressed.connect(_on_shop_continue_pressed)


func _reset_test() -> void:
	log_text.clear()
	EconomyManager.reset()
	PassiveManager.reset()
	WaveManager.reset()
	DungeonManager.generate_dungeon()

	shop_panel.visible = false

	for card: RoomCard in _pending_room_cards:
		if is_instance_valid(card):
			card.queue_free()
	_pending_room_cards.clear()

	skeleton_card.set_room_data(skeleton_room_data)
	skeleton_upgraded_card.set_room_data(skeleton_room_upgraded_data)
	skeleton_elite_card.set_room_data(skeleton_room_elite_data)
	spike_card.set_room_data(spike_corridor_room_data)
	poison_arrow_card.set_room_data(poison_arrow_room_data)
	sanctuary_card.set_room_data(sanctuary_room_data)

	_on_gold_changed(EconomyManager.gold)
	_update_wave_label(WaveManager.current_wave)
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
	hero_entity.configure(test_hero_data.max_health, test_hero_data.damage, test_hero_data.armor, test_hero_data.attack_speed, test_hero_data.abilities)
	hero_entity.is_melee = test_hero_data.is_melee
	hero_entity.projectile_color = test_hero_data.projectile_color

	var monster_entity: CombatEntity = CombatEntity.new()
	monster_entity.name = "Monster_Sandbox"
	add_child(monster_entity)
	monster_entity.configure(skeleton_room_data.monster.max_health, skeleton_room_data.monster.damage, skeleton_room_data.monster.armor, skeleton_room_data.monster.attack_speed, skeleton_room_data.monster.abilities)
	monster_entity.is_melee = skeleton_room_data.monster.is_melee
	monster_entity.projectile_color = skeleton_room_data.monster.projectile_color

	hero_entity.died.connect(_on_combatant_died)
	monster_entity.died.connect(_on_combatant_died)

	_log("Sandbox combat: %s vs %s" % [hero_entity.name, monster_entity.name])

	await CombatManager.begin_group_combat([hero_entity], [monster_entity])

	EconomyManager.award_hero_damage_gold(hero_entity, test_hero_data.gold_value)

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

	var multiplier: float = WaveManager.current_stat_multiplier()
	_log("Sending party (x%.2f stats): %s" % [multiplier, ", ".join(names)])
	dungeon.send_wave(party)


func _on_hero_escaped(hero: CombatEntity) -> void:
	_log("%s reached the exit alive! Heroes escaped." % hero.name)


## full_wipe comes straight from Dungeon.wave_cleared - true only if
## every hero in the wave died with none escaping. A full wipe both
## advances WaveManager's tier AND is what opens the shop; an escape
## sends the player straight back to Building to retry the same wave -
## no shop, since nothing was actually won.
func _on_wave_cleared(full_wipe: bool) -> void:

	if full_wipe:
		_log("Full wipe! The dungeon holds - the next wave will be stronger.")
	else:
		_log("Some heroes escaped. The dungeon must hold before growing stronger.")

	WaveManager.complete_wave(full_wipe)

	if full_wipe and WaveManager.is_at_max_wave():
		GameManager.start_victory()
		return

	if full_wipe:
		GameManager.start_reward_phase()
	else:
		GameManager.start_building_phase()


## Terminal - nothing re-enables these controls except a full reset.
## Uses _all_room_cards() (not a hardcoded list) so shop-bought cards
## get locked too, not just the six original palette cards.
func _on_victory_started() -> void:
	phase_label.text = "Phase: VICTORY"
	send_wave_button.disabled = true
	next_wave_button.disabled = true
	for card: RoomCard in _all_room_cards():
		card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log("🏆 VICTORY! The dungeon held through wave %d!" % WaveManager.max_wave)


func _on_next_wave_pressed() -> void:
	# Wave tier now advances automatically based on combat outcome (see
	# _on_wave_cleared) rather than a manual click - full wipe advances
	# it, an escape does not. Kept as an inert button for now.
	_log("Wave tier advances automatically based on combat outcome now.")


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


func _on_wave_completed(wave_number: int, full_wipe: bool) -> void:
	_update_wave_label(wave_number)
	_log("Wave %d completed (%s)." % [wave_number, "full wipe" if full_wipe else "escape"])


func _update_wave_label(wave_number: int) -> void:
	wave_label.text = "Wave: %d (x%.2f)" % [wave_number, WaveManager.current_stat_multiplier()]


func _on_building_phase_started() -> void:
	phase_label.text = "Phase: Building"
	send_wave_button.disabled = false
	next_wave_button.disabled = false
	for card: RoomCard in _all_room_cards():
		card.disabled = false
		card.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_combat_phase_started() -> void:
	phase_label.text = "Phase: Combat"
	send_wave_button.disabled = true
	next_wave_button.disabled = true
	for card: RoomCard in _all_room_cards():
		card.disabled = true
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_reward_phase_started() -> void:
	phase_label.text = "Phase: Reward"
	_log("Wave cleared! Opening the shop...")
	ShopManager.open_shop()


func _on_trap_triggered(hero: CombatEntity, trap_data: TrapData) -> void:
	_log("%s triggered %s!" % [hero.name, trap_data.trap_name])


func _on_ability_used(message: String) -> void:
	_log(message)


func _on_shop_opened() -> void:
	shop_panel.visible = true
	_refresh_shop_ui()


func _on_shop_closed() -> void:
	shop_panel.visible = false


func _refresh_shop_ui() -> void:

	for i: int in shop_room_buttons.size():
		if i >= ShopManager.room_offers.size():
			shop_room_buttons[i].visible = false
			continue
		shop_room_buttons[i].visible = true
		var room_data: RoomData = ShopManager.room_offers[i]
		var price: int = ShopManager.get_price("room", i)
		var sale: String = " ★SALE★" if ShopManager.discount_category == "room" and ShopManager.discount_index == i else ""
		shop_room_buttons[i].text = "%s\n%dg%s" % [room_data.room_name, price, sale]
		shop_room_buttons[i].disabled = ShopManager.room_bought[i]

	for i: int in shop_passive_buttons.size():
		if i >= ShopManager.passive_offers.size():
			shop_passive_buttons[i].visible = false
			continue
		shop_passive_buttons[i].visible = true
		var passive_data: PassiveData = ShopManager.passive_offers[i]
		var price: int = ShopManager.get_price("passive", i)
		var sale: String = " ★SALE★" if ShopManager.discount_category == "passive" and ShopManager.discount_index == i else ""
		shop_passive_buttons[i].text = "%s\n%dg%s" % [passive_data.passive_name, price, sale]
		shop_passive_buttons[i].disabled = ShopManager.passive_bought[i]

	shop_pack_button.text = "Card Pack (%dg)" % ShopManager.pack_cost

	if ShopManager.has_reroll_remaining():
		shop_reroll_button.text = "Reroll (%dg)" % ShopManager.get_reroll_cost()
		shop_reroll_button.disabled = false
	else:
		shop_reroll_button.text = "Reroll (used)"
		shop_reroll_button.disabled = true


func _on_buy_room_pressed(index: int) -> void:
	if not ShopManager.buy_room(index):
		_log("Can't buy that room right now.")
		return
	_refresh_shop_ui()


func _on_buy_passive_pressed(index: int) -> void:
	if not ShopManager.buy_passive(index):
		_log("Can't buy that passive right now.")
		return
	_refresh_shop_ui()


func _on_buy_pack_pressed() -> void:
	if not ShopManager.buy_pack():
		_log("Not enough gold for a card pack.")


func _on_reroll_pressed() -> void:
	if not ShopManager.reroll():
		_log("Not enough gold to reroll.")


func _on_shop_continue_pressed() -> void:
	ShopManager.close_shop()
	GameManager.start_building_phase()


## Fires for a shop room purchase AND a card pack's free-room win.
## Creates a brand-new card each time - buying multiple rooms adds
## multiple cards side by side, nothing gets overwritten.
func _on_room_purchased(room_data: RoomData) -> void:

	var card: Button = Button.new()
	card.set_script(ROOM_CARD_SCRIPT)
	card.custom_minimum_size = Vector2(120, 60)
	palette.add_child(card)
	card.set_room_data(room_data)

	var in_building: bool = GameManager.current_state == GameEnums.GameState.BUILDING
	card.disabled = not in_building
	card.mouse_filter = Control.MOUSE_FILTER_STOP if in_building else Control.MOUSE_FILTER_IGNORE

	_pending_room_cards.append(card)

	_log("Got %s (free)! Drag it into the dungeon to place it." % room_data.room_name)


## Fired by DungeonGrid the instant a free-credit room is actually
## placed. Removes exactly one matching pending card - which one
## doesn't matter, since identical RoomData means identical content.
func _on_room_placed_free(room_data: RoomData) -> void:

	for card: RoomCard in _pending_room_cards:
		if is_instance_valid(card) and card.room_data == room_data:
			_pending_room_cards.erase(card)
			card.queue_free()
			_log("Room placed!")
			return


func _on_passive_purchased(passive_data: PassiveData) -> void:
	_log("Purchased passive: %s" % passive_data.passive_name)


func _on_pack_opened(description: String) -> void:
	_log(description)
	_refresh_shop_ui()


func _all_room_cards() -> Array[RoomCard]:
	var cards: Array[RoomCard] = [skeleton_card, skeleton_upgraded_card, skeleton_elite_card, spike_card, poison_arrow_card, sanctuary_card]
	cards.append_array(_pending_room_cards)
	return cards


func _log(message: String) -> void:
	log_text.append_text(message + "\n")
	print(message)
