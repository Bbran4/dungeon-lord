extends Node

## The post-wave shop, opened once per full-wipe wave clear (see
## TestHarness._on_reward_phase_started). Offers 3 random rooms and 3
## random passives; the player may buy at most ONE room and ONE passive
## per shop visit. One random slot (room OR passive) is discounted.
## A reroll (cost scales down via PassiveManager.get_reroll_discount())
## reshuffles every slot EXCEPT the discounted one. A card pack (fixed
## cost, unlimited purchases) grants a random reward: gold, a free room,
## or a free passive.
##
## Room offers are drawn only from base-tier RoomData - already-
## upgraded tiers are reached via the in-dungeon upgrade path, not
## bought outright here.

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

var discount_category: String = "room"  # "room" or "passive"
var discount_index: int = 0

var room_bought: bool = false
var passive_bought: bool = false
var is_open: bool = false


func open_shop() -> void:
	is_open = true
	room_bought = false
	passive_bought = false
	_generate_offers()
	_pick_discount()
	shop_opened.emit()


func close_shop() -> void:
	is_open = false
	shop_closed.emit()


func get_reroll_cost() -> int:
	return maxi(0, int(round(reroll_cost_base - PassiveManager.get_reroll_discount())))


## Reshuffles every offer slot EXCEPT whichever one currently holds the
## discount, so the discounted item survives a reroll unchanged.
func reroll() -> bool:

	if not EconomyManager.spend_gold(get_reroll_cost()):
		return false

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


func buy_room(index: int) -> bool:

	if room_bought or index < 0 or index >= room_offers.size():
		return false

	if not EconomyManager.spend_gold(get_price("room", index)):
		return false

	room_bought = true
	room_purchased.emit(room_offers[index])
	return true


func buy_passive(index: int) -> bool:

	if passive_bought or index < 0 or index >= passive_offers.size():
		return false

	if not EconomyManager.spend_gold(get_price("passive", index)):
		return false

	passive_bought = true
	PassiveManager.apply_passive(passive_offers[index])
	passive_purchased.emit(passive_offers[index])
	return true


## Unlimited purchases, always at flat pack_cost - not affected by
## reroll or the room/passive "1 per visit" limit.
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
				pack_opened.emit("Card Pack: a free room - %s!" % room_data.room_name)
				room_purchased.emit(room_data)

		2:
			if passive_pool.is_empty():
				EconomyManager.add_gold(pack_cost)
				pack_opened.emit("Card Pack: nothing to give - refunded.")
			else:
				var passive_data: PassiveData = passive_pool[randi() % passive_pool.size()]
				PassiveManager.apply_passive(passive_data)
				pack_opened.emit("Card Pack: a passive - %s!" % passive_data.passive_name)

	return true


func _generate_offers() -> void:
	room_offers = _pick_random_unique(room_pool, 3)
	passive_offers = _pick_random_unique(passive_pool, 3)


func _pick_random_unique(pool: Array, count: int) -> Array:

	var shuffled: Array = pool.duplicate()
	shuffled.shuffle()

	return shuffled.slice(0, mini(count, shuffled.size()))


func _pick_discount() -> void:
	discount_category = "room" if randf() < 0.5 else "passive"
	var count: int = room_offers.size() if discount_category == "room" else passive_offers.size()
	discount_index = randi() % maxi(1, count)
