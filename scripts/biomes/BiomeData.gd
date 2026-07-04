extends Resource
class_name BiomeData

@export var biome_name : String

@export var background : Texture2D

@export var music : AudioStream

@export var room_pool : Array[RoomData]

@export var hero_pool : Array[HeroData]

@export var boss : BossData

@export var wave_count : int = 10

@export var special_rules : Array[String]
