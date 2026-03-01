# VendorNPC.gd
# =============================================================================
# An NPC that sells items when the player walks nearby.
# Place as an Area3D in the scene with a CollisionShape3D (sphere ~3m).
# Set vendor_name, vendor_type, item_ids, and item_prices in the Inspector.
#
# SCENE STRUCTURE:
#   VendorNPC (Area3D)
#   ├── CollisionShape3D  – SphereShape3D radius ≈ 3.0
#   ├── NpcMesh           MeshInstance3D (capsule body)
#   └── NameLabel         Label3D
# =============================================================================
class_name VendorNPC
extends Area3D

## Displayed at the top of the shop panel.
@export var vendor_name: String = "Vendor"

## "armor" or "potion" — for future filtering.
@export var vendor_type: String = "armor"

## Item IDs to sell (must exist in ItemDatabase).
@export var item_ids: Array[String] = []

## Price per item ID. Keys must match item_ids entries.
@export var item_prices: Dictionary = {}

@onready var name_label: Label3D = get_node_or_null("NameLabel") as Label3D

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if name_label:
		name_label.text = vendor_name


func _on_body_entered(body: Node) -> void:
	if body is PlayerCharacter and not _player_inside:
		_player_inside = true
		var shop_items: Array = []
		for item_id in item_ids:
			var data: ItemData = ItemDatabase.get_item_data(item_id)
			if data:
				shop_items.append({
					"id": item_id,
					"name": data.display_name,
					"price": item_prices.get(item_id, 50),
				})
		EventBus.vendor_opened.emit(vendor_name, vendor_type, shop_items)


func _on_body_exited(body: Node) -> void:
	if body is PlayerCharacter and _player_inside:
		_player_inside = false
		EventBus.vendor_closed.emit()
