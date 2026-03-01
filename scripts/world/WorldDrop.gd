# WorldDrop.gd
# =============================================================================
# A world-space item pickup node. Spawned by LootSystem when enemies die.
# The player can walk near it to pick up the item.
#
# SCENE STRUCTURE:
#   WorldDrop (Area3D)
#   ├── CollisionShape3D   – pickup trigger (sphere, radius ≈ 2.0 m)
#   ├── ItemMesh           MeshInstance3D – coloured box showing rarity
#   └── ItemLabel          Label3D        – item name displayed above drop
# =============================================================================
class_name WorldDrop
extends Area3D

## Emitted when the player enters the pickup area and the item is collected.
signal picked_up

# ─── Node References ─────────────────────────────────────────────────────────

@onready var item_mesh: MeshInstance3D = get_node_or_null("ItemMesh") as MeshInstance3D
@onready var item_label: Label3D = get_node_or_null("ItemLabel") as Label3D

# ─── State ────────────────────────────────────────────────────────────────────

var _item: BaseItem = null

## How long (seconds) before the drop disappears automatically.
@export var lifetime: float = 60.0

var _lifetime_timer: float = 0.0

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_update_visuals()


func _process(delta: float) -> void:
	_lifetime_timer += delta
	if _lifetime_timer >= lifetime:
		queue_free()

# ─── Public API ───────────────────────────────────────────────────────────────

## Called by LootSystem right after instantiation.
func set_item(item: BaseItem) -> void:
	_item = item
	_update_visuals()

# ─── Internals ────────────────────────────────────────────────────────────────

func _update_visuals() -> void:
	if _item == null:
		return

	# Tint mesh by rarity colour.
	if item_mesh:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _item.get_rarity_color()
		mat.emission_enabled = true
		mat.emission = _item.get_rarity_color()
		mat.emission_energy_multiplier = 0.4
		item_mesh.material_override = mat

	# Show item name with rarity colour.
	if item_label:
		item_label.text = _item.get_display_name()
		item_label.modulate = _item.get_rarity_color()


func _on_body_entered(body: Node) -> void:
	# Only the player can pick up items.
	if body is PlayerCharacter:
		if _item != null:
			picked_up.emit()
