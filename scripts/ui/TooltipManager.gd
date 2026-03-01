# TooltipManager.gd
# =============================================================================
# Renders item tooltips — the rich info panel that appears when hovering
# over an item in the inventory (like Diablo 2's item tooltip).
#
# SCENE REQUIREMENTS:
#   Panel             "TooltipPanel"
#   Label             "ItemNameLabel"
#   Label             "ItemTypeLabel"
#   VBoxContainer     "StatsContainer"
#   Label             "DescriptionLabel"
#
# Tooltip shows:
#   • Item name (in rarity colour)
#   • Type + equip slot
#   • All modifier lines (base stats + affixes)
#   • Item level
#   • Description / flavour text
# =============================================================================
class_name TooltipManager
extends Control

# ─── Nodes ────────────────────────────────────────────────────────────────────

@onready var tooltip_panel: Panel = get_node_or_null("TooltipPanel")
@onready var item_name_label: Label = get_node_or_null("TooltipPanel/ItemNameLabel")
@onready var item_type_label: Label = get_node_or_null("TooltipPanel/ItemTypeLabel")
@onready var stats_container: VBoxContainer = get_node_or_null("TooltipPanel/StatsContainer")
@onready var description_label: Label = get_node_or_null("TooltipPanel/DescriptionLabel")

# ─── Constants ────────────────────────────────────────────────────────────────

const TOOLTIP_OFFSET: Vector2 = Vector2(16, 8)
const MAX_WIDTH: float = 240.0

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	EventBus.tooltip_show_requested.connect(_on_show)
	EventBus.tooltip_hide_requested.connect(_on_hide)


func _process(_delta: float) -> void:
	if tooltip_panel and tooltip_panel.visible:
		_clamp_to_viewport()

# ─── Display ─────────────────────────────────────────────────────────────────

func _on_show(item: BaseItem, screen_position: Vector2) -> void:
	if item == null or tooltip_panel == null:
		_on_hide()
		return

	# Header.
	if item_name_label:
		item_name_label.text = item.get_display_name()
		item_name_label.add_theme_color_override("font_color", item.get_rarity_color())

	if item_type_label:
		var type_text: String = ItemData.EquipSlot.keys()[item.data.equip_slot]
		var cat_text: String = ItemData.ItemCategory.keys()[item.data.category]
		item_type_label.text = "%s | %s" % [cat_text.capitalize(), type_text.capitalize()]

	# Stat lines.
	if stats_container:
		for child in stats_container.get_children():
			child.queue_free()

		# Base damage for weapons.
		if item.data.weapon_max_damage > 0.0:
			_add_stat_line(
				"Damage: %.0f – %.0f" % [item.data.weapon_min_damage, item.data.weapon_max_damage],
				Color.WHITE)

		# All rolled modifiers.
		for line: String in item.get_tooltip_lines():
			var color := Color(0.7, 0.9, 1.0) if line.begins_with("+") else Color(0.9, 0.7, 0.7)
			_add_stat_line(line, color)

	# Description.
	if description_label:
		description_label.text = item.data.base_description
		description_label.visible = item.data.base_description.length() > 0

	# Position.
	tooltip_panel.position = screen_position + TOOLTIP_OFFSET
	tooltip_panel.custom_minimum_size.x = MAX_WIDTH
	tooltip_panel.visible = true


func _on_hide() -> void:
	if tooltip_panel:
		tooltip_panel.visible = false


func _add_stat_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = MAX_WIDTH - 16.0
	stats_container.add_child(label)


func _clamp_to_viewport() -> void:
	var viewport_size := get_viewport_rect().size
	var panel_size := tooltip_panel.size
	var pos := tooltip_panel.position

	pos.x = minf(pos.x, viewport_size.x - panel_size.x - 8.0)
	pos.y = minf(pos.y, viewport_size.y - panel_size.y - 8.0)
	pos.x = maxf(pos.x, 8.0)
	pos.y = maxf(pos.y, 8.0)

	tooltip_panel.position = pos
