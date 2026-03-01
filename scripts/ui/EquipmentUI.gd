# EquipmentUI.gd
# =============================================================================
# Diablo 2-style equipment paperdoll window.
# Shows all equipment slots with the currently equipped item in each.
# Toggle with E key. Right-click a slot to unequip its item.
# =============================================================================
class_name EquipmentUI
extends Control

# Maps slot int → Label showing the equipped item name.
var _slot_labels: Dictionary = {}


func _ready() -> void:
	visible = false
	_build_ui()
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)
	EventBus.item_equipped.connect(func(_c: Node, _i: Resource, _s: String) -> void:
		if visible:
			_refresh()
	)
	EventBus.item_unequipped.connect(func(_c: Node, _i: Resource, _s: String) -> void:
		if visible:
			_refresh()
	)


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.06, 0.12, 0.97)
	bg.z_index = -1
	add_child(bg)

	# Title bar
	var title_bar := ColorRect.new()
	title_bar.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	title_bar.set_anchor_and_offset(SIDE_TOP, 0.0, 0.0)
	title_bar.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	title_bar.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 28.0)
	title_bar.color = Color(0.08, 0.08, 0.22, 1.0)
	add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	title_lbl.set_anchor_and_offset(SIDE_TOP, 0.0, 4.0)
	title_lbl.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	title_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 26.0)
	title_lbl.text = "EQUIPMENT  [E]"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_lbl)

	var hint_lbl := Label.new()
	hint_lbl.set_anchor_and_offset(SIDE_LEFT, 0.0, 4.0)
	hint_lbl.set_anchor_and_offset(SIDE_TOP, 0.0, 30.0)
	hint_lbl.set_anchor_and_offset(SIDE_RIGHT, 1.0, -4.0)
	hint_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 48.0)
	hint_lbl.text = "Right-click slot to unequip"
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.modulate = Color(0.6, 0.6, 0.6)
	hint_lbl.add_theme_font_size_override("font_size", 11)
	add_child(hint_lbl)

	# Scroll area for slot rows
	var scroll := ScrollContainer.new()
	scroll.set_anchor_and_offset(SIDE_LEFT, 0.0, 6.0)
	scroll.set_anchor_and_offset(SIDE_TOP, 0.0, 52.0)
	scroll.set_anchor_and_offset(SIDE_RIGHT, 1.0, -6.0)
	scroll.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -42.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(vbox)

	for entry: Array in _get_slots():
		var slot_int: int = entry[0]
		var slot_name: String = entry[1]
		_add_slot_row(vbox, slot_int, slot_name)

	# Close button
	var close_btn := Button.new()
	close_btn.set_anchor_and_offset(SIDE_LEFT, 0.5, -50.0)
	close_btn.set_anchor_and_offset(SIDE_TOP, 1.0, -36.0)
	close_btn.set_anchor_and_offset(SIDE_RIGHT, 0.5, 50.0)
	close_btn.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -8.0)
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void:
		visible = false
	)
	add_child(close_btn)


func _get_slots() -> Array:
	return [
		[ItemData.EquipSlot.HELMET,      "Helmet"],
		[ItemData.EquipSlot.CHEST,       "Chest"],
		[ItemData.EquipSlot.WEAPON_MAIN, "Main Hand"],
		[ItemData.EquipSlot.WEAPON_OFF,  "Off Hand"],
		[ItemData.EquipSlot.GLOVES,      "Gloves"],
		[ItemData.EquipSlot.BOOTS,       "Boots"],
		[ItemData.EquipSlot.RING_LEFT,   "Ring (L)"],
		[ItemData.EquipSlot.RING_RIGHT,  "Ring (R)"],
		[ItemData.EquipSlot.AMULET,      "Amulet"],
	]


func _add_slot_row(parent: VBoxContainer, slot_int: int, slot_name: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = slot_name
	name_lbl.custom_minimum_size = Vector2(76, 0)
	name_lbl.modulate = Color(0.75, 0.75, 0.75)
	name_lbl.add_theme_font_size_override("font_size", 12)
	row.add_child(name_lbl)

	var item_panel := Panel.new()
	item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_panel.custom_minimum_size = Vector2(0, 26)

	var item_lbl := Label.new()
	item_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	item_lbl.offset_left = 4.0
	item_lbl.offset_right = -4.0
	item_lbl.text = "(empty)"
	item_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_lbl.modulate = Color(0.5, 0.5, 0.5)
	item_lbl.add_theme_font_size_override("font_size", 12)
	item_panel.add_child(item_lbl)

	_slot_labels[slot_int] = item_lbl

	# Right-click to unequip
	item_panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton \
				and event.button_index == MOUSE_BUTTON_RIGHT \
				and event.pressed:
			_unequip_slot(slot_int)
	)

	row.add_child(item_panel)
	parent.add_child(row)


func _on_panel_toggled(panel_id: String, open: bool) -> void:
	if panel_id == "equipment":
		visible = open
		if open:
			_refresh()


func _refresh() -> void:
	var player := GameManager.player as PlayerCharacter
	if not player or not player.equipment:
		return

	for slot_int: int in _slot_labels:
		var lbl: Label = _slot_labels[slot_int]
		var item: EquipmentItem = player.equipment.get_item_in_slot(slot_int)
		if item and item.data:
			lbl.text = item.data.display_name
			lbl.modulate = ItemData.get_rarity_color(item.data.rarity)
		else:
			lbl.text = "(empty)"
			lbl.modulate = Color(0.5, 0.5, 0.5)


func _unequip_slot(slot_int: int) -> void:
	var player := GameManager.player as PlayerCharacter
	if not player or not player.equipment:
		return
	var item := player.equipment.get_item_in_slot(slot_int)
	if item:
		player.equipment.unequip_slot(slot_int, player.inventory)
		_refresh()
