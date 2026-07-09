extends Node2D
class_name Room

signal room_clicked(room: Room)
signal sell_requested(room: Room)

@export var room_data: RoomData

var monster: Node = null
var hero: Node = null

@onready var upgrade_zone: RoomUpgradeZone = $UpgradeZone
@onready var sell_button: Button = $SellButton
@onready var monster_label: Label = $MonsterLabel
@onready var door_north: ColorRect = $DoorNorth
@onready var door_east: ColorRect = $DoorEast
@onready var door_south: ColorRect = $DoorSouth
@onready var door_west: ColorRect = $DoorWest


func _ready() -> void:
	upgrade_zone.visible = false
	sell_button.visible = false
	sell_button.pressed.connect(_on_sell_button_pressed)


func set_room(data: RoomData) -> void:

	room_data = data

	update_visuals()


func update_visuals() -> void:

	if room_data == null:
		$Label.text = "Empty"
		monster_label.text = ""
		monster_label.visible = false
		return

	$Label.text = room_data.room_name

	if room_data.monster != null:

		if room_data.monster_count > 1:
			monster_label.text = "%s x%d" % [room_data.monster.monster_name, room_data.monster_count]
		else:
			monster_label.text = room_data.monster.monster_name

		monster_label.visible = true
	elif room_data.boss != null:
		monster_label.text = "👑 %s" % room_data.boss.boss_name
		monster_label.visible = true
	else:
		monster_label.text = ""
		monster_label.visible = false


## Shows/hides this room's 4 edge doorway markers based on which
## neighbor directions are currently passable (see
## DungeonGrid._apply_doors). Purely visual - doorways are derived
## from grid adjacency at render time, never authored per-room; there
## is no door-configuration field anywhere on RoomData.
func set_open_doors(open_edges: Dictionary) -> void:
	door_north.visible = open_edges.get("north", false)
	door_east.visible = open_edges.get("east", false)
	door_south.visible = open_edges.get("south", false)
	door_west.visible = open_edges.get("west", false)


func show_upgrade_prompt(cell: Vector2i) -> void:
	upgrade_zone.cell = cell
	upgrade_zone.visible = true


func hide_upgrade_prompt() -> void:
	upgrade_zone.visible = false


func show_sell_button() -> void:
	sell_button.visible = true


func hide_sell_button() -> void:
	sell_button.visible = false


func _on_button_pressed() -> void:
	room_clicked.emit(self)


func _on_sell_button_pressed() -> void:
	sell_requested.emit(self)
