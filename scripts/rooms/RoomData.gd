extends Resource
class_name RoomData

@export var room_name : String
@export var cost : int = 50

@export_enum("Empty", "Monster", "Trap", "Boss")
var room_type : String = "Monster"

@export var monster : MonsterData
@export var trap : TrapData

@export var health : int = 100

@export var upgrade_path : RoomData

@export var icon : Texture2D

@export_enum("Common", "Rare", "Epic", "Legendary")
var rarity : String = "Common"
