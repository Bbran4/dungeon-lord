extends Node2D
class_name Room

signal room_clicked(room: Room)
signal sell_requested(room: Room)

@export var room_data: RoomData

var monster: Node = null
var hero: Node = null

@onready var upgrade_zone: RoomUpgradeZone = $UpgradeZone
@onready var sell_button: Button = $SellButton


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
		return

	$Label.text = room_data.room_name


func show_upgrade_prompt(room_index: int, room_name: String) -> void:
	upgrade_zone.room_index = room_index
	upgrade_zone.expected_room_name = room_name
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
