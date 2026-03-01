# VendorUI.gd
# =============================================================================
# Shop panel displayed when the player enters a VendorNPC's proximity.
# Listens to EventBus.vendor_opened / vendor_closed signals.
# Dynamically populates a list of buyable items.
#
# EXPECTED CHILD NODES:
#   Title      Label      – vendor name
#   GoldLabel  Label      – shows player's current gold
#   Items      VBoxContainer – populated with item rows at runtime
#   CloseBtn   Button     – hides the panel
# =============================================================================
class_name VendorUI
extends Control

@onready var title_label: Label = get_node_or_null("Title") as Label
@onready var gold_label: Label = get_node_or_null("GoldLabel") as Label
@onready var items_container: VBoxContainer = get_node_or_null("Items") as VBoxContainer
@onready var close_btn: Button = get_node_or_null("CloseBtn") as Button


func _ready() -> void:
	visible = false
	EventBus.vendor_opened.connect(_on_vendor_opened)
	EventBus.vendor_closed.connect(_on_vendor_closed)
	if close_btn:
		close_btn.pressed.connect(func() -> void: visible = false)


func _on_vendor_opened(vname: String, _vtype: String, shop_items: Array) -> void:
	if title_label:
		title_label.text = vname
	_rebuild_items(shop_items)
	_update_gold()
	visible = true


func _on_vendor_closed() -> void:
	visible = false


func _rebuild_items(shop_items: Array) -> void:
	if not items_container:
		return
	for child in items_container.get_children():
		child.queue_free()
	for item_info: Dictionary in shop_items:
		var row := HBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = item_info.get("name", "?")
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var price_lbl := Label.new()
		price_lbl.text = "%dg" % item_info.get("price", 0)
		price_lbl.custom_minimum_size = Vector2(50, 0)
		var buy_btn := Button.new()
		buy_btn.text = "Buy"
		buy_btn.pressed.connect(_on_buy.bind(item_info))
		row.add_child(name_lbl)
		row.add_child(price_lbl)
		row.add_child(buy_btn)
		items_container.add_child(row)


func _update_gold() -> void:
	var p: Node = GameManager.player
	if p and gold_label:
		gold_label.text = "Gold: %d" % (p as PlayerCharacter).gold


func _on_buy(item_info: Dictionary) -> void:
	var p: Node = GameManager.player
	if not (p is PlayerCharacter):
		return
	var player := p as PlayerCharacter
	var price: int = item_info.get("price", 0)
	if player.gold < price:
		EventBus.floating_text_requested.emit(
			player.global_position + Vector3(0, 2, 0),
			"Not enough gold!", Color.RED)
		return
	var item: BaseItem = ItemDatabase.create_item(item_info.get("id", ""), player.stats.level)
	if item == null:
		return
	if not player.inventory.add_item(item):
		EventBus.floating_text_requested.emit(
			player.global_position + Vector3(0, 2, 0),
			"Inventory full!", Color.YELLOW)
		return
	player.gold -= price
	_update_gold()
	EventBus.floating_text_requested.emit(
		player.global_position + Vector3(0, 2, 0),
		"Bought: " + item_info.get("name", ""), Color.GREEN)
