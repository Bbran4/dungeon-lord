extends Resource
class_name RoomData

@export var room_name : String
@export var cost : int = 50

@export_enum("Empty", "Monster", "Trap", "Boss", "Utility")
var room_type : String = "Monster"

## Card-facing flavor/summary text. Optional - RoomCard falls back to a
## short auto-generated blurb (see RoomCard._get_description) if this
## is left blank, so existing .tres files aren't broken by this field
## being new.
@export_multiline var description : String = ""

@export var monster : MonsterData

## How many of `monster` this room fields as a group encounter (e.g. a
## Skeleton Den fielding 3 Skeletons). 1 = a single monster, same as
## before this field existed.
@export var monster_count : int = 1

@export var trap : TrapData

@export var health : int = 100

@export var upgrade_path : RoomData

@export var icon : Texture2D

@export var rarity: GameEnums.Rarity = GameEnums.Rarity.COMMON
## Utility rooms only - applied once when the party arrives here (see
## Dungeon._apply_utility_room). Defaults are no-ops, so these are
## harmless on any non-Utility room.
@export var heal_party_on_entry : bool = false

## Multiplies gold earned by the party for the REST of the wave -
## stacks multiplicatively if more than one utility room is passed.
@export var gold_multiplier : float = 1.0

## Multiplies damage taken from traps (both INSTANT and
## PROJECTILE/DoT) for the rest of the wave - e.g. 0.5 for poison
## resistance, or >1.0 as the cost side of a strong buff elsewhere.
@export var trap_damage_multiplier : float = 1.0
## Boss rooms only (room_type == "Boss"). The boss fought in this room.
## Not a card - this room is never drafted into the hand, it's placed
## automatically via DungeonManager.set_boss_room(). See BiomeData.boss_room.
@export var boss : BossData
