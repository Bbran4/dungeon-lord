extends Resource
class_name HeroData

@export var hero_name : String

@export var max_health : int = 20

@export var damage : int = 2

@export var armor : int = 0

@export var attack_speed : float = 1.0

@export var abilities : Array[String]

@export_enum("Tank","Healer","Mage","Ranger","Rogue")
var class_type : String = "Tank"

@export var priority : int = 0

@export var sprite : Texture2D

## Gold earned if 100% of this hero's effective max health is dealt to
## them in damage over the course of a run (see EconomyManager).
@export var gold_value : int = 20
