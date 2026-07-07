extends Node

## The post-wave shop, opened once per full-wipe wave clear (see
## TestHarness._on_reward_phase_started). Offers 3 random rooms and 3
## random passives. Each individual offer SLOT can only be bought ONCE
## per shop visit - NOT "one room total" or "one passive total". The
## player may buy multiple DIFFERENT room/passive offers in the same
## visit; they just can't buy the exact same offered slot twice.
##
## REROLL is limited to ONCE per shop visit (see _reroll_used, reset in
## open_shop). Rerolling reshuffles every slot EXCEPT the discounted one
## and resets every slot's bought status back to available.
##
## PASSIVE CAPS: some passives (PassiveData.max_stacks) can only ever be
## owned a limited number of times across the whole run - see
## PassiveManager.can_apply. buy_passive refuses once a passive is
## capped, and _generate_offers filters capped-out passives out of the
## pool so they stop appearing as offers entirely once maxed.
##
## Room offers are drawn only from base-tier RoomData - already-
## upgraded tiers are reached via the in-dungeon upgrade path, not
## bought outright here.
##
## FREE ROOM CREDITS: buying a room (or winning one from a card pack)
## does NOT insert it directly - it grants a "free credit" for that
## exact RoomData resource, tracked in _free_room_credits. The player
## places it themselves by dragging a card (TestHarness dynamically
## creates one new card per credit - see room_purchased). Buying/
## winning the same room type more than once stacks additional credits
## and additional cards, rather than replacing anything.
## DungeonGrid.request_insert() calls consume_free_room() right before
## it would otherwise charge gold.

signal shop_opened
signal shop_closed
signal offers_refreshed
signal room_purchased(room_data: RoomData)
signal passive_purchased(passive_data: PassiveData)
signal pack_opened(description: String)

@export var room_pool: Array[RoomData] = [
	preload("res://resources/rooms/skeleton_den.tres"),
	preload("res://resources/rooms/spike_corridor.tres"),
	preload("res://resources/rooms/poison_arrow_corridor.tres"),
	preload("res://resources/rooms/sanctuary_room.tres"),
]

@export var passive_pool: Array[PassiveData] = [
	preload("res://resources/passives/golden_touch.tres"),
	preload("res://resources/passives/reinforced_minions.tres"),
	preload("res://resources/passives/sharpened_claws.tres"),
	preload("res://resources/passives/venomous_traps.tres"),
	preload("res://resources/passives/haggler.tres"),
]

@export var reroll_cost_base: int = 10
@export var pack_cost: int = 25
@export var discount_ratio: float = 0.5

var room_offers: Array[RoomData] = []
var passive_offers: Array[PassiveData] = []

## Per-offer-slot bought flags, sized to match room_offers/passive_offers.
## Reset to all-false by both open_shop() and reroll() - a reroll makes
## every slot available again, even ones already bought before it.
var room_bought: Array[bool] = []
var passive_bought: Array[bool] = []

var discount_category: String = "room"  # "room" or "passive"
var discount_index: int = 0

var is_open: bool = false

## True once a reroll has been used THIS shop visit. Reset by
## open_shop(). Checked by reroll() before anything else.
var _reroll_used: bool = false

## RoomData -> int. How many free placements of that exact resource are
## currently owed to the player. Incremented by a room purchase or a
## card pack's free-room roll; decremented by consume_free_room()
## whenever the room is actually placed.
var _free_room_credits: Dictionary = {}


func open_shop() -> void:
	is_open = true
	_reroll_used = false
	_generate_offers()
	_pick_discount()
	shop_opened.emit()


func close_shop() -> void:
	is_open = false
	shop_closed.emit()


func get_reroll_cost() -> int:
	return maxi(0, int(round(reroll_cost_base - PassiveManager.get_reroll_discount())))


func has_reroll_remaining() -> bool:
	return not _reroll_used


## Reshuffles every offer slot EXCEPT whichever one currently holds the
## discount, so the discounted item survives a reroll unchanged. Also
## resets EVERY slot's bought status back to available. Limited to ONE
## use per shop visit - refuses once _reroll_used is true, before even
## checking gold.
func reroll() -> bool:

	if _reroll_used:
		return false

	if not EconomyManager.spend_gold(get_reroll_cost()):
		return false

	_reroll_used = true

	var kept_room: RoomData = room_offers[discount_index] if discount_category == "room" and discount_index < room_offers.size() else null
	var kept_passive: PassiveData = passive_offers[discount_index] if discount_category == "passive" and discount_index < passive_offers.size() else null

	_generate_offers()

	if kept_room != null:
		room_offers[discount_index] = kept_room
	if kept_passive != null:
		passive_offers[discount_index] = kept_passive

	offers_refreshed.emit()
	return true


## Actual gold cost for a given offer slot, accounting for the discount.
func get_price(category: String, index: int) -> int:

	var base_cost: int = 0

	if category == "room" and index < room_offers.size():
		base_cost = room_offers[index].cost
	elif category == "passive" and index < passive_offers.size():
		base_cost = passive_offers[index].cost

	if category == discount_category and index == discount_index:
		return int(round(base_cost * discount_ratio))

	return base_cost


