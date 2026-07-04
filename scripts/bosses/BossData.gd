extends Resource
class_name BossData

@export var boss_name : String

@export var max_health : int

@export var damage : int

@export var armor : int

@export var phases : int = 1

@export var summons : Array[MonsterData]

@export var abilities : Array[String]

@export var sprite : Texture2D
