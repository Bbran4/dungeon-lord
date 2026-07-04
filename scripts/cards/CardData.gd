extends Resource
class_name CardData

@export var title : String

@export_multiline var description : String

@export_enum("Common","Rare","Epic","Legendary")
var rarity : String = "Common"

@export var icon : Texture2D

@export var effects : Array[String]
