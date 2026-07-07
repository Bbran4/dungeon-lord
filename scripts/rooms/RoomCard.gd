extends Button
class_name RoomCard

## Visual card representation of a RoomData resource. Both the fixed
## upgrade-only palette entries (skeleton_upgraded_card /
## skeleton_elite_card) and every card in the player's hand
## (dynamically instantiated by CardHandUI, one per
## CardHandManager.hand entry) are instances of the SAME scene/script -
## see scenes/rooms/RoomCard.tscn.
##
## Purely a VIEW: displays room_data (name, gold cost, rarity-tinted
## border, icon, description) and offers itself as drag data for
## RoomGapZone (insert) / RoomUpgradeZone (upgrade) to accept. It does
## not resolve placement itself - DungeonGrid.request_insert /
## request_upgrade do that.
##
## Fan/hover-lift animation while sitting in a hand is CardHandUI's
## job, driven off this node's native mouse_entered/mouse_exited
## signals - hover_tween exists here only so CardHandUI can kill a
## previous tween before starting a new one (same pattern as the
## dice-combat prototype's CardView.hover_tween).

signal drag_started(room_data: RoomData)
signal drag_ended

@onready var name_label: Label = $MarginContainer/VBoxContainer/Header/NameLabel
@onready var cost_label: Label = $MarginContainer/VBoxContainer/Header/DiceRequirementLabel
@onready var art_texture: TextureRect = $MarginContainer/VBoxContainer/ArtTexture
@onready var description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel

var room_data: RoomData
var hover_tween: Tween

## Per-rarity border color - mirrors RoomData.rarity's
## ("Common","Rare","Epic","Legendary") @export_enum values exactly, so
## an unrecognized/missing string just falls back to Common's color.
const RARITY_BORDER_COLORS: Dictionary = {
	GameEnums.Rarity.COMMON: Color(0.72, 0.56, 0.28),
	GameEnums.Rarity.RARE: Color(0.35, 0.55, 0.95),
	GameEnums.Rarity.EPIC: Color(0.68, 0.35, 0.95),
	GameEnums.Rarity.LEGENDARY: Color(1.0, 0.72, 0.15),
}	


func _ready() -> void:
	custom_minimum_size = Vector2(160, 240)

	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))

	cost_label.add_theme_font_size_override("font_size", 13)
	cost_label.add_theme_color_override("font_color", Color(0.95, 0.82, 0.55))

	description_label.custom_minimum_size = Vector2(130, 55)
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.clip_text = true
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))

	if room_data != null:
		_apply_room_data()


func set_room_data(data: RoomData) -> void:
	room_data = data
	_apply_room_data()


func _apply_room_data() -> void:

	if room_data == null or not is_node_ready():
		return

	name_label.text = room_data.room_name
	cost_label.text = "💰%d" % room_data.cost
	description_label.text = _get_description(room_data)
	art_texture.texture = room_data.icon

	_create_card_styles(_border_color_for_rarity(room_data.rarity))


## Falls back to a short auto-generated blurb if RoomData.description
## hasn't been authored yet, so a card is never blank while the .tres
## files catch up.
func _get_description(data: RoomData) -> String:

	if data.description != "":
		return data.description

	match data.room_type:
		"Monster":
			if data.monster != null:
				return "Houses %d %s." % [data.monster_count, data.monster.monster_name]
			return "An empty monster room."
		"Trap":
			if data.trap != null:
				return "%s trap." % data.trap.trap_name
			return "An empty trap room."
		"Utility":
			return "A utility room."
		"Boss":
			return "A boss encounter."

	return ""


func _border_color_for_rarity(rarity: GameEnums.Rarity) -> Color:
	return RARITY_BORDER_COLORS.get(rarity, RARITY_BORDER_COLORS[GameEnums.Rarity.COMMON])

func _get_drag_data(_at_position: Vector2) -> Variant:

	if room_data == null:
		return null

	var preview: Label = Label.new()
	preview.text = room_data.room_name
	set_drag_preview(preview)

	drag_started.emit(room_data)

	return room_data


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drag_ended.emit()


func _create_card_styles(border_color: Color) -> void:

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0.10, 0.085, 0.075)
	normal_style.border_color = border_color
	normal_style.set_border_width_all(4)
	normal_style.set_corner_radius_all(10)
	normal_style.content_margin_left = 8
	normal_style.content_margin_right = 8
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	normal_style.shadow_color = Color(0, 0, 0, 0.65)
	normal_style.shadow_size = 8
	normal_style.shadow_offset = Vector2(3, 4)

	var hover_style := normal_style.duplicate()
	hover_style.bg_color = Color(0.14, 0.11, 0.085)
	hover_style.border_color = border_color.lightened(0.25)
	hover_style.set_border_width_all(5)
	hover_style.shadow_size = 14
	hover_style.shadow_offset = Vector2(4, 6)

	var pressed_style := normal_style.duplicate()
	pressed_style.bg_color = Color(0.07, 0.055, 0.05)
	pressed_style.border_color = border_color.darkened(0.15)
	pressed_style.set_border_width_all(5)

	var disabled_style := normal_style.duplicate()
	disabled_style.bg_color = Color(0.045, 0.045, 0.045)
	disabled_style.border_color = Color(0.22, 0.22, 0.22)
	disabled_style.shadow_size = 3

	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("disabled", disabled_style)