## Buys the room at `index`. Each offer slot can only be bought once per
## shop visit (until a reroll refreshes bought status), but buying one
## room offer does NOT block buying a different room offer, or any
## passive offer. Grants a free placement credit rather than inserting
## directly - see room_purchased / consume_free_room.
func buy_room(index: int) -> bool:

	if index < 0 or index >= room_offers.size() or room_bought[index]:
		return false

	if not EconomyManager.spend_gold(get_price("room", index)):
		return false

	room_bought[index] = true

	var room_data: RoomData = room_offers[index]
	_free_room_credits[room_data] = _free_room_credits.get(room_data, 0) + 1

	room_purchased.emit(room_data)
	return true


## Buys the passive at `index`. Same per-slot (not per-category) limit
## as buy_room. Additionally refuses if PassiveManager.can_apply()
## says this exact passive has already hit its max_stacks cap.
func buy_passive(index: int) -> bool:

	if index < 0 or index >= passive_offers.size() or passive_bought[index]:
		return false

	var passive_data: PassiveData = passive_offers[index]

	if not PassiveManager.can_apply(passive_data):
		return false

	if not EconomyManager.spend_gold(get_price("passive", index)):
		return false

	passive_bought[index] = true

	PassiveManager.apply_passive(passive_data)
	passive_purchased.emit(passive_data)
	return true


## Unlimited purchases, always at flat pack_cost - not affected by
## reroll or the per-offer "once per visit" limit (packs aren't offer
## slots at all). A capped-out passive roll (2) is re-rolled as a
## refund of pack_cost worth of gold instead, same treatment as an
## empty pool.
func buy_pack() -> bool:

	if not EconomyManager.spend_gold(pack_cost):
		return false

	var roll: int = randi() % 3

	match roll:

		0:
			var amount: int = randi_range(20, 40)
			EconomyManager.add_gold(amount)
			pack_opened.emit("Card Pack: +%d gold!" % amount)

		1:
			if room_pool.is_empty():
				EconomyManager.add_gold(pack_cost)
				pack_opened.emit("Card Pack: nothing to give - refunded.")
			else:
				var room_data: RoomData = room_pool[randi() % room_pool.size()]
				_free_room_credits[room_data] = _free_room_credits.get(room_data, 0) + 1
				pack_opened.emit("Card Pack: a free room - %s!" % room_data.room_name)
				room_purchased.emit(room_data)

		2:
			var available_passives: Array = passive_pool.filter(func(p: PassiveData) -> bool: return PassiveManager.can_apply(p))

			if available_passives.is_empty():
				EconomyManager.add_gold(pack_cost)
				pack_opened.emit("Card Pack: nothing to give - refunded.")
			else:
				var passive_data: PassiveData = available_passives[randi() % available_passives.size()]
				PassiveManager.apply_passive(passive_data)
				pack_opened.emit("Card Pack: a passive - %s!" % passive_data.passive_name)

	return true


## Called by DungeonGrid.request_insert right before it would otherwise
## charge gold for `room_data`. If a free credit is owed for this exact
## resource, consumes ONE and returns true (place it for free);
## otherwise returns false and the normal gold cost applies.
func consume_free_room(room_data: RoomData) -> bool:

	var remaining: int = _free_room_credits.get(room_data, 0)

	if remaining <= 0:
		return false

	if remaining <= 1:
		_free_room_credits.erase(room_data)
	else:
		_free_room_credits[room_data] = remaining - 1

	return true


## Also usable by DungeonGrid.request_insert's rollback path if an
## insert fails after a credit was already consumed.
func refund_room_credit(room_data: RoomData) -> void:
	_free_room_credits[room_data] = _free_room_credits.get(room_data, 0) + 1


## Passives already maxed out (PassiveManager.can_apply() == false) are
## excluded from the pool entirely, so a fully-stacked passive stops
## appearing as an offer at all rather than showing up unbuyable.
func _generate_offers() -> void:

	room_offers = _pick_random_unique(room_pool, 3)

	var available_passives: Array = passive_pool.filter(func(p: PassiveData) -> bool: return PassiveManager.can_apply(p))
	passive_offers = _pick_random_unique(available_passives, 3)

	room_bought = []
	room_bought.resize(room_offers.size())
	room_bought.fill(false)

	passive_bought = []
	passive_bought.resize(passive_offers.size())
	passive_bought.fill(false)


func _pick_random_unique(pool: Array, count: int) -> Array:

	var shuffled: Array = pool.duplicate()
	shuffled.shuffle()

	return shuffled.slice(0, mini(count, shuffled.size()))


func _pick_discount() -> void:
	discount_category = "room" if randf() < 0.5 else "passive"
	var count: int = room_offers.size() if discount_category == "room" else passive_offers.size()
	discount_index = randi() % maxi(1, count)
