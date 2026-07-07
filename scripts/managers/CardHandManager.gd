extends Node

## Tracks the player's current hand of build cards for the run. A
## "card" is just a RoomData resource — the same resource already used
## to build/upgrade rooms — so this manager owns no new data type, only
## the runtime list of which RoomData instances are currently in hand.
##
## The hand starts with a small fixed set of starter cards (see
## TestHarness.starting_hand_cards, added via add_card() during
## _reset_test()). From then on, the ONLY way to add more cards is
## buying a room in the shop (ShopManager.buy_room) or winning one from
## a card pack (ShopManager.buy_pack) — both call add_card() directly
## instead of granting a "free placement credit" like before.
##
## Placing a card (DungeonGrid.request_insert) calls remove_card() and
## refuses the insert if the card isn't actually in hand. Placement
## itself is free of additional gold cost — the gold was already spent
## acquiring the card (or it was a free starter card). RoomData.cost
## still matters for the shop's purchase price and a room's sell
## refund, just not charged again at drop time.
##
## Multiple copies of the exact same RoomData resource can be in hand
## at once (e.g. buying "Spike Corridor" twice) - remove_card() only
## ever removes ONE matching instance, so duplicates are tracked
## correctly rather than collapsed into a single flag.

signal card_added(room_data: RoomData)
signal card_removed(room_data: RoomData)
signal hand_changed

var hand: Array[RoomData] = []


func reset() -> void:
	hand.clear()
	hand_changed.emit()


func add_card(room_data: RoomData) -> void:

	if room_data == null:
		return

	hand.append(room_data)

	card_added.emit(room_data)
	hand_changed.emit()


## Removes ONE instance of room_data from hand (not all matching
## copies). Returns false if no matching card is currently held -
## callers (e.g. DungeonGrid.request_insert) should treat that as
## "can't place this, you don't have the card."
func remove_card(room_data: RoomData) -> bool:

	var index: int = hand.find(room_data)

	if index == -1:
		return false

	hand.remove_at(index)

	card_removed.emit(room_data)
	hand_changed.emit()

	return true


func has_card(room_data: RoomData) -> bool:
	return hand.has(room_data)


func card_count() -> int:
	return hand.size()
