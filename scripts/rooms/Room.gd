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


func show_upgrade_prompt(room_index: int) -> void:
	upgrade_zone.room_index = room_index
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
