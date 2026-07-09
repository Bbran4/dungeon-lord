extends Resource
class_name BiomeData

@export var biome_name : String

@export var background : Texture2D

@export var music : AudioStream

@export var room_pool : Array[RoomData]

@export var hero_pool : Array[HeroData]

## The dungeon's fixed boss encounter for this biome, authored as a
## RoomData (room_type = "Boss", boss = a BossData) rather than a bare
## BossData - the room needs a name/icon/description like any other
## room, it just isn't a card. See DungeonManager.set_boss_room.
@export var boss_room : RoomData

@export var wave_count : int = 10

@export var special_rules : Array[String]
